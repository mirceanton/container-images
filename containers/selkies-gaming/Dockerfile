# syntax=docker/dockerfile:1

ARG UBUNTU_VERSION=24.04
FROM ghcr.io/selkies-project/nvidia-glx-desktop:${UBUNTU_VERSION}

SHELL [ "/bin/bash", "-o", "pipefail", "-c" ]
ENV DEBIAN_FRONTEND=noninteractive
USER root

# -------------------------------------------------------------------------------
# Update base packages
# -------------------------------------------------------------------------------
RUN apt-get update && \
    apt-get upgrade -y && \
    rm -rf /var/lib/apt/lists/*

# -------------------------------------------------------------------------------
# Install Steam
# -------------------------------------------------------------------------------
# hadolint ignore=DL3008
RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        steam-installer \
        steam-libs-amd64 \
        steam-libs-i386 \
    && rm -rf /var/lib/apt/lists/*

# -------------------------------------------------------------------------------
# Install Sunshine
# -------------------------------------------------------------------------------
ARG SUNSHINE_VERSION=2026.516.143833
# hadolint ignore=DL3008,DL3015
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl && \
    curl -fsSL "https://github.com/LizardByte/Sunshine/releases/download/v${SUNSHINE_VERSION}/sunshine-ubuntu-24.04-amd64.deb" \
        -o /tmp/sunshine.deb && \
    apt-get install -y /tmp/sunshine.deb && \
    rm -f /tmp/sunshine.deb && \
    rm -rf /var/lib/apt/lists/*

# Sunshine: supervisord config and entrypoint wrapper
# sunshine.conf and apps.json are expected to be injected at runtime
COPY files/sunshine.conf          /etc/supervisor/conf.d/sunshine.conf
COPY files/sunshine-entrypoint.sh /etc/sunshine/entrypoint.sh
RUN chmod +x /etc/sunshine/entrypoint.sh

# Input node watcher
COPY files/input-watcher.conf /etc/supervisor/conf.d/input-watcher.conf
COPY files/input-watcher.sh   /etc/sunshine/input-watcher.sh
RUN chmod +x /etc/sunshine/input-watcher.sh

# -------------------------------------------------------------------------------
# Sunshine-only: disable Selkies WebRTC + its joystick interposer
# -------------------------------------------------------------------------------
# This is a Sunshine/Moonlight (couch) image. Selkies and Sunshine cannot coexist:
#   1. Selkies' LD_PRELOAD joystick interposer (exported from /etc/entrypoint.sh)
#      hijacks controller input to the browser Gamepad API, which is empty when
#      streaming over Moonlight -> dead controller in-game.
#   2. selkies-gstreamer competes with Sunshine for PulseAudio capture.
# So we (1) neuter the selkies-gstreamer supervisor program (no Selkies, no
# turnserver), and (2) strip the interposer env + fake js node creation from the
# desktop entrypoint so Steam/games use Sunshine's real uinput devices instead.
COPY files/disable-selkies.sh /etc/selkies-gstreamer-entrypoint.sh
RUN chmod +x /etc/selkies-gstreamer-entrypoint.sh && \
    sed -i \
        -e '/SELKIES_INTERPOSER/d' \
        -e '/SDL_JOYSTICK_DEVICE/d' \
        -e '/touch \/dev\/input\/js/d' \
        -e '/chmod .*\/dev\/input\/js/d' \
        /etc/entrypoint.sh

USER ubuntu
