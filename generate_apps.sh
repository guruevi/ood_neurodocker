#!/usr/bin/env bash
CONTAINER="singularity"
CONTAINER_REPOS="/opt/ood_apps/images/"
APPS="afni ants bids_validator cat12 convert3d dcm2niix freesurfer fsl jq matlabmcr minc miniconda mricron mrtrix3 ndfreeze neurodebian niftyreg petpvc spm12 vnc"

if CONTAINER="singularity"; then
  CONTAINER_FILE="def"
elif CONTAINER="docker"; then
  CONTAINER_FILE="Dockerfile"
fi

set_title() {
  yq -i '.title = "'"${2}"'"' bc_"$1"/form.yml
  yq -i '.name = "'"${2}"'"' bc_"$1"/manifest.yml
  yq -i '.attributes.bc_account = "'"${1}"'"' bc_"$1"/form.yml
}

FSL_VERSIONS=('6.0.6.1' '6.0.5.1' '5.0.10' '5.0.11' '6.0.0' '6.0.2' '6.0.1' '6.0.6.2' '6.0.3' '6.0.4' '5.0.8' '6.0.5.2' '6.0.7.4' '6.0.6' '5.0.9' '6.0.5' '6.0.6.4' '6.0.7.1' '6.0.6.3')
FSL_VERSIONS=($(printf "%s\n" "${FSL_VERSIONS[@]}" | sort -rV))

for app in $APPS; do
  echo "Building ${app}"
  rsync -a template/ "bc_${app}"/
  if [ -d "${app}"_template ]; then
    rsync -a "${app}"_template/ "bc_${app}"/
  fi
done

set_title "fsl" "FSL (FMRIB Software Library)"
for fsl_version in "${FSL_VERSIONS[@]}"; do
  echo "Building fsl_${fsl_version}"
  neurodocker generate ${CONTAINER} \
    --pkg-manager apt \
    --base-image neurodebian \
    --fsl version=${fsl_version} \
    --yes \
    --install ttyd \
  > bc_fsl/fsl_"${fsl_version}"."${CONTAINER_FILE}"
  if [ "${CONTAINER}" = "docker" ]; then
    # TODO: Build and publish Docker env
    echo "Docker not supported"
  elif [ "${CONTAINER}" = "singularity" ]; then
    # singularity build bc_fsl/fsl_"${fsl_version}".def ${CONTAINER_REPOS}/fsl/fsl_"${fsl_version}".sif
    echo "Singularity not supported"
  fi
  yq -i '.attributes.app_version.options += [[ "'"${fsl_version}"'", "'"${fsl_version}"'"]]' bc_fsl/form.yml
done
