build_fsl() {
  ## '6.0.6.2' '6.0.6.1' '6.0.6' '6.0.5.2' '6.0.5.1' '6.0.5' '6.0.4' '6.0.3' '6.0.2' '6.0.1' '6.0.0' '5.0.11' '5.0.10' '5.0.9' '5.0.8'
  FSL_VERSIONS=('6.0.7.19' '6.0.6.4')
  app_name="fsl"
  gen_template "fsl" "FSL (Shell)" "MRI Analysis" "fa://brain"
  gen_template "fsl_gui" "FSL (GUI)" "MRI Analysis" "fa://brain"
  for app_version in "${FSL_VERSIONS[@]}"; do
    echo "Building fsl_${app_version}"
    "${ND_GEN_COMMAND[@]}" "${ND_GEN_ARGS[@]}" \
      --base-image debian:bullseye-slim \
      --kasmvnc de=xfce kasm_distro="bullseye" single_app="/usr/local/bin/fsl" \
      --ttyd version=1.7.7 \
      --fsl version="${app_version}" \
      --copy fsl_gui_template/build/src/fsl_start.sh /usr/local/bin/fsl \
      --copy fsl_gui_template/build/src/fsl.sh /etc/profile.d/fsl.sh \
      --copy ${app_name}_gui_template/build/src/${app_name}.desktop /usr/share/applications/${app_name}.desktop \
    > "bc_${app_name}/${app_name}_${app_version}.${CONTAINER_FILE}"
    gen_container ${app_name} ${app_version}
  done
}
