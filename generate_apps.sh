#!/usr/bin/env bash
CONTAINER="singularity"
CONTAINER_REPOS="/opt/ood_apps/images"
APPS="afni ants bids_validator cat12 convert3d dcm2niix freesurfer fsl fsl_gui jq matlabmcr minc miniconda mricron mrtrix3 ndfreeze neurodebian niftyreg petpvc spm12 vnc"

set_title() {
  yq -i '.title = "'"${2}"'"' bc_"$1"/form.yml
  yq -i '.attributes.bc_account = "'"${1}"'"' bc_"$1"/form.yml
  yq -i '.name = "'"${2}"'"' bc_"$1"/manifest.yml
  yq -i '.description = "'"${2}"'"' bc_"$1"/manifest.yml
}

if CONTAINER="singularity"; then
  CONTAINER_FILE="def"
elif CONTAINER="docker"; then
  CONTAINER_FILE="Dockerfile"
fi

for app in $APPS; do
  echo "Building ${app}"
  rsync -a template/ "bc_${app}"/
  if [ -d "${app}"_template ]; then
    rsync -a "${app}"_template/ "bc_${app}"/
  fi
done

########################################################################################################################
# AFNI
########################################################################################################################
AFNI_VERSIONS=('25.0.06')
app_name="afni"
set_title "afni" "AFNI"
set_title "afni_gui" "AFNI (GUI)"
for app_version in "${AFNI_VERSIONS[@]}"; do
  echo "Building ${app_name}_${app_version}"
  neurodocker generate ${CONTAINER} \
    --pkg-manager yum \
    --base-image fedora:36 \
    --afni method=binaries version="${app_version}" install_r_pkgs=true \
    --install supervisor xfce4 xfce4-terminal xterm dbus-x11 dbus-glib vim wget net-tools bzip2 procps-ng mesa-dri-drivers pulseaudio tigervnc-server nss_wrapper gettext \
    --run "curl -L --output /usr/bin/ttyd https://github.com/tsl0922/ttyd/releases/download/1.7.7/ttyd.i686" \
    --run "chmod +x /usr/bin/ttyd" \
    --run "echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen && locale-gen" \
    --run "mkdir -p /opt/novnc/utils/websockify" \
    --run "curl -sL https://github.com/novnc/noVNC/archive/refs/tags/v1.5.0.tar.gz | tar xz --strip 1 -C /opt/novnc" \
    --run "ln -s /opt/novnc/vnc_lite.html /opt/novnc/index.html" \
    --run "printf '\n# docker-headless-vnc-container:\n\$localhost = \"no\";\n1;\n\' >>/etc/tigervnc/vncserver-config-defaults" \
    --copy template/build/src/vnc_startup.sh /opt/vnc_startup.sh \
  > "bc_${app_name}/${app_name}_${app_version}.${CONTAINER_FILE}"
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

########################################################################################################################
# FSL
########################################################################################################################
FSL_VERSIONS=('6.0.6.1' '6.0.5.1' '5.0.10' '5.0.11' '6.0.0' '6.0.2' '6.0.1' '6.0.6.2' '6.0.3' '6.0.4' '5.0.8' '6.0.5.2' '6.0.7.4' '6.0.6' '5.0.9' '6.0.5' '6.0.6.4' '6.0.7.1' '6.0.6.3')
FSL_VERSIONS=($(printf "%s\n" "${FSL_VERSIONS[@]}" | sort -rV))

set_title "fsl" "FSL (Terminal)"
set_title "fsl_gui" "FSL (GUI)"
for fsl_version in "${FSL_VERSIONS[@]}"; do
  echo "Building fsl_${fsl_version}"
  neurodocker generate ${CONTAINER} \
    --pkg-manager apt \
    --base-image debian:bullseye-slim \
    --fsl version="${fsl_version}" \
    --yes \
    --install supervisor xfce4 xfce4-terminal xterm dbus-x11 libdbus-glib-1-2 vim wget net-tools locales bzip2 procps apt-utils python3-numpy mesa-utils pulseaudio tigervnc-standalone-server libnss-wrapper gettext \
    --run "curl -L --output /usr/bin/ttyd https://github.com/tsl0922/ttyd/releases/download/1.7.7/ttyd.i686" \
    --run "chmod +x /usr/bin/ttyd" \
    --run "echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen && locale-gen" \
    --run "mkdir -p /opt/novnc/utils/websockify" \
    --run "curl -sL https://github.com/novnc/noVNC/archive/refs/tags/v1.5.0.tar.gz | tar xz --strip 1 -C /opt/novnc" \
    --run "ln -s /opt/novnc/vnc_lite.html /opt/novnc/index.html" \
    --run "printf '\n# docker-headless-vnc-container:\n\$localhost = \"no\";\n1;\n\' >>/etc/tigervnc/vncserver-config-defaults" \
    --copy template/build/src/vnc_startup.sh /opt/vnc_startup.sh
  > "bc_fsl/fsl_${fsl_version}.${CONTAINER_FILE}"
  if [ "${CONTAINER}" = "docker" ]; then
    # TODO: Build and publish Docker env
    echo "Docker not supported"
  elif [ "${CONTAINER}" = "singularity" ]; then
    # Make sure we don't overwrite the container
    if [ -f "${CONTAINER_REPOS}/fsl/fsl_"${fsl_version}".sif" ]; then
      echo "Singularity container already exists, skipping"
    else
      singularity build ${CONTAINER_REPOS}/fsl/fsl_"${fsl_version}".sif bc_fsl/fsl_"${fsl_version}".def
      echo "Done building Singularity container"
    fi
  fi
  yq -i '.attributes.app_version.options += [[ "'"${fsl_version}"'", "'"${fsl_version}"'"]]' bc_fsl/form.yml
  yq -i '.attributes.app_version.options += [[ "'"${fsl_version}"'", "'"${fsl_version}"'"]]' bc_fsl_gui/form.yml
done
