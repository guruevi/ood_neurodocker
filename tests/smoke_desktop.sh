#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -eq 0 ]; then
  set -- desktop:rhel7 desktop:rhel8 desktop:rhel9 desktop:ubuntu22 desktop:ubuntu24
fi

for image in "$@"; do
  printf 'Smoke-testing %s\n' "$image"
  docker run --rm -i --platform linux/amd64 \
    --env XVNC_OPTIONS="-websocketPort 6080 -interface 127.0.0.1" \
    "$image" timeout 90 bash -s "$image" <<'SH'
set -euo pipefail
image="$1"
test "$(id -u)" -ne 0
if command -v dpkg-query > /dev/null 2>&1; then
  dpkg-query -W kasmvncserver xfce4-session tmux
  if [ "$image" = "desktop:ubuntu24" ]; then
    dpkg-query -W google-chrome-stable
  fi
else
  rpm -q kasmvncserver xfce4-session tmux
  if [ "$image" = "desktop:rhel7" ]; then
    rpm -q screen
  fi
  if [ "$image" = "desktop:rhel9" ]; then
    rpm -q google-chrome-stable
  fi
fi
ttyd --version
bash -n /opt/kasm_startup.sh

# Match OOD's before.sh without changing the host user's files.
printf 'none::wo\n' > "$HOME/.kasmpasswd"
/opt/kasm_startup.sh > /tmp/kasm-smoke.log 2>&1 &
ttyd -i 127.0.0.1 -p 7681 -W tmux new-session -A -s smoke \
  > /tmp/ttyd-smoke.log 2>&1 &
if [ "$image" = "desktop:rhel7" ]; then
  ttyd -i 127.0.0.1 -p 7682 -W /usr/bin/screen -xR -S smoke_screen \
    > /tmp/ttyd-screen-smoke.log 2>&1 &
fi

ready=false
for attempt in $(seq 1 60); do
  if curl -fsS --max-time 2 http://127.0.0.1:6080/vnc.html -o /dev/null 2>/dev/null \
    && curl -fsS --max-time 2 http://127.0.0.1:7681/ -o /dev/null 2>/dev/null \
    && ([ "$image" != "desktop:rhel7" ] || curl -fsS --max-time 2 http://127.0.0.1:7682/ -o /dev/null 2>/dev/null) \
    && pgrep -x xfce4-session > /dev/null \
    && pgrep -x xfwm4 > /dev/null \
    && pgrep -x xfce4-panel > /dev/null; then
    ready=true
    break
  fi
  sleep 1
done

if [ "$ready" != true ]; then
  tail -n 80 /tmp/kasm-smoke.log /tmp/ttyd-smoke.log /tmp/ttyd-screen-smoke.log 2>/dev/null || true
  exit 1
fi

tmux new-session -d -s terminal-smoke 'sleep 10'
tmux has-session -t terminal-smoke
if [ "$image" = "desktop:rhel7" ]; then
  screen -d -m -S screen-test
  screen -ls > /dev/null 2>&1 || true
fi
printf 'PASS: %s verified\n' "$image"
SH
done
