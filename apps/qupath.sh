build_qupath() {
  app_name="qupath"
  app_version="0.5.1"
  gen_template "qupath" "QuPath (Shell)" "Image Processing" "fa://magnifying-glass"
  gen_template "qupath_gui" "QuPath (GUI)" "Image Processing" "fa://magnifying-glass"
  echo "Building qupath"
  "${ND_GEN_COMMAND[@]}" "${ND_GEN_ARGS[@]}" \
      --base-image nvcr.io/nvidia/cuda:11.8.0-runtime-ubuntu22.04 \
      --run "echo '$GLOBAL_PIP_CONF' > /etc/pip.conf" \
      --novnc websockify_version="e81894751365afc19fe64fc9d0e5c6fc52655c36" novnc_proxy_version="7f5b51acf35963d125992bb05d32aa1b68cf87bf" \
      --kasmvnc de=xfce kasm_distro="jammy" single_app="/opt/QuPath/bin/qupath" \
      --qupath version=${app_version} \
  > "bc_${app_name}/${app_name}_${app_version}.${CONTAINER_FILE}"
  gen_container ${app_name} ${app_version}
  sed -i 's@export SINGULARITYENV_APPEND_PATH=""@export SINGULARITYENV_APPEND_PATH="/opt/QuPath/bin"@' bc_${app_name}/template/script.sh.erb
  sed -i 's@export SINGULARITYENV_APPEND_PATH=""@export SINGULARITYENV_APPEND_PATH="/opt/QuPath/bin"@' bc_${app_name}_gui/template/script.sh.erb
}
