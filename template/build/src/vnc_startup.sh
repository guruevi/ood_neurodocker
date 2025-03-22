#!/bin/bash
# every exit != 0 fails the script
set -e

echo -e "\n------------------ change VNC password  --------------------"
PASSWD_PATH="$(pwd)/.vnc/passwd"
mkdir -p $(dirname "$PASSWD_PATH")

echo "$VNC_PW" | vncpasswd -f > "$PASSWD_PATH"
chmod 600 "$PASSWD_PATH"

echo -e "\n------------------ start noVNC  ----------------------------"
# Check if /opt/novnc or /usr/share/novnc should be used
if [ -d /opt/novnc ]; then
  NO_VNC_HOME="/opt/novnc"
else
  NO_VNC_HOME="/usr/share/novnc"
fi
$NO_VNC_HOME/utils/novnc_proxy --vnc localhost:$VNC_PORT --listen $NO_VNC_PORT > /var/log/app/no_vnc_startup.log 2>&1 &
PID_SUB=$!

echo -e "\n------------------ start dbus  -----------------------------"
eval $(dbus-launch)

# Cast whatever we got to integer (will be 0 if empty or string)
VNC_COL_DEPTH=$((VNC_COL_DEPTH+0))

if [ "$VNC_COL_DEPTH" -ne 8 ] && [ "$VNC_COL_DEPTH" -ne 16 ] && [ "$VNC_COL_DEPTH" -ne 24 ] && [ "$VNC_COL_DEPTH" -ne 32 ]; then
  VNC_COL_DEPTH=24
fi

echo -e "\n------------------ start VNC server ------------------------"
echo -e "start vncserver with param: VNC_COL_DEPTH=$VNC_COL_DEPTH, VNC_RESOLUTION=$VNC_RESOLUTION\n..."
vnc_cmd="/usr/bin/vncserver $DISPLAY -rfbport $VNC_PORT -depth $VNC_COL_DEPTH -geometry $VNC_RESOLUTION PasswordFile=$PASSWD_PATH"
$vnc_cmd > /var/log/app/vnc_startup.log 2>&1

echo -e "\n\n------------------ VNC environment started --------------"
echo -e "\nconnect via VNC viewer on $(hostname -s):${NO_VNC_PORT}"
wait $PID_SUB