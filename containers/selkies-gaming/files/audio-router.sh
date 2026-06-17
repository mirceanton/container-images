#!/usr/bin/env bash
set -uo pipefail

log() { echo "[audio-router] $*"; }

# Sunshine captures the monitor of this sink. App audio (games, Steam) must be
# linked into it, but Sunshine's per-session audio teardown on disconnect leaves
# app output streams orphaned (unlinked) and they don't re-attach on reconnect ->
# Sunshine captures silence. This loop re-links any orphaned app playback stream
# back into the sink, so audio survives every disconnect/reconnect cycle.
SINK="sink-sunshine-stereo"

# Talk to the same PipeWire daemon as pipewire-pulse (its runtime dir).
pwpid=$(pgrep -f "bin/pipewire-pulse" | head -1 || true)
if [ -n "${pwpid:-}" ]; then
    rt=$(tr '\0' '\n' < "/proc/${pwpid}/environ" 2>/dev/null | sed -n 's/^XDG_RUNTIME_DIR=//p')
    [ -n "${rt:-}" ] && export XDG_RUNTIME_DIR="$rt"
fi

log "started (relinking orphaned app audio -> ${SINK})"

# Is this output port already connected to anything?
is_linked() { pw-link -l 2>/dev/null | grep -F -A1 -- "$1" | grep -q -- '->'; }

while :; do
    # Only act once the capture sink's playback ports exist.
    if pw-link -i 2>/dev/null | grep -qx "${SINK}:playback_FL"; then
        while read -r port; do
            [ -n "$port" ] || continue
            is_linked "$port" && continue
            case "${port##*:}" in
                output_FL)   pw-link "$port" "${SINK}:playback_FL" 2>/dev/null && log "relinked ${port}" ;;
                output_FR)   pw-link "$port" "${SINK}:playback_FR" 2>/dev/null && log "relinked ${port}" ;;
                output_MONO) pw-link "$port" "${SINK}:playback_FL" 2>/dev/null
                             pw-link "$port" "${SINK}:playback_FR" 2>/dev/null && log "relinked ${port} (mono)" ;;
            esac
        done < <(pw-link -o 2>/dev/null | grep -E ':output_(FL|FR|MONO)$' | grep -vE '^sink-sunshine|:monitor')
    fi
    sleep 2
done
