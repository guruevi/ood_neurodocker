# Create a port for the OOD-authenticated KasmVNC connection
export port=$(find_port ${host})
echo "none::wo" > ~/.kasmpasswd