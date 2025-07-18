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

# Test if we have a global pip config file
if [ -f /etc/pip.conf ]; then
  GLOBAL_PIP_CONF="/etc/pip.conf"
elif [ -f /etc/xdg/pip/pip.conf ]; then
  GLOBAL_PIP_CONF="/etc/xdg/pip/pip.conf"
elif [ -f /Library/Application\ Support/pip/pip.conf ]; then
  GLOBAL_PIP_CONF="/Library/Application Support/pip/pip.conf"
elif [ -f "$HOME/.config/pip/pip.conf" ]; then
  GLOBAL_PIP_CONF="$HOME/.config/pip/pip.conf"
fi
GLOBAL_PIP_CONF=`cat "${GLOBAL_PIP_CONF}"`

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

gen_container() {
  app_name=$1
  app_version=$2
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
    if [ -f "bc_${app_name}/form.yml" ]; then
      yq -i '.attributes.app_version.options += [[ "'"${app_version}"'", "'"${app_version}"'"]]' bc_${app_name}/form.yml
    fi
    if [ -f "bc_${app_name}_gui/form.yml" ]; then
      yq -i '.attributes.app_version.options += [[ "'"${app_version}"'", "'"${app_version}"'"]]' bc_${app_name}_gui/form.yml
    fi
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
      --ttyd version=1.7.7 \
      --kasmvnc de=xfce kasm_distro="noble" but_can_it_run_doom="Y" \
      --user nonroot \
    > "bc_${app_name}/${app_name}_${app_version}.${CONTAINER_FILE}"
    gen_container ${app_name} ${app_version}
  done
}

########################################################################################################################
# ANTS
########################################################################################################################
build_ants() {
  app_name="ants"
  APP_VERSIONS=($(date +%Y%m%d))
  gen_template "${app_name}" "ANTS (Shell)" "ANTS"
  #gen_template "${app_name}_gui" "ANTS (GUI)" "ANTS (GUI)"
  for app_version in "${APP_VERSIONS[@]}"; do
    echo "Building ${app_name}_${app_version}"
    neurodocker generate --template-path nd_templates "${CONTAINER}" \
      --pkg-manager apt \
      --base-image ubuntu:noble \
      --ttyd version=1.7.7 \
      --ants version=2.6.0 \
      --user nonroot \
    > "bc_${app_name}/${app_name}_${app_version}.${CONTAINER_FILE}"
    gen_container ${app_name} ${app_version}
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
      --ttyd version=1.7.7 \
      --afni ubuntu_version="24" \
      --user nonroot \
    > "bc_${app_name}/${app_name}_${app_version}.${CONTAINER_FILE}"
    gen_container ${app_name} ${app_version}
  done
}

########################################################################################################################
# RSTUDIO
########################################################################################################################
build_rstudio() {
  app_name="rstudio"

  # 4.5 is not yet available in the rocker/ml-verse images
  # When changing RStudio versions, also update the bioconductor version
  RSTUDIO_VERSIONS=('4.5.0' '4.4.1' '4.3.0')
  declare -A BIOCONDUCTOR_VERSIONS=(
    ["4.5.0"]="3.21"
    ["4.4.1"]="3.20"
    ["4.3.0"]="3.17"
  )
  ML_VERSE_VERSIONS=("4.4.1" "4.3.0")

  gen_template ${app_name} "R (Shell)" "Servers"
  gen_template "${app_name}_gui" "RStudio (GUI)" "Servers"
  for app_version in "${RSTUDIO_VERSIONS[@]}"; do
    echo "Building ${app_name}_${app_version}"
    for variant in "r-ver" "ml-verse"; do
      # Generate the container definition
      if ! docker manifest inspect docker.io/rocker/${variant}:${app_version} > /dev/null 2>&1; then
        echo "Does not appear that rocker/${variant}:${app_version} is available, skipping"
        continue
      fi
      base_image="rocker/${variant}:${app_version}"
      for with_libs in "" "-Seurat"; do
        # BioConductor is small enough, always included it
        bioconductor="${BIOCONDUCTOR_VERSIONS[$app_version]}"
        # Check if we are Seurat
        if [[ "$with_libs" = *Seurat* ]]; then
          seurat="Y"
        else
          seurat="N"
        fi
        echo "Building ${app_name}_${app_version} (${variant})"
        neurodocker generate --template-path nd_templates "${CONTAINER}" \
          --pkg-manager apt \
          --base-image $base_image \
          --run "echo '$GLOBAL_PIP_CONF' > /etc/pip.conf" \
          --ttyd version="1.7.7" \
          --rstudio addons="remotes" seurat="$seurat" bioconductor="$bioconductor" rprofile='options(BioC_mirror = "https://smdartifactory.urmc-sh.rochester.edu/artifactory/bioconductor")\noptions(repos = "https://smdartifactory.urmc-sh.rochester.edu/artifactory/cran-remote")' \
          --user rstudio \
        > "bc_${app_name}/${app_name}_${app_version}-${variant}${with_libs}.${CONTAINER_FILE}"
        gen_container ${app_name} ${app_version}-${variant}${with_libs}
      done
    done
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
    gen_container ${app_name} ${app_version}
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
    --ttyd version=1.7.7 \
    --kasmvnc de=xfce kasm_distro="bullseye" \
    --yes \
    --copy /opt/ood_apps/spaceranger/spaceranger-3.1.3.tar.gz /opt/spaceranger-3.1.3.tar.gz \
    --run "tar -xvf /opt/spaceranger-3.1.3.tar.gz -C /opt/spaceranger" \
    --run "rm /opt/spaceranger-3.1.3.tar.gz" \
    --run "cp /opt/spaceranger/sourceme.bash /etc/profile.d/spaceranger.sh" \
  > "bc_${app_name}/${app_name}_${app_version}.${CONTAINER_FILE}"
  gen_container ${app_name} ${app_version}
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
      --run "echo '$GLOBAL_PIP_CONF' > /etc/pip.conf" \
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
  gen_template "matlab" "MATLAB (Shell)" "Servers" "fa://cogs"
  gen_template "matlab_gui" "MATLAB (GUI)" "Servers" "fa://cogs"
  echo "Building MATLAB"

  for app_version in "${MATLAB_VERSIONS[@]}"; do
    ### Generate  ###
    neurodocker generate --template-path nd_templates "${CONTAINER}" \
        --pkg-manager apt \
        --base-image ${base_repo}:"${app_version}" \
        --run "echo '$GLOBAL_PIP_CONF' > /etc/pip.conf" \
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

########################################################################################################################
# fMRIprep
########################################################################################################################
build_fmriprep() {
  app_name="fmriprep"
  FMRIPREP_VERSIONS=('25.1.3' '24.1.1' '23.2.3' '22.1.1' ) # Add more versions as needed
  gen_template "${app_name}" "fMRIPrep" "MRI Analysis" "fa://brain"

  for app_version in "${FMRIPREP_VERSIONS[@]}"; do
    echo "Building ${app_name}_${app_version}"
    neurodocker generate --template-path nd_templates "${CONTAINER}" \
      --pkg-manager apt \
      --base-image nipreps/fmriprep:${app_version} \
      --run "echo '$GLOBAL_PIP_CONF' > /etc/pip.conf" \
      --ttyd version=1.7.7 \
      --copy $(pwd)/${app_name}_template/build/src/license.txt /usr/share/freesurfer_license.txt \
      --user nonroot \
    > "bc_${app_name}/${app_name}_${app_version}.${CONTAINER_FILE}"
    gen_container ${app_name} ${app_version}
  done
}

########################################################################################################################
# PyMOL
########################################################################################################################
build_pymol() {
  app_name="pymol"
  PYMOL_VERSIONS=('3.1.0')
  gen_template "${app_name}" "PyMOL" "Computational Biology" "fa://molecule"
  gen_template "${app_name}_gui" "PyMOL (GUI)" "Computational Biology" "fa://molecule"
  for app_version in "${PYMOL_VERSIONS[@]}"; do
    echo "Building ${app_name}_${app_version}"
    neurodocker generate --template-path nd_templates "${CONTAINER}" \
      --pkg-manager apt \
      --base-image ubuntu:noble \
      --ttyd version=1.7.7 \
      --run "echo '$GLOBAL_PIP_CONF' > /etc/pip.conf" \
      --kasmvnc de=xfce kasm_distro="noble" single_app="/opt/conda/envs/pymol-env/bin/pymol" \
      --micromamba mamba_dependencies="name: pymol-env\nchannels: [conda-forge]\ndependencies: [python=3.10, pip, pymol-open-source=$app_version, fretraj]" \
      --user nonroot \
    > "bc_${app_name}/${app_name}_${app_version}.${CONTAINER_FILE}"
    gen_container ${app_name} ${app_version}
  done
}