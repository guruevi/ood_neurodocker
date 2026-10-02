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
if [ -z "${ND_GEN_COMMAND}" ]; then
  ND_GEN_COMMAND=(neurodocker generate --template-path nd_templates ${CONTAINER})
fi
if [ -z "${ND_GEN_ARGS}" ]; then
  ND_GEN_ARGS=(--user nonroot --pkg-manager apt --yes)
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
else
  echo "No PIP config found"
  exit 2
fi
GLOBAL_PIP_CONF=$(cat "${GLOBAL_PIP_CONF}")

gen_template() {
  app=$1
  title=$2
  subcategory=$3
  icon=$4
  bc_account="${app/_gui/}"

  # Merge the templates
  rsync -a template/ "bc_${app}"/
  if [ -d "${app}"_template ]; then
    rsync -a "${app}"_template/ "bc_${app}"/
  fi

  # Update the form and manifest files
  yq -i '.title = "'"${title}"'" | .attributes.bc_account = "'"${bc_account}"'"' bc_"${app}"/form.yml
  yq -i '.name = "'"${title}"'" | .subcategory = "'"${subcategory}"'"' bc_"${app}"/manifest.yml

  # Use custom icon if provided
  if [ -f "bc_${app}/icon.png" ]; then
    yq -i 'del(.icon)' bc_"${app}"/manifest.yml
  else
    yq -i '.icon = "'"${icon}"'"' bc_"${app}"/manifest.yml
  fi
}

gen_container() {
  app_name=$1
  app_version=$2
  mkdir -p "${CONTAINER_REPOS}/${app_name}"
    if [ "${CONTAINER}" = "docker" ]; then
      docker buildx build --platform linux/amd64 -t ${app_name}:${app_version} -f bc_${app_name}/${app_name}_${app_version}.Dockerfile .
    elif [ "${CONTAINER}" = "singularity" ]; then
      # Make sure we don't overwrite the container
      if [ -z "${SKIP_SIF_CHECK}" ] && [ -f "${CONTAINER_REPOS}/${app_name}/${app_name}_${app_version}.sif" ]; then
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
for app_script in "${SCRIPT_DIR}/apps"/*.sh; do
  if [ -f "${app_script}" ]; then
    source "${app_script}"
  fi
done