# About OOD Neurodocker
OOD Neurodocker is a tool for creating Docker images for OpenOnDemand. 
It was initially designed by the ReproNim repository to create Docker images for neuroimaging software.

However the concept has been very useful to create any Docker image for OpenOnDemand.

# Getting started
## Short version:
Read generate_apps.sh
source generate_apps.sh
Call a function to generate a Docker or Singularity image for OpenOnDemand

## Functional version:
1. Clone the repository into your RubyMine IDE
1. Create a Python virtual environment (slightly optional but recommended):
   - `python3 -m venv .venv`
   - `source .venv/bin/activate` (Linux/Mac) or `.venv\Scripts\activate` (Windows)
1. Install the dependencies:
   - `pip install -r requirements.txt`
1. Make sure Neurodocker and YQ are installed and in your PATH:
   - `neurodocker --version`
   - `yq --version`
1. Set the environment variable to generate a Docker image for OpenOnDemand (default is Singularity):
   - `export CONTAINER=docker`
1. Source the script to generate the Docker image:
   - `source generate_apps.sh`
1. Build the Docker image:
   - `build_doom`
1. IF that works, you can now edit generate_apps.sh to add more applications or modify the existing ones.
1. Read the neurodocker documentation to understand how to use templates which are in nd_templates/
1. Go back to source the script if you make changes to generate_apps.sh

# Testing the generated Docker image
If you build the container with Docker, you should see "naming to docker.io/library/your_software:version" in the output
and the image will be available locally.

You can test the generated Docker image by running the following command (eg. for KasmVnc):
```bash
export XVNC_OPTIONS="-websocketPort 8080"
docker run --rm -it --platform linux/amd64 -p 127.0.0.1:8080:8080 \
  -e XVNC_OPTIONS \
  -v ~/test_home:/home/nonroot \
  --name kasmvnc \
  --entrypoint /bin/bash \
  your_software:version
```
Note this runs the /bin/bash entrypoint, so you can test the image interactively.
Once inside the container, you can run the command to start the application, e.g.:
```bash
printf 'none::wo\n' > "$HOME/.kasmpasswd"
/opt/kasm_startup.sh
```

# Making more images
Copy/paste from another app, modify the various variables to your liking
The way it works is that it will rsync in order:
- the template directory
- the appname_template directory
- the appname_gui_template directory if it has both a gui and a terminal option

There are various templates you can include in your neurodocker generate command
They will basically be parsed in order and added to the Dockerfile and/or Singularity container document

This MAY be slightly inefficient at build time but the composability is worth it.

# Documentation:
Using WriterSide.

# Desktop environments

`build_desktop` creates `bc_desktop` (ttyd/tmux shell) and `bc_desktop_gui`
(KasmVNC/XFCE), sharing five images:

| Version | Base image | Desktop packages | KasmVNC |
| --- | --- | --- | --- |
| `rhel7` | `centos:7` | CentOS Vault and archived EPEL 7 | 1.2.1 CentOS RPM |
| `rhel8` | `rockylinux:8` | EPEL 8 and PowerTools | 1.4.0 Oracle 8 RPM |
| `rhel9` | `rockylinux:9` | EPEL 9 and CRB | 1.4.0 Oracle 9 RPM |
| `ubuntu22` | `ubuntu:22.04` | Ubuntu Jammy repositories | 1.5.0 Jammy DEB |
| `ubuntu24` | `ubuntu:24.04` | Ubuntu Noble repositories | 1.5.0 Noble DEB |

These are public RHEL-compatible distributions, not official Red Hat images.
EL7 is end-of-life, uses frozen repositories and an older KasmVNC, and is provided
only for legacy compatibility. Prefer EL8/9 for new deployments. ttyd 1.7.7 is
installed as an EPEL RPM on EL8/9; EL7 uses the upstream binary because its older
EPEL package does not support the OOD launcher's `-W` option.

After installing the prerequisites above (including `rsync`, Mike Farah's `yq` v4,
and a pip configuration discoverable by `generate_apps.sh`):

```bash
export CONTAINER=docker
export CONTAINER_REPOS="$PWD/images"
source generate_apps.sh
build_desktop
```

This generates recipes and **builds all images**, tagged `desktop:rhel7`,
`desktop:rhel8`, `desktop:rhel9`, `desktop:ubuntu22`, and `desktop:ubuntu24`. For Singularity, set `CONTAINER=singularity`
before sourcing; images are written to `${CONTAINER_REPOS}/desktop/desktop_*.sif`.
The OOD launch templates default to `/opt/ood_apps/images`; keep that deployment
path or adjust the templates to match your site. Images and RPMs target x86_64.
When composing the RPM templates directly, enable the matching EPEL and optional
PowerTools/CRB repositories before invoking KasmVNC or ttyd.

For a local Docker smoke test:

```bash
docker run --rm --platform linux/amd64 -p 127.0.0.1:8080:8080 \
  -e XVNC_OPTIONS="-websocketPort 8080" \
  desktop:rhel9 bash -c 'printf "none::wo\n" > "$HOME/.kasmpasswd"; exec /opt/kasm_startup.sh'
```

Open `http://localhost:8080`. KasmVNC basic authentication is disabled for the
existing OOD proxy integration; never expose this test port publicly.
The password file initialization matches the OOD `before.sh` launcher.

After building all three images, run the automated runtime smoke tests:

```bash
bash tests/smoke_desktop.sh
```

These verify nonroot XFCE startup, KasmVNC and ttyd HTTP responses, and tmux in
disposable containers without publishing ports. They do not validate browser
interaction or the OOD proxy. Pass image tags to test only selected versions.

Generator tests (no image builds):

```bash
bash -n generate_apps.sh
python -m unittest discover -s tests -v
```

See `AGENTS.md` for repository-specific instructions for LLM contributors.

# TODO:
- Add a cleanup template that minifies the container (consideration: reproducibility if you eliminate sources)
- Add RPM or NIST compliant/hardened source containers for common tools
- Compile this documentation to a static page for both GitLab and GitHub