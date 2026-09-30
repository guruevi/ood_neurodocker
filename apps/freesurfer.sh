build_freesurfer() {
  app_name="freesurfer"
  FREESURFER_VERSIONS=('8.2.0')
  gen_template "${app_name}" "FreeSurfer (Shell)" "MRI Analysis" "fa://brain"
  gen_template "${app_name}_gui" "FreeSurfer (GUI)" "MRI Analysis" "fa://brain"

  for app_version in "${FREESURFER_VERSIONS[@]}"; do
    echo "Building ${app_name}_${app_version}"
    "${ND_GEN_COMMAND[@]}" "${ND_GEN_ARGS[@]}" \
      --base-image freesurfer/freesurfer:${app_version} \
      --ttyd version=1.7.7 \
      --kasmvnc de=xfce kasm_distro="jammy" \
      --copy $(pwd)/${app_name}_template/build/src/license.txt /usr/local/freesurfer/.license \
      --copy $(pwd)/${app_name}_template/build/src/env.sh /etc/profile.d/freesurfer.sh \
    > "bc_${app_name}/${app_name}_${app_version}.${CONTAINER_FILE}"
    gen_container ${app_name} ${app_version}
  done
}
