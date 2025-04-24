# Find available port to run server on
export port=$(find_port ${host})
export password="$(create_passwd 20)"
export host="${host}"

cat << 'EOF' > "${HOME}/.matlab-license"
SERVER ecm-lic-wp3.ur.rochester.edu 0050569261b5 any
USE_SERVER
EOF