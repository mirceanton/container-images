#!/usr/bin/env bash
set -euo pipefail

log() { echo "[input-watcher] $*"; }

log "started"

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
