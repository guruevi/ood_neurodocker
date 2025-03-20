#!/usr/bin/env bash
CONTAINER="singularity"
CONTAINER_REPOS="/opt/ood_apps/images"
# APPS="afni afni_gui ants bids_validator cat12 convert3d dcm2niix freesurfer fsl fsl_gui jq matlabmcr minc miniconda mricron mrtrix3 ndfreeze neurodebian niftyreg petpvc spm12 vnc spaceranger"

gen_template() {
  app=$1
  rsync -a template/ "bc_${app}"/
  if [ -d "${app}"_template ]; then
    rsync -a "${app}"_template/ "bc_${app}"/
  fi

  bc_account="${app/_gui/}"
  yq -i '.title = "'"${2}"'"' bc_"${app}"/form.yml
  yq -i '.attributes.bc_account = "'"${bc_account}"'"' bc_"${app}"/form.yml
  yq -i '.name = "'"${2}"'"' bc_"${app}"/manifest.yml
  yq -i '.description = "This app will launch an interactive shell with '"${2}"' pre-installed. You
                         will have full access to the resources these nodes provide. This is analogous
                         to an interactive batch job."' bc_"${app}"/manifest.yml
}

if CONTAINER="singularity"; then
  CONTAINER_FILE="def"
elif CONTAINER="docker"; then
  CONTAINER_FILE="Dockerfile"
fi

# Test if yq is on path
if ! command -v yq &> /dev/null; then
  echo "yq could not be found"
  exit 1
fi

########################################################################################################################
# AFNI
########################################################################################################################
build_afni() {
  app_name="afni"
  AFNI_VERSIONS=('25.0.06')
  gen_template ${app_name} "AFNI (Shell)"
  gen_template "${app_name}_gui" "AFNI (GUI)"
  for app_version in "${AFNI_VERSIONS[@]}"; do
    echo "Building ${app_name}_${app_version}"
    neurodocker generate ${CONTAINER} \
      --pkg-manager apt \
      --base-image ubuntu:24.04 \
      --env TZ=America/New_York \
      --env R_LIBS=/usr/local/lib/R \
      --env PATH=/usr/local/AFNIbin:/usr/local/bin:/usr/bin:/bin \
      --run "export DEBIAN_FRONTEND=noninteractive TZ=America/New_York" \
      --install           tcsh xfonts-base libssl-dev       \
                          python-is-python3                 \
                          python3-matplotlib python3-numpy  \
                          python3-flask python3-flask-cors  \
                          python3-pil                       \
                          gsl-bin netpbm gnome-tweaks       \
                          libjpeg62 xvfb xterm vim curl     \
                          gedit evince eog                  \
                          libglu1-mesa-dev libglw1-mesa-dev \
                          libxm4 build-essential            \
                          libcurl4-openssl-dev libxml2-dev  \
                          libgfortran-14-dev libgomp1       \
                          gnome-terminal nautilus           \
                          firefox xfonts-100dpi             \
                          r-base-dev cmake bc git           \
                          libgdal-dev libopenblas-dev       \
                          libnode-dev libudunits2-dev       \
                          supervisor xfce4 xfce4-terminal   \
                          xterm dbus-x11 libdbus-glib-1-2   \
                          vim wget net-tools locales bzip2  \
                          procps apt-utils mesa-utils       \
                          pulseaudio tmux                   \
                          libnss-wrapper gettext            \
                          libgdal-dev libopenblas-dev       \
                          libnode-dev libudunits2-dev       \
                          x11-utils libxcvt0                \
      --run "curl -L --output /tmp/@update.afni.binaries https://afni.nimh.nih.gov/pub/dist/bin/misc/@update.afni.binaries" \
      --run "tcsh /tmp/@update.afni.binaries -package linux_ubuntu_24_64 -bindir /usr/local/AFNIbin -do_extras" \
      --run "PATH=/usr/local/AFNIbin:$PATH /usr/local/AFNIbin/rPkgsInstall -pkgs ALL" \
      --run "curl -L --output /tmp/tigervnc.deb https://versaweb.dl.sourceforge.net/project/tigervnc/stable/1.14.1/ubuntu-24.04LTS/amd64/tigervncserver_1.14.1-1ubuntu1_amd64.deb" \
      --run "dpkg -i /tmp/tigervnc.deb" \
      --run "curl -L --output /usr/bin/ttyd https://github.com/tsl0922/ttyd/releases/download/1.7.7/ttyd.i686" \
      --run "chmod +x /usr/bin/ttyd" \
      --run "echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen && locale-gen" \
      --run "mkdir -p /opt/novnc/utils/websockify" \
      --run "curl -sL https://github.com/novnc/noVNC/archive/refs/tags/v1.6.0.tar.gz | tar xz --strip 1 -C /opt/novnc" \
      --run "wget -qO- https://github.com/novnc/websockify/archive/refs/tags/v0.13.0.tar.gz | tar xz --strip 1 -C /opt/novnc/utils/websockify" \
      --run "ln -s /opt/novnc/vnc_lite.html /opt/novnc/index.html" \
      --run "printf '\$localhost = \"no\";\n1;\n' >/etc/tigervnc/vncserver-config-defaults" \
      --copy template/build/src/vnc_startup.sh /opt/vnc_startup.sh \
    > "bc_${app_name}/${app_name}_${app_version}.${CONTAINER_FILE}"
    mkdir -p "${CONTAINER_REPOS}/${app_name}"
    if [ "${CONTAINER}" = "docker" ]; then
      # TODO: Build and publish Docker env
      echo "Docker not supported"
    elif [ "${CONTAINER}" = "singularity" ]; then
      # Make sure we don't overwrite the container
      if [ -f "${CONTAINER_REPOS}/${app_name}/${app_name}_${app_version}.sif" ]; then
        echo "Singularity container already exists, skipping"
      else
        singularity build "${CONTAINER_REPOS}/${app_name}/${app_name}_${app_version}.sif" "bc_${app_name}/${app_name}_${app_version}.def"
        echo "Done building Singularity container"
      fi
    fi
    yq -i '.attributes.app_version.options += [[ "'"${app_version}"'", "'"${app_version}"'"]]' bc_${app_name}/form.yml
    yq -i '.attributes.app_version.options += [[ "'"${app_version}"'", "'"${app_version}"'"]]' bc_${app_name}_gui/form.yml
  done
}

########################################################################################################################
# FSL
########################################################################################################################
build_fsl() {
  ## '6.0.6.2' '6.0.6.1' '6.0.6' '6.0.5.2' '6.0.5.1' '6.0.5' '6.0.4' '6.0.3' '6.0.2' '6.0.1' '6.0.0' '5.0.11' '5.0.10' '5.0.9' '5.0.8'
  FSL_VERSIONS=('6.0.7.4' '6.0.7.1' '6.0.6.4' '6.0.6.3')
  app_name="fsl"
  gen_template "fsl" "FSL (Shell)"
  gen_template "fsl_gui" "FSL (GUI)"
  for app_version in "${FSL_VERSIONS[@]}"; do
    echo "Building fsl_${app_version}"
    neurodocker generate ${CONTAINER} \
      --pkg-manager apt \
      --base-image debian:bullseye-slim \
      --fsl version="${app_version}" \
      --yes \
      --install supervisor xfce4 xfce4-terminal xterm dbus-x11 libdbus-glib-1-2 vim wget net-tools locales bzip2 tmux \
                procps apt-utils python3-numpy mesa-utils pulseaudio tigervnc-standalone-server libnss-wrapper gettext \
      --run "curl -L --output /usr/bin/ttyd https://github.com/tsl0922/ttyd/releases/download/1.7.7/ttyd.i686" \
      --run "chmod +x /usr/bin/ttyd" \
      --run "echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen && locale-gen" \
      --run "mkdir -p /opt/novnc/utils/websockify" \
      --run "curl -sL https://github.com/novnc/noVNC/archive/refs/tags/v1.6.0.tar.gz | tar xz --strip 1 -C /opt/novnc" \
      --run "wget -qO- https://github.com/novnc/websockify/archive/refs/tags/v0.13.0.tar.gz | tar xz --strip 1 -C /opt/novnc/utils/websockify" \
      --run "ln -s /opt/novnc/vnc_lite.html /opt/novnc/index.html" \
      --run "printf '\$localhost = \"no\";\n1;\n' >/etc/tigervnc/vncserver-config-defaults" \
      --copy template/build/src/vnc_startup.sh /opt/vnc_startup.sh \
      --copy fsl_gui_template/build/src/fsl.sh /etc/profile.d/fsl.sh \
      --copy fsl_gui_template/build/src/fsl_start.sh /usr/local/bin/fsl \
      --copy fsl_gui_template/build/src/fsl.desktop /usr/share/applications/fsl.desktop \
    > "bc_${app_name}/${app_name}_${app_version}.${CONTAINER_FILE}"
    mkdir -p "${CONTAINER_REPOS}/${app_name}"
    if [ "${CONTAINER}" = "docker" ]; then
      # TODO: Build and publish Docker env
      echo "Docker not supported"
    elif [ "${CONTAINER}" = "singularity" ]; then
      # Make sure we don't overwrite the container
      if [ -f "${CONTAINER_REPOS}/${app_name}/${app_name}_${app_version}.sif" ]; then
        echo "Singularity container already exists, skipping"
      else
        singularity build ${CONTAINER_REPOS}/${app_name}/${app_name}_${app_version}.sif bc_${app_name}/${app_name}_${app_version}.def
        echo "Done building Singularity container"
      fi
    fi
    yq -i '.attributes.app_version.options += [[ "'"${app_version}"'", "'"${app_version}"'"]]' bc_${app_name}/form.yml
    yq -i '.attributes.app_version.options += [[ "'"${app_version}"'", "'"${app_version}"'"]]' bc_${app_name}_gui/form.yml
  done
}

########################################################################################################################
# Spaceranger
########################################################################################################################
build_spaceranger() {
  app_name="spaceranger"
  app_version="3.1.3"
  gen_template "spaceranger" "Space Ranger"
  echo "Building spaceranger"
  neurodocker generate ${CONTAINER} \
    --pkg-manager apt \
    --base-image debian:bullseye-slim \
    --yes \
    --install supervisor xfce4 xfce4-terminal xterm dbus-x11 libdbus-glib-1-2 vim wget net-tools locales bzip2 tmux \
              procps apt-utils python3-numpy mesa-utils pulseaudio tigervnc-standalone-server libnss-wrapper gettext \
    --run "curl -L --output /usr/bin/ttyd https://github.com/tsl0922/ttyd/releases/download/1.7.7/ttyd.i686" \
    --run "chmod +x /usr/bin/ttyd" \
    --run "echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen && locale-gen" \
    --copy /opt/ood_apps/spaceranger/spaceranger-3.1.3.tar.gz /opt/spaceranger-3.1.3.tar.gz \
    --run "tar -xvf /opt/spaceranger-3.1.3.tar.gz -C /opt/spaceranger" \
    --run "rm /opt/spaceranger-3.1.3.tar.gz" \
    --run "cp /opt/spaceranger/sourceme.bash /etc/profile.d/spaceranger.sh" \
  > "bc_${app_name}/${app_name}_${app_version}.${CONTAINER_FILE}"
  mkdir -p "${CONTAINER_REPOS}/${app_name}"
  if [ "${CONTAINER}" = "docker" ]; then
    # TODO: Build and publish Docker env
    echo "Docker not supported"
  elif [ "${CONTAINER}" = "singularity" ]; then
    # Make sure we don't overwrite the container
    if [ -f "${CONTAINER_REPOS}/${app_name}/${app_name}_${app_version}.sif" ]; then
      echo "Singularity container already exists, skipping"
    else
      singularity build ${CONTAINER_REPOS}/${app_name}/${app_name}_${app_version}.sif bc_${app_name}/${app_name}_${app_version}.def
      echo "Done building Singularity container"
    fi
  fi
  yq -i '.attributes.app_version.options += [[ "'"${app_version}"'", "'"${app_version}"'"]]' bc_${app_name}/form.yml
}


########################################################################################################################
# QUPath
########################################################################################################################
build_qupath() {
  app_name="qupath"
  app_version="0.5.1"
  gen_template "qupath" "QuPath"
  echo "Building qupath"
  neurodocker generate ${CONTAINER} \
      --pkg-manager apt \
      --base-image ubuntu:24.04 \
      --yes \
      --install supervisor xfce4 xfce4-terminal xterm dbus-x11 libdbus-glib-1-2 vim wget net-tools locales bzip2 tmux \
                procps apt-utils python3-numpy mesa-utils pulseaudio tigervnc-standalone-server libnss-wrapper gettext \
      --run "curl -L --output /tmp/tigervnc.deb https://versaweb.dl.sourceforge.net/project/tigervnc/stable/1.14.1/ubuntu-24.04LTS/amd64/tigervncserver_1.14.1-1ubuntu1_amd64.deb" \
      --run "dpkg -i /tmp/tigervnc.deb" \
      --run "curl -L --output /usr/bin/ttyd https://github.com/tsl0922/ttyd/releases/download/1.7.7/ttyd.i686" \
      --run "chmod +x /usr/bin/ttyd" \
      --run "echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen && locale-gen" \
      --run "mkdir -p /opt/novnc/utils/websockify" \
      --run "curl -sL https://github.com/novnc/noVNC/archive/refs/tags/v1.6.0.tar.gz | tar xz --strip 1 -C /opt/novnc" \
      --run "wget -qO- https://github.com/novnc/websockify/archive/refs/tags/v0.13.0.tar.gz | tar xz --strip 1 -C /opt/novnc/utils/websockify" \
      --run "ln -s /opt/novnc/vnc_lite.html /opt/novnc/index.html" \
      --run "printf '\$localhost = \"no\";\n1;\n' >/etc/tigervnc/vncserver-config-defaults" \
      --copy template/build/src/vnc_startup.sh /opt/vnc_startup.sh \
  > "bc_${app_name}/${app_name}_${app_version}.${CONTAINER_FILE}"
  mkdir -p "${CONTAINER_REPOS}/${app_name}"
  if [ "${CONTAINER}" = "docker" ]; then
    # TODO: Build and publish Docker env
    echo "Docker not supported"
  elif [ "${CONTAINER}" = "singularity" ]; then
    # Make sure we don't overwrite the container
    if [ -f "${CONTAINER_REPOS}/${app_name}/${app_name}_${app_version}.sif" ]; then
      echo "Singularity container already exists, skipping"
    else
      singularity build ${CONTAINER_REPOS}/${app_name}/${app_name}_${app_version}.sif bc_${app_name}/${app_name}_${app_version}.def
      echo "Done building Singularity container"
    fi
  fi
  yq -i '.attributes.app_version.options += [[ "'"${app_version}"'", "'"${app_version}"'"]]' bc_${app_name}/form.yml
}