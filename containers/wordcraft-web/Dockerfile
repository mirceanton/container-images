# syntax=docker/dockerfile:1

# ===============================================================================
# Download stage
# ===============================================================================
FROM alpine:3.24 AS downloader
SHELL ["/bin/ash", "-o", "pipefail", "-c"]
ARG VERSION

RUN echo "Downloading WordCraft web v${VERSION}..."

# hadolint ignore=DL3018
RUN apk add --no-cache curl unzip && \
    curl -fsSL "https://github.com/storytold/wordcraft/releases/download/v${VERSION}/wordcraft-web-${VERSION}.zip" \
    -o /tmp/web.zip && \
    unzip /tmp/web.zip -d /tmp/ && \
    rm /tmp/web.zip

# ===============================================================================
# Final image
# ===============================================================================
FROM nginxinc/nginx-unprivileged:1.29-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=downloader /tmp/wordcraft-web-* /srv/app
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s \
    CMD ["wget", "-q", "--spider", "http://127.0.0.1:8080/"]