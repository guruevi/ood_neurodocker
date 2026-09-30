import os
from pathlib import Path
import re
import shlex
import subprocess
import sys
import tempfile
import unittest

from click.testing import CliRunner
from neurodocker.cli.generate import generate
import yaml


ROOT = Path(__file__).resolve().parents[1]


class DesktopTests(unittest.TestCase):
    def render(self, container, manager, distro, base):
        result = CliRunner().invoke(generate, [
            "--template-path", str(ROOT / "nd_templates"), container,
            "--pkg-manager", manager, "--yes", "--base-image", base,
            "--kasmvnc", f"kasm_distro={distro}", "de=xfce",
            "--ttyd", "version=1.7.7",
        ])
        self.assertEqual(result.exit_code, 0, f"{result.output}\n{result.exception}")
        self.check_shell(container, result.output)
        return result.output.split("# Save specification to JSON.")[0]

    def check_shell(self, container, recipe):
        if container == "docker":
            commands = re.findall(r"^RUN (.*)$", recipe.replace("\\\n", ""), re.MULTILINE)
        else:
            commands = re.findall(r"^%post\n(.*?)(?=^%|\Z)", recipe, re.MULTILINE | re.DOTALL)
        self.assertTrue(commands)
        for command in commands:
            result = subprocess.run(["bash", "-n"], input=command, text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr + "\n" + command)
        startup = re.search(r"printf '#!/usr/bin/env bash.*?' \| sed '[^']*' > /opt/kasm_startup.sh",
                            recipe.replace("\\\n", ""), re.DOTALL)
        self.assertIsNotNone(startup)
        with tempfile.TemporaryDirectory(dir=ROOT) as directory:
            path = Path(directory) / "kasm_startup.sh"
            command = startup.group().replace("/opt/kasm_startup.sh", shlex.quote(str(path)))
            result = subprocess.run(["bash", "-c", command], text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            result = subprocess.run(["bash", "-n", str(path)], text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr + "\n" + path.read_text())

    def test_rpm_recipes(self):
        for container in ("docker", "singularity"):
            for version in ("7", "8", "9"):
                with self.subTest(container=container, version=version):
                    base = "centos:7" if version == "7" else f"rockylinux:{version}"
                    recipe = self.render(container, "yum", f"rhel{version}", base)
                    self.assertIn("kasmvncserver.rpm", recipe)
                    self.assertIn("yum install -y", recipe)
                    self.assertIn("xfce4-session", recipe)
                    self.assertIn("openssl req", recipe)
                    self.assertIn("ttyd-1.7.7", recipe)
                    self.assertIn("ttyd.x86_64", recipe)
                    self.assertNotIn("apt-get", recipe)
                    self.assertNotIn(".deb", recipe)
                    self.assertNotIn("DEBIAN_FRONTEND", recipe)
                    self.assertNotIn("--refresh", recipe)
                    self.assertLess(recipe.index("glibc-common"), recipe.index("localedef"))
                    self.assertIn("/usr/bin/curl", recipe)

    def test_existing_debian_recipes(self):
        template = yaml.safe_load((ROOT / "nd_templates/kasmvnc.yaml").read_text())
        for distro, url in template["binaries"]["urls"].items():
            if distro == "google-chrome" or not url.endswith(".deb"):
                continue
            for container in ("docker", "singularity"):
                with self.subTest(container=container, distro=distro):
                    recipe = self.render(container, "apt", distro, "ubuntu:noble")
                    self.assertIn(url, recipe)
                    self.assertIn("kasmvncserver.deb", recipe)
                    self.assertIn("ssl-cert-snakeoil.pem", recipe)
                    self.assertIn("ttyd.x86_64", recipe)
                    self.assertNotIn("yum install", recipe)

    def run_builder(self, directory, container, fail=False):
        command = "false" if fail else (
            f"{shlex.quote(sys.executable)} -c "
            "'from neurodocker.cli.cli import cli; cli()' generate "
            f"--template-path {shlex.quote(str(ROOT / 'nd_templates'))} {container}"
        )
        script = f"""
source {shlex.quote(str(ROOT / 'generate_apps.sh'))}
CONTAINER={container}
CONTAINER_FILE={'Dockerfile' if container == 'docker' else 'def'}
ND_GEN_COMMAND=({command})
ND_GEN_ARGS=(--user nonroot --pkg-manager apt --yes)
gen_template() {{ mkdir -p "bc_$1"; printf '%s\\n' "$1" >> templates.log; }}
gen_container() {{ printf '%s %s\\n' "$1" "$2" >> builds.log; }}
build_desktop || exit $?
printf '%s\\n' "${{ND_GEN_ARGS[@]}}" > args.log
"""
        return subprocess.run(
            ["bash"], input=script, text=True, cwd=directory,
            capture_output=True, env=os.environ.copy(),
        )

    def test_build_desktop(self):
        for container, extension in (("docker", "Dockerfile"), ("singularity", "def")):
            with self.subTest(container=container), tempfile.TemporaryDirectory(dir=ROOT) as directory:
                result = self.run_builder(directory, container)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                directory = Path(directory)
                self.assertEqual((directory / "templates.log").read_text().splitlines(),
                                 ["desktop", "desktop_gui"])
                self.assertEqual((directory / "builds.log").read_text().splitlines(),
                                 ["desktop rhel7", "desktop rhel8", "desktop rhel9",
                                  "desktop ubuntu22", "desktop ubuntu24"])
                self.assertIn("apt", (directory / "args.log").read_text())
                for version, repository in (("7", "archives.fedoraproject.org"),
                                            ("8", "powertools"), ("9", "crb")):
                    recipe = (directory / f"bc_desktop/desktop_rhel{version}.{extension}").read_text()
                    self.check_shell(container, recipe)
                    if container == "docker":
                        instructions = [line for line in recipe.splitlines()
                                        if line and not line.startswith("#")]
                        self.assertTrue(instructions[0].startswith("FROM "), instructions[0])
                        self.assertLess(recipe.index("kasmvncserver.rpm"), recipe.index("USER nonroot"))
                    self.assertIn(repository, recipe)
                    self.assertIn("xfce4-session", recipe)
                    self.assertIn("kasmvncserver.rpm", recipe)
                    self.assertIn("compat-db47", recipe)
                    self.assertIn("glibc-devel", recipe)
                    self.assertIn("mesa-libGLU", recipe)
                    self.assertIn("xterm", recipe)
                    self.assertIn("ksh", recipe)
                    self.assertIn("libssl.so", recipe)
                    self.assertIn("libcrypto.so", recipe)
                    self.assertIn("libdl.so", recipe)
                    if version == "7":
                        self.assertIn("screen", recipe)
                    if version in ("8", "9"):
                        self.assertIn("libnsl", recipe)
                        self.assertIn("compat-openssl10", recipe)
                    self.assertNotIn("apt-get", recipe)
                    self.assertNotIn("chocolate-doom", recipe)
                    self.assertLess(recipe.index(repository), recipe.index("kasmvncserver.rpm"))
                for version, distro in (("22", "jammy"), ("24", "noble")):
                    recipe = (directory / f"bc_desktop/desktop_ubuntu{version}.{extension}").read_text()
                    self.check_shell(container, recipe)
                    if container == "docker":
                        instructions = [line for line in recipe.splitlines()
                                        if line and not line.startswith("#")]
                        self.assertTrue(instructions[0].startswith("FROM "), instructions[0])
                        self.assertLess(recipe.index("kasmvncserver.deb"), recipe.index("USER nonroot"))
                    self.assertIn("kasmvncserver.deb", recipe)
                    self.assertIn(distro, recipe)
                    self.assertIn("apt-get", recipe)
                    self.assertNotIn("yum install", recipe)
                    self.assertNotIn(".rpm", recipe)

    def test_generation_failure_stops_build(self):
        with tempfile.TemporaryDirectory(dir=ROOT) as directory:
            result = self.run_builder(directory, "docker", fail=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertNotIn("command not found", result.stderr)
            self.assertFalse((Path(directory) / "builds.log").exists())

    def test_desktop_template(self):
        directory = ROOT / "desktop_template"
        form = yaml.safe_load((directory / "form.yml").read_text())
        self.assertIn("memory", form["form"])
        self.assertEqual(form["attributes"]["memory"]["widget"], "select")
        options = [opt[0] if isinstance(opt, list) else opt for opt in form["attributes"]["memory"]["options"]]
        self.assertEqual(options, ["8G", "16G", "32G", "64G", "128G", "256G"])
        self.assertFalse(form["attributes"]["app_version"]["options"])
        script_erb = (directory / "template/script.sh.erb").read_text()
        ruby_script = f"""
require 'erb'
require 'ostruct'
require 'open3'

class Object
  def blank?
    respond_to?(:empty?) ? !!empty? : !self
  end
  def present?
    !blank?
  end
end

template = <<'ERB'
{script_erb}
ERB

erb = ERB.new(template, nil, '-')

        res_rhel8 = erb.result(OpenStruct.new(context: OpenStruct.new(bc_account: 'desktop', app_version: 'rhel8', gpu: 0)).instance_eval {{ binding }})
raise "rhel8 missing tmux" unless res_rhel8.include?('/usr/bin/tmux') || res_rhel8.include?('tmux -L')
raise "rhel8 should not include screen" if res_rhel8.include?('/usr/bin/screen')

res_u22 = erb.result(OpenStruct.new(context: OpenStruct.new(bc_account: 'desktop', app_version: 'ubuntu22', gpu: 0)).instance_eval {{ binding }})
raise "ubuntu22 missing tmux" unless res_u22.include?('tmux')

res_u24 = erb.result(OpenStruct.new(context: OpenStruct.new(bc_account: 'desktop', app_version: 'ubuntu24', gpu: 0)).instance_eval {{ binding }})
raise "ubuntu24 missing tmux" unless res_u24.include?('tmux')

[res_rhel8, res_u22, res_u24].each do |script|
  Open3.popen3('bash', '-n') do |stdin, stdout, stderr, wait_thr|
    stdin.write(script)
    stdin.close
    raise "bash -n failed: #{{stderr.read}}" unless wait_thr.value.success?
  end
end

puts 'OK'
"""
        proc = subprocess.run(["ruby", "-e", ruby_script], text=True, capture_output=True)
        self.assertEqual(proc.returncode, 0, proc.stderr + proc.stdout)

    def test_desktop_gui(self):
        directory = ROOT / "desktop_gui_template"
        form = yaml.safe_load((directory / "form.yml").read_text())
        self.assertIn("memory", form["form"])
        options = [opt[0] if isinstance(opt, list) else opt for opt in form["attributes"]["memory"]["options"]]
        self.assertEqual(options, ["8G", "16G", "32G", "64G", "128G", "256G"])
        self.assertFalse(form["attributes"]["app_version"]["options"])
        script = (directory / "template/script.sh.erb").read_text()
        self.assertIn("/opt/kasm_startup.sh", script)
        self.assertIn("context.bc_account", script)
        self.assertIn("context.app_version", script)
        self.assertIn("SINGULARITYENV_XVNC_OPTIONS", script)
        self.assertIn("/rnode/", (directory / "view.html.erb").read_text())

    def test_submit_memory(self):
        submit_erb = (ROOT / "template/submit.yml.erb").read_text()
        ruby_script = f"""
require 'erb'
require 'ostruct'
require 'yaml'

class Object
  def blank?
    respond_to?(:empty?) ? !!empty? : !self
  end
  def present?
    !blank?
  end
end

template = <<'ERB'
{submit_erb}
ERB

def render(template, ctx)
  ERB.new(template, trim_mode: '-').result(ctx.instance_eval {{ binding }})
end

# Case 1: default with 2 cores
res1 = YAML.safe_load(render(template, OpenStruct.new(cluster: 'general', cores: 2)))
raise "Fail 1" unless res1['script']['native'].include?('--mem') && res1['script']['native'].include?('2048')

# Case 2: explicit 16G memory (16384 MB)
res2 = YAML.safe_load(render(template, OpenStruct.new(cluster: 'general', cores: 2, memory: '16384')))
raise "Fail 2" unless res2['script']['native'].include?('16384')

# Case 3: explicit integer 32768 memory
res3 = YAML.safe_load(render(template, OpenStruct.new(cluster: 'general', cores: 2, memory: 32768)))
raise "Fail 3" unless res3['script']['native'].include?('32768')

puts 'OK'
"""
        proc = subprocess.run(["ruby", "-e", ruby_script], text=True, capture_output=True)
        self.assertEqual(proc.returncode, 0, proc.stderr + proc.stdout)


if __name__ == "__main__":
    unittest.main()