# Create a port and password
export port=$(find_port ${host})
export password="$(create_passwd 20)"
echo "none::wo" > ~/.kasmpasswd