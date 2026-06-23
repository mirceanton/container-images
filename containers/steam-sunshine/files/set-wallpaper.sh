#!/usr/bin/env bash
# Apply the embedded wallpaper as the XFCE desktop background ONCE.
#
# Runs each session via /etc/xdg/autostart, but only sets the wallpaper the first
# time on a given (persistent) home -- tracked by a marker file. After that the
# user is free to change the wallpaper via the XFCE GUI and it will stick across
# sessions. Iterating the live xfconf channel makes it robust to the monitor
# connector name (e.g. HDMI-0).
set -u

WP=/usr/share/backgrounds/wallpaper.png
MARKER="${HOME:-/home/ubuntu}/.config/.selkies-wallpaper-applied"
[ -f "$WP" ] || exit 0
# Already applied once -> leave the user's choice alone.
[ -f "$MARKER" ] && exit 0

# Wait for xfdesktop to register its backdrop properties on the xfconf channel.
for _ in $(seq 1 30); do
    xfconf-query -c xfce4-desktop -l 2>/dev/null | grep -q '/last-image$' && break
    sleep 0.5
done

props="$(xfconf-query -c xfce4-desktop -l 2>/dev/null | grep '/last-image$')"
if [ -z "${props}" ]; then
    # Channel not populated yet; seed a default for the common connector name.
    xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitorHDMI-0/workspace0/last-image -n -t string -s "${WP}" 2>/dev/null || true
    props="$(xfconf-query -c xfce4-desktop -l 2>/dev/null | grep '/last-image$')"
fi

for p in ${props}; do
    base="${p%/last-image}"
    xfconf-query -c xfce4-desktop -p "${p}" -s "${WP}" 2>/dev/null \
        || xfconf-query -c xfce4-desktop -p "${p}" -n -t string -s "${WP}" 2>/dev/null || true
    # image-style 5 = Zoomed (fill the screen)
    xfconf-query -c xfce4-desktop -p "${base}/image-style" -s 5 2>/dev/null \
        || xfconf-query -c xfce4-desktop -p "${base}/image-style" -n -t int -s 5 2>/dev/null || true
done

xfdesktop --reload 2>/dev/null || true

# Mark as applied so future sessions don't override a user-chosen wallpaper.
mkdir -p "$(dirname "$MARKER")" 2>/dev/null || true
touch "$MARKER" 2>/dev/null || true
