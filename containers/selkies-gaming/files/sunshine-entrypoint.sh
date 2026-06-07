#!/usr/bin/env bash
set -euo pipefail

log() { echo "[sunshine] $*"; }

# =================================================================================================
# Wait for X11
# =================================================================================================
log "waiting for X11 socket..."
until [ -S "/tmp/.X11-unix/X${DISPLAY#*:}" ]; do
    log "X11 socket not found, retrying..."
    sleep 0.5;
done


# =================================================================================================
# Wait for PipeWire
# =================================================================================================
log "waiting for PipeWire..."
until [ "$(echo "${XDG_RUNTIME_DIR}"/pipewire-*.lock)" != "${XDG_RUNTIME_DIR}/pipewire-*.lock" ]; do
    log "PipeWire not found, retrying..."
    sleep 0.5
done


# =================================================================================================
# Fix permissions
# =================================================================================================
log "fixing /dev/uinput group ownership..."
if sudo-root chgrp input /dev/uinput 2>/dev/null; then
    log "fixed /dev/uinput group ownership"
else
    log "WARN: could not fix /dev/uinput group ownership"
fi

log "fixing /dev/uinput permissions..."
if sudo-root chmod 0660 /dev/uinput 2>/dev/null; then
    log "fixed /dev/uinput permissions"
else
    log "WARN: could not fix /dev/uinput permissions"
fi

# Fix existing /dev/input/event* nodes for the same reason.
log "fixing /dev/input/event* group ownership and permissions..."
sudo-root chgrp input /dev/input/event* 2>/dev/null || true
sudo-root chmod 0660 /dev/input/event* 2>/dev/null || true


# =================================================================================================
# Kill any leftover sunshine process (e.g. from a previous crash loop) so its
# port bindings are released before we start fresh.
# =================================================================================================
sudo-root pkill -x sunshine 2>/dev/null || true
sleep 1


# =================================================================================================
# Seed web UI credentials from env vars if provided
# =================================================================================================
if [ -n "${SUNSHINE_USER:-}" ] && [ -n "${SUNSHINE_PASSWORD:-}" ]; then
    sunshine --creds "${SUNSHINE_USER}" "${SUNSHINE_PASSWORD}" || \
        log "WARN: failed to set Sunshine credentials"
fi


# =================================================================================================
# Start Sunshine
# =================================================================================================
exec sunshine /etc/sunshine/sunshine.conf
