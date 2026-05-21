# syntax=docker/dockerfile:1

# ===============================================================================
# Source stage
# ===============================================================================
FROM alpine:3.23 AS downloader
SHELL [ "/bin/ash", "-o", "pipefail", "-c" ]
ARG CARBON_VERSION

# hadolint ignore=DL3018
RUN apk add --no-cache git && \
    git clone https://github.com/carbon-app/carbon.git /app --branch "${CARBON_VERSION}"

# ===============================================================================
# Build stage
# ===============================================================================
FROM node:18-alpine AS builder
WORKDIR /app

ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true

COPY --from=downloader /app .
RUN yarn install --frozen-lockfile && \
    yarn build && \
    yarn install --production --frozen-lockfile && \
    yarn cache clean

# ===============================================================================
# Final image
# ===============================================================================
FROM node:18-alpine
WORKDIR /app

# hadolint ignore=DL3018
RUN apk add --no-cache \
    dumb-init \
    chromium \
    nss \
    freetype \
    harfbuzz \
    ca-certificates \
    ttf-freefont

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser

COPY --from=builder /app/.next ./.next
COPY --from=builder /app/public ./public
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./

EXPOSE 3000

ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["node_modules/.bin/next", "start"]
