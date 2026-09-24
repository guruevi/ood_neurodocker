# Instructions for LLM contributors

## Project purpose and layout

This repository composes Neurodocker containers and Open OnDemand (OOD) Batch Connect apps.
It is a Bash/YAML/ERB generator, not a Python web application.

- `generate_apps.sh` is sourced from the repository root. Each `build_<app>()` generates app files and then builds its container versions; sourcing alone must not start builds.
- `nd_templates/*.yaml` contains Neurodocker software installers. `_default.yaml` is shared bootstrap code, so changes affect every app.
- `template/` supplies the default ttyd/tmux shell app. `<app>_template/` overrides it for that app; `<app>_gui_template/` supplies GUI-specific overrides.
- `gen_template` copies `template/`, then only the matching `${app}_template/`, to `bc_${app}/`. It does not automatically merge the shell app's overrides into the GUI app.
- `gen_container` builds the generated recipe and adds its version to both shell and GUI forms. Both use the same image; `bc_account` removes the `_gui` suffix.
- `build/src/` files are build inputs. Preserve existing licenses and never introduce credentials or copy private license contents into documentation.
- `bc_*` directories and container recipes are generated output. Edit source templates, not generated files. Do not commit images, virtual environments, or test artifacts.
- `README.md` is a symlink to `Writerside/topics/readme.md`; edit the shared document only once.

## Adding an app

1. Read the closest examples first: `build_doom` for simple composition, `build_fsl` for a shell/GUI pair with build inputs, `build_rstudio` for custom generation arguments, and `build_desktop` for RPM-based desktops.
2. Add a `build_<app>()` function, set the app name and version list, and call `gen_template` with the name, title, subcategory, and optional Font Awesome icon. Use `_gui` for the GUI entry, but call `gen_container` only for the shared image name.
3. Compose the image with `ND_GEN_COMMAND`, an appropriate base image, and ordered Neurodocker options. Emit `--base-image` first, perform installation as root, and select the runtime user last. `ND_GEN_ARGS` defaults to `--user nonroot --pkg-manager apt --yes`; place it after installation and override the package manager for RPM builds without mutating this global array.
4. Write `bc_${app_name}/${app_name}_${app_version}.${CONTAINER_FILE}`, then call `gen_container`. Stop if generation fails rather than building a partial recipe.
5. Add only the overrides needed for the app. GUI forms need `bc_vnc_resolution`; KasmVNC launchers pass `SINGULARITYENV_VNC_RESOLUTION` and `SINGULARITYENV_XVNC_OPTIONS`, then execute `/opt/kasm_startup.sh`. Shell launchers use ttyd with tmux.
6. Keep form version options empty in source templates: `gen_container` fills them. The app version in the form, recipe filename, image tag, and SIF filename must agree.

## Neurodocker and distribution rules

- Follow the existing YAML schema: `name`, `url`, `binaries` or `source`, `urls`, `arguments`, `dependencies`, `instructions`, and `env`. Use `{{ self.<name> }}` for template arguments and `self.install_dependencies()` for dependency installation.
- Pin software releases and use real upstream assets. Match the base image, package manager, distribution key, architecture, and binary ABI; do not invent RPM filenames by changing a Debian URL's suffix.
- Keep `apt` and `yum` dependencies and commands separate. Neurodocker uses `yum` for EL8/9 even when the distribution implements it via DNF. Do not leak `apt-get`, Debian package names, or Debian certificate paths into RPM instructions.
- Configure required repositories before installing desktop packages. `build_desktop` uses CentOS 7 plus vault/EPEL archives, Rocky Linux 8 plus PowerTools/EPEL, and Rocky Linux 9 plus CRB/EPEL. These are RHEL-compatible images, not official entitled RHEL images.
- EL7 is an unsupported legacy target: its KasmVNC RPM is pinned to 1.2.1, while EL8/9 use 1.4.0 Oracle-compatible RPMs. ttyd uses EPEL RPMs on EL8/9, but the upstream 1.7.7 binary on EL7 because older EPEL ttyd lacks the launcher's `-W` option.
- Preserve existing Debian/Ubuntu template behavior when adding another distribution.
- Neurodocker joins Docker `RUN` lines with `&&`. Leading/trailing blank lines introduced by Jinja, shell `else` blocks, and missing semicolons before `fi` can break generated shell syntax. Validate rendered recipes, not just YAML. Also validate scripts emitted via `printf`/`sed`.
- Keep downloads fail-fast and package installation noninteractive. Do not disable signature or certificate checks to work around missing repositories.
- KasmVNC's current launcher disables basic authentication and assumes OOD's authenticated proxy. Do not expose its port publicly; bind manual test ports to localhost. EL7 must not be advertised as a security-hardened desktop.

## Validation and environment

- Match existing Bash indentation (two spaces), YAML indentation, naming, and ERB conventions. Avoid unrelated refactors or changes to site-specific cluster, queue, image, and bind-mount defaults.
- Install Python dependencies from `requirements.txt` in the project's configured environment. Tests use standard-library `unittest` and Neurodocker's actual renderer; no Docker daemon is needed for generation tests.
- Run `bash -n generate_apps.sh`, `python -m unittest discover -s tests -v`, and `git diff --check` for generator/template changes. The test harness isolates template-copy and container-build side effects; it does not claim to build images.
- `generate_apps.sh` also requires Mike Farah's `yq` v4, `rsync`, and a discoverable pip configuration, even for apps that do not use pip. Do not create or overwrite host pip configuration or change `HOME` just to source it in tests.
- `CONTAINER` defaults to `singularity`; set `CONTAINER=docker` before sourcing for Docker. `CONTAINER_REPOS` defaults to `/opt/ood_apps/images` and must be writable for real builds. Docker builds target `linux/amd64`.
- For functional changes, verify Docker and Singularity generation, relevant negative cases, and existing distribution branches. If a container engine is available, build and smoke-test the changed images. Clearly distinguish recipe checks from image-build and browser-session validation when reporting results.