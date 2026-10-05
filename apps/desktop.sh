build_desktop() {
  local app_name="desktop"
  local app_version base_image pkg_manager
  local -a repo_setup desktop_packages
  gen_template "${app_name}" "Desktop (Shell)" "Desktops" "fa://desktop" || return
  gen_template "${app_name}_gui" "Desktop (XFCE)" "Desktops" "fa://desktop" || return
  for app_version in rhel7 rhel8 rhel9 ubuntu22 ubuntu24; do
    repo_setup=()
    desktop_packages=()
    case "${app_version}" in
      rhel7)
        base_image="centos:7"
        # CentOS 7 and EPEL 7 are end-of-life; both need their archive repositories.
        repo_setup=(
          "yum install -y epel-release"
          "sed -i 's|^metalink=|#metalink=|; s|^mirrorlist=|#mirrorlist=|; s|^#baseurl=http://download.fedoraproject.org/pub/epel|baseurl=https://archives.fedoraproject.org/pub/archive/epel|' /etc/yum.repos.d/epel*.repo"
          "sed -i 's|vault.centos.org/centos/\$releasever|archive.kernel.org/centos-vault/7.9.2009|g' /etc/yum.repos.d/CentOS-Base.repo"
        )
        desktop_packages=(
          "yum install -y jre ksh xterm mesa-libGLU redhat-lsb-core csh Xvfb 'xorg-x11-fonts*' apr-util glibc-devel compat-db47 screen libXScrnSaver"
          "ln -sf libssl.so.10 /lib64/libssl.so"
          "ln -sf libcrypto.so.10 /lib64/libcrypto.so"
          "ln -sf /lib64/libdl.so.2 /lib64/libdl.so"
        )
        pkg_manager="yum"
        ;;
      rhel8)
        base_image="rockylinux:8"
        repo_setup=(
          "yum install -y dnf-plugins-core epel-release"
          "yum config-manager --set-enabled powertools"
          "dnf copr enable -y vowstar/compat-db47 epel-8-x86_64"
        )
        desktop_packages=(
          "yum install -y jre ksh xterm mesa-libGLU redhat-lsb-core csh Xvfb 'xorg-x11-fonts*' libnsl apr-util glibc-devel compat-db47 compat-openssl10 libXScrnSaver"
          "ln -sf libssl.so.10 /lib64/libssl.so"
          "ln -sf libcrypto.so.10 /lib64/libcrypto.so"
          "ln -sf /lib64/libdl.so.2 /lib64/libdl.so"
        )
        pkg_manager="yum"
        ;;
      rhel9)
        base_image="rockylinux:9"
        repo_setup=(
          "yum install -y dnf-plugins-core epel-release"
          "yum config-manager --set-enabled crb"
          "dnf copr enable -y vowstar/compat-db47 epel-9-x86_64"
          "dnf copr enable -y mroche/vfx-compatibility epel-9-x86_64"
        )
        desktop_packages=(
          "yum install -y jre ksh xterm mesa-libGLU python3-distro csh Xvfb 'xorg-x11-fonts*' libnsl apr-util glibc-devel compat-db47 compat-openssl10 libXScrnSaver"
          "ln -sf libssl.so.10 /lib64/libssl.so"
          "ln -sf libcrypto.so.10 /lib64/libcrypto.so"
          "ln -sf /lib64/libdl.so.2 /lib64/libdl.so"
        )
        pkg_manager="yum"
        ;;
      ubuntu22)
        base_image="ubuntu:22.04"
        pkg_manager="apt"
        desktop_packages=(
          "apt-get update"
          "apt-get install -y default-jre ksh xterm libglu1-mesa csh xvfb libnsl2 libaprutil1 libc6-dev libxss1"
        )
        ;;
      ubuntu24)
        base_image="ubuntu:24.04"
        pkg_manager="apt"
        desktop_packages=(
          "apt-get update"
          "apt-get install -y default-jre ksh xterm libglu1-mesa csh xvfb libnsl2 libaprutil1 libc6-dev libxss1"
        )
        ;;
    esac
    echo "Building ${app_name}_${app_version}"
    local kasm_distro="${app_version}"
    if [ "${app_version}" = "ubuntu22" ]; then
      kasm_distro="jammy"
    elif [ "${app_version}" = "ubuntu24" ]; then
      kasm_distro="noble"
    fi
    local gen_cmd=(
      "${ND_GEN_COMMAND[@]}"
      --base-image "${base_image}"
    )
    local cmd
    for cmd in "${repo_setup[@]}"; do
      gen_cmd+=(--run "${cmd}")
    done
    gen_cmd+=(
      --kasmvnc de=xfce kasm_distro="${kasm_distro}"
      --ttyd version=1.7.7
    )
    for cmd in "${desktop_packages[@]}"; do
      gen_cmd+=(--run "${cmd}")
    done
    gen_cmd+=(
      "${ND_GEN_ARGS[@]}" --pkg-manager "${pkg_manager}"
    )
    "${gen_cmd[@]}" > "bc_${app_name}/${app_name}_${app_version}.${CONTAINER_FILE}" || return
    gen_container "${app_name}" "${app_version}" || return
  done
}
