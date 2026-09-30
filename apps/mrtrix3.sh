build_mrtrix3() {
  app_name="mrtrix3"
  MRTRIX3_VERSIONS=('3.0.8')
  gen_template "${app_name}" "MRtrix3 (Shell)" "MRI Analysis" "fa://brain"
  gen_template "${app_name}_gui" "MRtrix3 (GUI)" "MRI Analysis" "fa://brain"
  for app_version in "${MRTRIX3_VERSIONS[@]}"; do
    echo "Building ${app_name}_${app_version}"
    "${ND_GEN_COMMAND[@]}" "${ND_GEN_ARGS[@]}" \
      --base-image mrtrix3/mrtrix3:${app_version} \
      --ttyd version=1.7.7 addpath=/opt/mrtrix3/bin \
      --kasmvnc de=xfce kasm_distro="bookworm" single_app="/opt/mrtrix3/bin/mrview" \
    > "bc_${app_name}/${app_name}_${app_version}.${CONTAINER_FILE}"
    gen_container ${app_name} ${app_version}
  done
}
