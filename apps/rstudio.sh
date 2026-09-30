build_rstudio() {
  app_name="rstudio"

  # 4.5 is not yet available in the rocker/ml-verse images
  # When changing RStudio versions, also update the bioconductor version
  RSTUDIO_VERSIONS=('4.5.2' '4.5.0' '4.4.1' '4.3.0')

  gen_template ${app_name} "R (Shell)" "Servers"
  gen_template "${app_name}_gui" "RStudio (GUI)" "Servers"
  for app_version in "${RSTUDIO_VERSIONS[@]}"; do
    echo "Building ${app_name}_${app_version}"
    # Generate the container definition
    base_image="rocker/ml-verse:${app_version}"
    if ! docker manifest inspect docker.io/${base_image} > /dev/null 2>&1; then
      echo "Does not appear that ${base_image} is available, skipping"
      continue
    fi
    echo "Building ${app_name}_${app_version}"
    "${ND_GEN_COMMAND[@]}" --pkg-manager apt --user rstudio --yes \
      --base-image $base_image \
      --ttyd version="1.7.7" \
      --rstudio rprofile='options(BioC_mirror = "https://smdartifactory.urmc-sh.rochester.edu/artifactory/bioconductor")\noptions(repos = "https://smdartifactory.urmc-sh.rochester.edu/artifactory/cran-remote")' \
    > "bc_${app_name}/${app_name}_${app_version}.${CONTAINER_FILE}"
    gen_container ${app_name} ${app_version}

  done
}
