# Find available port to run server on
export port=$(find_port ${host})
export password="$(create_passwd 20)"
export host="${host}"