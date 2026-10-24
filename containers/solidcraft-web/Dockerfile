# syntax=docker/dockerfile:1

# ===============================================================================
# Download stage
# ===============================================================================
FROM alpine:3.24 AS downloader
SHELL ["/bin/ash", "-o", "pipefail", "-c"]
ARG SOLIDCRAFT_VERSION

RUN echo "Downloading SolidCraft web v${SOLIDCRAFT_VERSION}..."

# hadolint ignore=DL3018
RUN apk add --no-cache curl unzip && \
    curl -fsSL "https://github.com/tangency-labs/solidcraft/releases/download/v${SOLIDCRAFT_VERSION}/solidcraft-web-${SOLIDCRAFT_VERSION}.zip" \
    -o /tmp/web.zip && \
    unzip /tmp/web.zip -d /tmp/ && \
    rm /tmp/web.zip

# ===============================================================================
# Final image
# ===============================================================================
FROM nginxinc/nginx-unprivileged:1.29-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=downloader /tmp/solidcraft-web-* /srv/solidcraft
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s \
    CMD ["wget", "-q", "--spider", "http://127.0.0.1:8080/"]