build_matlab() {
  app_name="matlab"
  # To check the available matlab-deps images, see: https://hub.docker.com/r/mathworks/matlab-deps
  base_repo="mathworks/matlab-deps"

  MATLAB_VERSIONS=('R2025a' 'R2024b' 'R2024a' 'R2023b' 'R2023a' 'R2022b' 'R2022a' 'R2021b' 'R2021a' 'R2020b' 'R2020a')
  gen_template "matlab" "MATLAB (Shell)" "Servers" "fa://cogs"
  gen_template "matlab_gui" "MATLAB (GUI)" "Servers" "fa://cogs"
  echo "Building MATLAB"

  for app_version in "${MATLAB_VERSIONS[@]}"; do
    ### Generate  ###
    "${ND_GEN_COMMAND[@]}" "${ND_GEN_ARGS[@]}" \
        --base-image ${base_repo}:"${app_version}" \
        --ttyd version=1.7.7 \
        --matlab version="${app_version}" \
    > "bc_${app_name}/${app_name}_${app_version}.${CONTAINER_FILE}"
    gen_container ${app_name} ${app_version}
  done
}
