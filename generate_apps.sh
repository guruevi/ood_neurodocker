#!/usr/bin/env bash
if [ -z "${CONTAINER}" ]; then
  CONTAINER="singularity"
fi
if [ -z "${CONTAINER_REPOS}" ]; then
  CONTAINER_REPOS="/opt/ood_apps/images"
fi
if [ -z "${SINGULARITY_BIN}" ]; then
  SINGULARITY_BIN="/bin/singularity"
fi
if [ -z "${SINGULARITY_TMPDIR}" ]; then
  SINGULARITY_TMPDIR="/opt/ood_apps/images/.tmp"
fi
if [ -z "${SINGULARITY_CACHEDIR}" ]; then
  SINGULARITY_CACHEDIR="/opt/ood_apps/images/.cache"
fi
# APPS="afni afni_gui ants bids_validator cat12 convert3d dcm2niix freesurfer fsl fsl_gui jq matlabmcr minc miniconda mricron mrtrix3 ndfreeze neurodebian niftyreg petpvc spm12 vnc spaceranger"

if [ "$CONTAINER" = "singularity" ]; then
  CONTAINER_FILE="def"
elif [ "$CONTAINER" = "docker" ]; then
  CONTAINER_FILE="Dockerfile"
else
  echo "Unknown container type: $CONTAINER"
  exit 1
fi

# Test if yq is on path
if ! command -v yq &> /dev/null; then
  echo "yq could not be found"
  exit 1
fi

gen_template() {
  app=$1
  title=$2
  subcategory=$3
  icon=$4
  rsync -a template/ "bc_${app}"/
  if [ -d "${app}"_template ]; then
    rsync -a "${app}"_template/ "bc_${app}"/
  fi

  bc_account="${app/_gui/}"
  yq -i '.title = "'"${title}"'"' bc_"${app}"/form.yml
  yq -i '.attributes.bc_account = "'"${bc_account}"'"' bc_"${app}"/form.yml
  yq -i '.name = "'"${title}"'"' bc_"${app}"/manifest.yml
  yq -i '.subcategory = "'"${subcategory}"'"' bc_"${app}"/manifest.yml

  # Remove the icon pointer if a file exists
  if [ -f "bc_${app}/icon.png" ]; then
    yq -i 'del(.icon)' bc_"${app}"/manifest.yml
  else
    yq -i '.icon = "'"${icon}"'"' bc_"${app}"/manifest.yml
  fi

  yq -i '.description = "This will launch an interactive shell with '"${title}"' pre-installed. You
                         will have full access to the resources requested. This is analogous
                         to an interactive batch job."' bc_"${app}"/manifest.yml
}

########################################################################################################################
# DOOM
########################################################################################################################
build_doom() {
  app_name="doom"
  DOOM_VERSION=($(date +%Y%m%d))
  gen_template "${app_name}" "DOOM (Shell)" "DOOM"
  gen_template "${app_name}_gui" "DOOM (GUI)" "DOOM (GUI)" "fa://gamepad"
  for app_version in "${DOOM_VERSION[@]}"; do
    echo "Building ${app_name}_${app_version}"
    neurodocker generate --template-path nd_templates "${CONTAINER}" \
      --pkg-manager apt \
      --base-image ubuntu:noble \
      --kasmvnc de=xfce kasm_distro="noble" but_can_it_run_doom="Y" \
      --user nonroot \
    > "bc_${app_name}/${app_name}_${app_version}.${CONTAINER_FILE}"
    mkdir -p "${CONTAINER_REPOS}/${app_name}"
    if [ "${CONTAINER}" = "docker" ]; then
      docker buildx build --platform linux/amd64 -t ${app_name}:${app_version} -f bc_${app_name}/${app_name}_${app_version}.Dockerfile .
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
# AFNI
########################################################################################################################
build_afni() {
  app_name="afni"
  AFNI_VERSIONS=($(date +%Y%m%d))
  gen_template ${app_name} "AFNI (Shell)" "MRI Analysis" "fa://brain"
  gen_template "${app_name}_gui" "AFNI (GUI)" "MRI Analysis"
  for app_version in "${AFNI_VERSIONS[@]}"; do
    echo "Building ${app_name}_${app_version}"
    neurodocker generate --template-path nd_templates "${CONTAINER}" \
      --pkg-manager apt \
      --base-image ubuntu:24.04 \
      --kasmvnc de=xfce kasm_distro="noble" \
      --afni ubuntu_version="24" \
      --user nonroot \
    > "bc_${app_name}/${app_name}_${app_version}.${CONTAINER_FILE}"
    mkdir -p "${CONTAINER_REPOS}/${app_name}"
    if [ "${CONTAINER}" = "docker" ]; then
      docker buildx build --platform linux/amd64 -t ${app_name}:${app_version} -f bc_${app_name}/${app_name}_${app_version}.Dockerfile .
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
  gen_template "fsl" "FSL (Shell)" "MRI Analysis" "fa://brain"
  gen_template "fsl_gui" "FSL (GUI)" "MRI Analysis" "fa://brain"
  for app_version in "${FSL_VERSIONS[@]}"; do
    echo "Building fsl_${app_version}"
    neurodocker generate ${CONTAINER} \
      --pkg-manager apt \
      --base-image debian:bullseye-slim \
      --fsl version="${app_version}" \
      --yes \
      --run "export DEBIAN_FRONTEND=noninteractive TZ=America/New_York" \
      --install supervisor xfce4 xfce4-terminal xterm dbus-x11 libdbus-glib-1-2 vim wget net-tools locales bzip2 tmux \
                procps apt-utils python3-numpy mesa-utils pulseaudio tigervnc-standalone-server libnss-wrapper gettext \
      --run "curl -L --output /usr/bin/ttyd https://github.com/tsl0922/ttyd/releases/download/1.7.7/ttyd.i686" \
      --run "chmod +x /usr/bin/ttyd" \
      --run "echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen && locale-gen" \
      --run "mkdir -p /opt/novnc/utils/websockify" \
      --run "curl -sL https://github.com/novnc/noVNC/archive/refs/tags/v1.6.0.tar.gz | tar xz --strip 1 -C /opt/novnc" \
      --run "curl -sL https://github.com/novnc/websockify/archive/refs/tags/v0.12.0.tar.gz | tar xz --strip 1 -C /opt/novnc/utils/websockify" \
      --run "ln -s /opt/novnc/vnc_lite.html /opt/novnc/index.html" \
      --run "printf '\$localhost = \"no\";\n1;\n' >/etc/tigervnc/vncserver-config-defaults" \
      --copy fsl_gui_template/build/src/fsl.sh /etc/profile.d/fsl.sh \
      --copy fsl_gui_template/build/src/fsl_start.sh /usr/local/bin/fsl \
      --copy ${app_name}_gui_template/build/src/${app_name}.desktop /usr/share/applications/${app_name}.desktop \
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
  gen_template "spaceranger" "Space Ranger" "Omics" "fa://shuttle-space"
  echo "Building spaceranger"
  neurodocker generate ${CONTAINER} \
    --pkg-manager apt \
    --base-image debian:bullseye-slim \
    --yes \
    --run "export DEBIAN_FRONTEND=noninteractive TZ=America/New_York" \
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
  sed -i 's@export SINGULARITYENV_APPEND_PATH=""@export SINGULARITYENV_APPEND_PATH="/opt/spaceranger/bin"@' bc_${app_name}/template/script.sh.erb
}


########################################################################################################################
# QUPath
########################################################################################################################
build_qupath() {
  app_name="qupath"
  app_version="0.5.1"
  gen_template "qupath" "QuPath (Shell)" "Image Processing" "fa://magnifying-glass"
  gen_template "qupath_gui" "QuPath (GUI)" "Image Processing" "fa://magnifying-glass"
  echo "Building qupath"
  neurodocker generate --template-path nd_templates "${CONTAINER}" \
      --pkg-manager apt \
      --base-image nvcr.io/nvidia/cuda:11.8.0-runtime-ubuntu22.04 \
      --yes \
      --novnc websockify_version="e81894751365afc19fe64fc9d0e5c6fc52655c36" novnc_proxy_version="7f5b51acf35963d125992bb05d32aa1b68cf87bf" \
      --qupath version=${app_version} \
      --user nonroot \
  > "bc_${app_name}/${app_name}_${app_version}.${CONTAINER_FILE}"
  mkdir -p "${CONTAINER_REPOS}/${app_name}"
  if [ "${CONTAINER}" = "docker" ]; then
    docker buildx build --platform linux/amd64 -t qupath:${app_version} -f bc_qupath/qupath_${app_version}.Dockerfile .
  elif [ "${CONTAINER}" = "singularity" ]; then
    # Make sure we don't overwrite the container
    if [ -f "${CONTAINER_REPOS}/${app_name}/${app_name}_${app_version}.sif" ]; then
      echo "Singularity container already exists, skipping"
    else
      singularity build --nv ${CONTAINER_REPOS}/${app_name}/${app_name}_${app_version}.sif bc_${app_name}/${app_name}_${app_version}.def
      echo "Done building Singularity container"
    fi
  fi
  yq -i '.attributes.app_version.options += [[ "'"${app_version}"'", "'"${app_version}"'"]]' bc_${app_name}/form.yml
  yq -i '.attributes.app_version.options += [[ "'"${app_version}"'", "'"${app_version}"'"]]' bc_${app_name}_gui/form.yml
  sed -i 's@export SINGULARITYENV_APPEND_PATH=""@export SINGULARITYENV_APPEND_PATH="/opt/QuPath/bin"@' bc_${app_name}/template/script.sh.erb
  sed -i 's@export SINGULARITYENV_APPEND_PATH=""@export SINGULARITYENV_APPEND_PATH="/opt/QuPath/bin"@' bc_${app_name}_gui/template/script.sh.erb
}

########################################################################################################################
# MATLAB
########################################################################################################################
build_matlab() {
  app_name="matlab"
  # To check the available matlab-deps images, see: https://hub.docker.com/r/mathworks/matlab-deps
  base_repo="mathworks/matlab-deps"

  MATLAB_VERSIONS=('R2024a' 'R2023b' 'R2023a' 'R2022b' 'R2022a' 'R2021b' 'R2021a' 'R2020b' 'R2020a')
  gen_template "matlab" "MATLAB (Shell)" "Image Processing" "fa://cogs"
  gen_template "matlab_gui" "MATLAB (GUI)" "Image Processing" "fa://cogs"
  echo "Building MATLAB"

  for app_version in "${MATLAB_VERSIONS[@]}"; do
    ### Generate  ###
    neurodocker generate --template-path nd_templates "${CONTAINER}" \
        --pkg-manager apt \
        --base-image ${base_repo}:"${app_version}" \
        --yes \
        --ttyd version=1.7.7 \
        --matlab version="${app_version}" \
        --user nonroot \
    > "bc_${app_name}/${app_name}_${app_version}.${CONTAINER_FILE}"

    ### Build ###
    # Make sure the destination exists
    mkdir -p "${CONTAINER_REPOS}/${app_name}"
    if [ "${CONTAINER}" = "docker" ]; then
      docker buildx build --platform linux/amd64 -t ${base_repo}:"${app_version}" -f bc_${app_name}/${app_name}_"${app_version}".Dockerfile .
    elif [ "${CONTAINER}" = "singularity" ]; then
      # Make sure we don't overwrite the container
      if [ -f "${CONTAINER_REPOS}/${app_name}/${app_name}_${app_version}.sif" ]; then
        echo "Singularity container already exists, skipping"
      else
        singularity build --nv "${CONTAINER_REPOS}"/${app_name}/${app_name}_"${app_version}".sif bc_${app_name}/${app_name}_"${app_version}".def
        echo "Done building Singularity container"
      fi
    fi
    yq -i '.attributes.app_version.options += [[ "'"${app_version}"'", "'"${app_version}"'"]]' bc_${app_name}/form.yml
    yq -i '.attributes.app_version.options += [[ "'"${app_version}"'", "'"${app_version}"'"]]' bc_${app_name}_gui/form.yml
  done
}