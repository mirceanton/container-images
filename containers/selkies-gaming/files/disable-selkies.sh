#!/bin/bash
# Sunshine-only image: Selkies WebRTC is intentionally disabled.
#
# This stub replaces the base image's /etc/selkies-gstreamer-entrypoint.sh so the
# supervisor [program:selkies-gstreamer] stays "up" without actually launching
# Selkies (and its turnserver). Selkies and Sunshine cannot coexist:
#   - Selkies' LD_PRELOAD joystick interposer hijacks controller input to the
#     browser Gamepad API, which is empty when streaming over Moonlight.
#   - selkies-gstreamer competes with Sunshine for PulseAudio capture.
#
# See the Dockerfile for the matching removal of the interposer env from
# /etc/entrypoint.sh.
echo "[disable-selkies] Selkies WebRTC disabled (Sunshine-only image); idling."
exec sleep infinity
