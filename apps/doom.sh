build_doom() {
  app_name="doom"
  DOOM_VERSION=($(date +%Y%m%d))
  gen_template "${app_name}" "DOOM (Shell)" "DOOM"
  gen_template "${app_name}_gui" "DOOM (GUI)" "DOOM (GUI)" "fa://gamepad"
  for app_version in "${DOOM_VERSION[@]}"; do
    echo "Building ${app_name}_${app_version}"
    "${ND_GEN_COMMAND[@]}" "${ND_GEN_ARGS[@]}" \
      --base-image ubuntu:noble \
      --ttyd version=1.7.7 \
      --kasmvnc de=xfce kasm_distro="noble" but_can_it_run_doom="Y" \
    > "bc_${app_name}/${app_name}_${app_version}.${CONTAINER_FILE}"
    gen_container ${app_name} ${app_version}
  done
}
