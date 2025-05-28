# Find available port to run server on
export port=$(find_port)
export password="$(create_passwd 24)"
mkdir -p "${HOME}/.rstudio-server/db"
export DBCONF="${HOME}/.rstudio-server/database.conf"
(
sed 's/^ \{2\}//' > "${DBCONF}" << EOL
  # set database location
  provider=sqlite
  directory=${HOME}/.rstudio-server/db
EOL
)
chmod 700 "${DBCONF}"