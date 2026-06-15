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

USER ubuntu
