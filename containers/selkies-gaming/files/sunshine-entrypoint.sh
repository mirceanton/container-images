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
# Unlock NvFBC on consumer GeForce GPUs
# =================================================================================================
# NVIDIA's stock libnvidia-fbc refuses frame capture on GeForce cards, which Sunshine needs for
# `capture = nvfbc`. keylase/nvidia-patch NOPs that check. The driver lib is injected read-only, so
# we patch a writable copy into /usr/local/lib (first in the ld cache) and repoint the soname
# symlink. patch-fbc.sh auto-detects the driver version, so a driver bump just works while keylase
# supports it. Idempotent per container; best-effort so a failure still leaves the desktop usable
# (only nvfbc capture is affected — x11/kms capture and the Selkies WebRTC path are unaffected).
if [ -e /usr/local/lib/libnvidia-fbc.so.patched ]; then
    log "NvFBC already patched"
elif (
    set -e
    curl -fsSL https://raw.githubusercontent.com/keylase/nvidia-patch/master/patch-fbc.sh -o /tmp/patch-fbc.sh
    rm -rf /tmp/nvfbc && mkdir -p /tmp/nvfbc
    PATCH_OUTPUT_DIR=/tmp/nvfbc bash /tmp/patch-fbc.sh
    lib="$(find /tmp/nvfbc -maxdepth 1 -type f -name 'libnvidia-fbc.so.*' -printf '%f\n' | head -n1)"
    test -n "${lib}"
    cp -f "/tmp/nvfbc/${lib}" /usr/local/lib/libnvidia-fbc.so.patched
    ln -sf libnvidia-fbc.so.patched /usr/local/lib/libnvidia-fbc.so.1
); then
    log "NvFBC unlocked (libnvidia-fbc patched)"
else
    rm -f /usr/local/lib/libnvidia-fbc.so.patched 2>/dev/null || true
    log "WARN: NvFBC patch failed; capture=nvfbc will not work"
fi


# =================================================================================================
# Start Sunshine
# =================================================================================================
exec sunshine /etc/sunshine/sunshine.conf
