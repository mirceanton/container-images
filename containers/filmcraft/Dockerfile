# syntax=docker/dockerfile:1

# ===============================================================================
# Builder stage
# ===============================================================================
FROM alpine:3.24 AS downloader
SHELL [ "/bin/ash", "-o", "pipefail", "-c" ]
ARG FILMCRAFT_VERSION
ARG TARGETARCH

RUN echo "Downloading FilmCraft version ${FILMCRAFT_VERSION} for architecture ${TARGETARCH}"

# hadolint ignore=DL3018
RUN apk add --no-cache curl tar && \
    arch="$( [ "${TARGETARCH}" = "arm64" ] && echo "aarch64" || echo "x86_64" )" && \
    curl -fsSL "https://github.com/storytold/filmcraft/releases/download/v${FILMCRAFT_VERSION}/SHA256SUMS.txt" -o /tmp/SHA256SUMS.txt && \
    curl -fsSL "https://github.com/storytold/filmcraft/releases/download/v${FILMCRAFT_VERSION}/filmcraft-${FILMCRAFT_VERSION}-linux-${arch}.tar.gz" -o /tmp/filmcraft.tar.gz && \
    expected="$(grep "filmcraft-${FILMCRAFT_VERSION}-linux-${arch}.tar.gz$" /tmp/SHA256SUMS.txt | awk '{print $1}')" && \
    actual="$(sha256sum /tmp/filmcraft.tar.gz | awk '{print $1}')" && \
    [ "${expected}" = "${actual}" ] || ( echo "Checksum mismatch: expected ${expected}, got ${actual}" && exit 1 ) && \
    tar -xzf /tmp/filmcraft.tar.gz -C /tmp && \
    mv "filmcraft-${FILMCRAFT_VERSION}-linux-${arch}" /tmp/filmcraft && \
    /tmp/filmcraft/bin/filmcraft-cli --version

# ===============================================================================
# Final image
# ===============================================================================
FROM debian:bookworm-slim

# hadolint ignore=DL3018
RUN apt-get update && \
    apt-get install -y --no-install-recommends ffmpeg ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY --from=downloader /tmp/filmcraft /opt/filmcraft

ENV PATH="/opt/filmcraft/bin:${PATH}"

ENTRYPOINT ["/opt/filmcraft/bin/filmcraft-cli"]
CMD ["--help"]
