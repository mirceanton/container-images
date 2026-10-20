# syntax=docker/dockerfile:1

# ===============================================================================
# Source stage — clone the upstream project at a pinned revision
# ===============================================================================
FROM alpine:3.24 AS downloader
SHELL ["/bin/ash", "-o", "pipefail", "-c"]
ARG ESSENTIA_TAGGER_REV

WORKDIR /tmp
# hadolint ignore=DL3018
RUN apk add --no-cache git && \
    git clone https://github.com/WB2024/Essentia-to-Metadata.git /src

WORKDIR /src
RUN git checkout "${ESSENTIA_TAGGER_REV}"

# ===============================================================================
# Final image — mirrors the upstream Dockerfile with pinned source code
# ===============================================================================
FROM python:3.10-slim

# Install system dependencies required by Essentia
# hadolint ignore=DL3008
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libfftw3-dev \
    libavcodec-dev \
    libavformat-dev \
    libavutil-dev \
    libswresample-dev \
    libsamplerate0-dev \
    libtag1-dev \
    libchromaprint-dev \
    libyaml-dev \
    wget \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install uv for fast dependency management
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

# Install Python dependencies
# essentia-tensorflow only publishes dev builds for Python 3.10+,
# which are not matched by the >=2.1b6 specifier in requirements.txt,
# so install it explicitly first then the remaining deps.
RUN uv pip install --system --no-cache essentia-tensorflow
COPY --from=downloader /src/requirements.txt .
RUN uv pip install --system --no-cache mutagen numpy

# Download ML models at build time
COPY --from=downloader /src/download_models.sh .
ENV HOME=/app
RUN sed -i 's/\r$//' download_models.sh && bash download_models.sh

# Copy application code from the pinned upstream revision
COPY --from=downloader /src/tag_music.py /src/docker-entrypoint.py ./

# Suppress noisy TensorFlow logs (INFO + WARNING)
ENV TF_CPP_MIN_LOG_LEVEL=3

# Music directory mount point
VOLUME ["/music"]

ENTRYPOINT ["python", "docker-entrypoint.py", "--model-dir", "/app/essentia_models"]
CMD ["/music", "--auto"]
