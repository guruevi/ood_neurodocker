build_pymol() {
  app_name="pymol"
  PYMOL_VERSIONS=('3.1.0')
  gen_template "${app_name}" "PyMOL" "Computational Biology" "fa://molecule"
  gen_template "${app_name}_gui" "PyMOL (GUI)" "Computational Biology" "fa://molecule"
  for app_version in "${PYMOL_VERSIONS[@]}"; do
    echo "Building ${app_name}_${app_version}"
    "${ND_GEN_COMMAND[@]}" "${ND_GEN_ARGS[@]}" \
      --base-image ubuntu:noble \
      --ttyd version=1.7.7 \
      --kasmvnc de=xfce kasm_distro="noble" single_app="/opt/conda/envs/pymol-env/bin/pymol" \
      --micromamba mamba_dependencies="name: pymol-env\nchannels: [conda-forge]\ndependencies: [python=3.10, pip, pymol-open-source=$app_version, fretraj]" \
      "${ND_GEN_ARGS[@]}" \
    > "bc_${app_name}/${app_name}_${app_version}.${CONTAINER_FILE}"
    gen_container ${app_name} ${app_version}
  done
}
