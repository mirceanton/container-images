#!/usr/bin/env bash
set -euo pipefail

log() { echo "[input-watcher] $*"; }

log "started"

# Sunshine creates DS5/PS5 gamepads (with gyro/touchpad/rumble) via /dev/uhid,
# which ships as root:root 0600 - unusable by the unprivileged sunshine user.
# Hand it to the 'input' group (which sunshine is a member of) so those
# controllers work. Xbox-style pads use uinput and don't need this.
if [ -c /dev/uhid ]; then
    sudo-root chgrp input /dev/uhid 2>/dev/null || true
    sudo-root chmod 0660 /dev/uhid 2>/dev/null || true
    log "fixed permissions on /dev/uhid (-> input 660)"
fi

while :; do
    for node in /dev/input/event*; do
        [ -c "$node" ] || continue

        current_group=$(stat -c '%G' "$node" 2>/dev/null) || continue
        current_perms=$(stat -c '%a' "$node" 2>/dev/null) || continue

        if [ "$current_group" != "input" ] || [ "$current_perms" != "660" ]; then
            sudo-root chgrp input "$node" 2>/dev/null || true
            sudo-root chmod 0660 "$node" 2>/dev/null || true
            log "fixed permissions on $node ($current_group $current_perms -> input 660)"

            name="$(basename "$node")"
            sudo-root sh -c "echo change > /sys/class/input/${name}/uevent" 2>/dev/null || true
        fi
    done
    sleep 2
done
