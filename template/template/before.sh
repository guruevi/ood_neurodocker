# Create a port and password
export port=$(find_port ${host})
export password="$(create_passwd 20)"
export host="${host}"
export x11port=$(find_port ${host})
export vncport=$(find_port ${host})