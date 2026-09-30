# Spaceranger only provides temporary download files, so you need to copy the tarball into /opt/ood_apps/spaceranger/
build_spaceranger() {
  app_name="spaceranger"
  SPACERANGER_VERSIONS=('4.0.1' '3.1.3')
  gen_template "spaceranger" "Space Ranger" "Omics" "fa://shuttle-space"
  echo "Building spaceranger"
  for app_version in "${SPACERANGER_VERSIONS[@]}"; do
    "${ND_GEN_COMMAND[@]}" "${ND_GEN_ARGS[@]}" \
      --base-image debian:bullseye-slim \
      --ttyd version=1.7.7 \
      --copy /opt/ood_apps/spaceranger/spaceranger-${app_version}.tar.gz /.repro-bins/spaceranger-${app_version}.tar.gz \
      --run "tar -xzvf /.repro-bins/spaceranger-${app_version}.tar.gz -C /opt" \
      --run "rm -f /opt/spaceranger; ln -s /opt/spaceranger-${app_version} /opt/spaceranger" \
      --run "cp /opt/spaceranger/sourceme.bash /etc/profile.d/spaceranger.sh" \
    > "bc_${app_name}/${app_name}_${app_version}.${CONTAINER_FILE}"
    gen_container ${app_name} ${app_version}
    sed -i 's@export SINGULARITYENV_APPEND_PATH=""@export SINGULARITYENV_APPEND_PATH="/opt/spaceranger/bin"@' bc_${app_name}/template/script.sh.erb
  done
}
