# syntax=docker/dockerfile:1

# =================================================================================================
# Build stage
# =================================================================================================
FROM golang:1.22-alpine AS builder
WORKDIR /app

COPY src/go.mod src/go.sum ./
RUN go mod download

COPY src/main.go .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /truenas-backup-to-s3 .

# =================================================================================================
# Final stage
# =================================================================================================
FROM scratch
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /truenas-backup-to-s3 /truenas-backup-to-s3
ENTRYPOINT ["/truenas-backup-to-s3"]
