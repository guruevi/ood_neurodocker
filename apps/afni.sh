build_afni() {
  app_name="afni"
  AFNI_VERSIONS=($(date +%Y%m%d))
  gen_template ${app_name} "AFNI (Shell)" "MRI Analysis" "fa://brain"
  gen_template "${app_name}_gui" "AFNI (GUI)" "MRI Analysis"
  for app_version in "${AFNI_VERSIONS[@]}"; do
    echo "Building ${app_name}_${app_version}"
    "${ND_GEN_COMMAND[@]}" "${ND_GEN_ARGS[@]}" \
      --base-image ubuntu:24.04 \
      --kasmvnc de=xfce kasm_distro="noble" \
      --ttyd version=1.7.7 \
      --afni ubuntu_version="24" \
    > "bc_${app_name}/${app_name}_${app_version}.${CONTAINER_FILE}"
    gen_container ${app_name} ${app_version}
  done
}
