# Find available port to run server on
port=$(find_port)
export password="$(create_passwd 24)"

cat << 'EOF' > "${HOME}/.matlab-license"
SERVER ecm-lic-wp3.ur.rochester.edu 0050569261b5 any
USE_SERVER
EOF