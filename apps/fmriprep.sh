build_fmriprep() {
  app_name="fmriprep"
  FMRIPREP_VERSIONS=('25.2.3' ) # Add more versions as needed
  gen_template "${app_name}" "fMRIPrep" "MRI Analysis" "fa://brain"
  gen_template "${app_name}_gui" "fMRIPrep (Shell)" "MRI Analysis" "fa://brain"

  for app_version in "${FMRIPREP_VERSIONS[@]}"; do
    echo "Building ${app_name}_${app_version}"
    "${ND_GEN_COMMAND[@]}" "${ND_GEN_ARGS[@]}" \
      --base-image nipreps/fmriprep:${app_version} \
      --ttyd version=1.7.7 \
      --copy $(pwd)/${app_name}_template/build/src/license.txt /usr/share/freesurfer_license.txt \
      --copy $(pwd)/${app_name}_template/build/src/99-fmriprep.sh /etc/profile.d/99-fmriprep.sh \
    > "bc_${app_name}/${app_name}_${app_version}.${CONTAINER_FILE}"
    gen_container ${app_name} ${app_version}
  done
}
