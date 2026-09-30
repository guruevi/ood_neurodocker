build_hdglio() {
  app_name="hd-glio"
  HDGLIO_VERSIONS=('2.0')
  gen_template "${app_name}" "HD-GLIO" "MRI Analysis" "fa://brain"
  gen_template "${app_name}_gui" "HD-GLIO (GUI)" "MRI Analysis" "fa://brain"
  for app_version in "${HDGLIO_VERSIONS[@]}"; do
    echo "Building ${app_name}_${app_version}"
    "${ND_GEN_COMMAND[@]}" \
      --base-image nvcr.io/nvidia/cuda:11.8.0-runtime-ubuntu22.04 \
      --ttyd version=1.7.7 \
      --virtualenv python_version="3.10" venv="hd_glio" packages="hd_glio==${app_version}" \
      "${ND_GEN_ARGS[@]}" \
    > "bc_${app_name}/${app_name}_${app_version}.${CONTAINER_FILE}"
    gen_container ${app_name} ${app_version}
  done
}
