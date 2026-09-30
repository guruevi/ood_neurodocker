build_fastsurfer() {
  app_name="fastsurfer"
  FASTSURFER_VERSIONS=('cu128-v2.5.4')
  gen_template "${app_name}" "Fastsurfer (Shell)" "MRI Analysis" "fa://brain"
  gen_template "${app_name}_gui" "Fastsurfer (GUI)" "MRI Analysis" "fa://brain"

  for app_version in "${FASTSURFER_VERSIONS[@]}"; do
    echo "Building ${app_name}_${app_version}"
    "${ND_GEN_COMMAND[@]}" "${ND_GEN_ARGS[@]}" \
      --base-image deepmi/fastsurfer:${app_version} \
      --ttyd version=1.7.7 \
      --kasmvnc de=xfce kasm_distro="noble" \
      --copy $(pwd)/${app_name}_template/build/src/license.txt /usr/local/freesurfer/.license \
      --copy $(pwd)/${app_name}_template/build/src/env.sh /etc/profile.d/freesurfer.sh \
    > "bc_${app_name}/${app_name}_${app_version}.${CONTAINER_FILE}"
    # Replace %post with %post and mkdir /nonexistent
    sed -i 's@%post@%post\nmkdir -p /nonexistent\nusermod -s /bin/bash nonroot@g' "bc_${app_name}/${app_name}_${app_version}.${CONTAINER_FILE}"
    gen_container ${app_name} ${app_version}
  done
}
