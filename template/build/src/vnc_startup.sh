#!/bin/bash
# every exit != 0 fails the script
set -e

if [ -z "$VNC_PW" ]; then
  echo -e "\n------------------ no VNC password set ---------------------"
  echo -e "\n------------------ VNC password set to 'vncpassword' -------"
  export VNC_PW="vncpassword"
fi
if [ -z "$VNC_RESOLUTION" ]; then
  echo -e "\n------------------ no VNC resolution set -------------------"
  echo -e "\n------------------ VNC resolution set to '1024x768' --------"
  export VNC_RESOLUTION="1024x768"
fi
# Cast whatever we got to integer (will be 0 if empty or string)
VNC_COL_DEPTH=$((VNC_COL_DEPTH+0))
if [ "$VNC_COL_DEPTH" -ne 8 ] && [ "$VNC_COL_DEPTH" -ne 16 ] && [ "$VNC_COL_DEPTH" -ne 24 ] && [ "$VNC_COL_DEPTH" -ne 32 ]; then
  echo -e "\n------------------ VNC color depth set to 24 ---------------"
  VNC_COL_DEPTH=24
fi
if [ -z "$VNC_PORT" ]; then
  echo -e "\n------------------ no VNC port set -------------------------"
  echo -e "\n------------------ VNC port set to '5901' ------------------"
  export VNC_PORT=5901
fi
if [ -z "$NO_VNC_PORT" ]; then
  echo -e "\n------------------ no noVNC port set -----------------------"
  echo -e "\n------------------ noVNC port set to '6901' ----------------"
  export NO_VNC_PORT=6901
fi

echo -e "\n------------------ store VNC password  --------------------"
PASSWD_PATH="$(pwd)/.vnc/passwd"
mkdir -p $(dirname "$PASSWD_PATH")

echo "$VNC_PW" | vncpasswd -f > "$PASSWD_PATH"
chmod 600 "$PASSWD_PATH"

echo -e "\n------------------ start noVNC  ----------------------------"
# Check if /opt/novnc or /usr/share/novnc should be used
if [ -z "$NO_VNC_HOME" ]; then
  NO_VNC_HOME="/usr/share/novnc"
fi
"$NO_VNC_HOME"/utils/novnc_proxy --vnc localhost:"$VNC_PORT" --listen "$NO_VNC_PORT" > /var/log/app/no_vnc_startup.log 2>&1 &
PID_SUB=$!

echo -e "\n------------------ start dbus  -----------------------------"
eval $(dbus-launch)

echo -e "\n------------------ start VNC server ------------------------"
echo -e "start vncserver with param: VNC_COL_DEPTH=$VNC_COL_DEPTH, VNC_RESOLUTION=$VNC_RESOLUTION\n..."
vnc_cmd="/usr/bin/vncserver $DISPLAY -rfbport $VNC_PORT -depth $VNC_COL_DEPTH -geometry $VNC_RESOLUTION PasswordFile=$PASSWD_PATH"
$vnc_cmd > /var/log/app/vnc_startup.log 2>&1

echo -e "\n\n------------------ VNC environment started --------------"
echo -e "\nconnect via VNC viewer on $(hostname -s):${NO_VNC_PORT}"
wait $PID_SUB