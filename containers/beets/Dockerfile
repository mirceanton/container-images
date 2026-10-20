# syntax=docker/dockerfile:1

# ===============================================================================
# Beets Audit Container Image
#
# Base: python:3.13-slim
# Includes: beets, mutagen, and the library audit script.
# ===============================================================================
FROM python:3.15-slim

# Install system dependencies for audio format support
# hadolint ignore=DL3008
RUN apt-get update && apt-get install -y --no-install-recommends \
    # FLAC validation (badfiles plugin)
    flac \
    # MP3 validation (badfiles plugin)
    mp3val \
    # chromaprint/acoustic fingerprinting (chroma plugin): provides fpcalc
    libchromaprint-tools \
    # General utilities
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install beets with commonly-used plugins
# Pinned versions for reproducibility
# renovate: datasource=pypi depName=beets
ARG BEETS_VERSION=2.3.1
# renovate: datasource=pypi depName=mutagen
ARG MUTAGEN_VERSION=1.47.0
# renovate: datasource=pypi depName=pyyaml
ARG PYYAML_VERSION=6.0.3
# renovate: datasource=pypi depName=requests
ARG REQUESTS_VERSION=2.32.5

RUN pip install --no-cache-dir \
    "beets[fetchart,lyrics,lastgenre,chroma,scrub]==${BEETS_VERSION}" \
    "mutagen==${MUTAGEN_VERSION}" \
    "pyyaml==${PYYAML_VERSION}" \
    "requests==${REQUESTS_VERSION}"

WORKDIR /app

# Copy the audit script
COPY audit.py /app/audit.py

# Volumes
# /music:  music library (mounted read-only for audit)
# /data:   beets database, config, and report output
VOLUME ["/music", "/data"]

# Default: audit mode, report-only
ENTRYPOINT ["python", "/app/audit.py"]
CMD ["/music"]
