build_ants() {
  app_name="ants"
  APP_VERSIONS=($(date +%Y%m%d))
  gen_template "${app_name}" "ANTS (Shell)" "ANTS"
  #gen_template "${app_name}_gui" "ANTS (GUI)" "ANTS (GUI)"
  for app_version in "${APP_VERSIONS[@]}"; do
    echo "Building ${app_name}_${app_version}"
    "${ND_GEN_COMMAND[@]}" "${ND_GEN_ARGS[@]}" \
      --base-image ubuntu:noble \
      --ttyd version=1.7.7 \
      --ants version=2.6.0 \
    > "bc_${app_name}/${app_name}_${app_version}.${CONTAINER_FILE}"
    gen_container ${app_name} ${app_version}
  done
}
