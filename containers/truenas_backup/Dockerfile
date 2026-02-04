# syntax=docker/dockerfile:1

# =================================================================================================
# Build stage
# =================================================================================================
FROM golang:1.22-alpine AS builder
WORKDIR /app

COPY src/go.mod src/go.sum ./
RUN go mod download

COPY src/main.go .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /truenas-backup .

# =================================================================================================
# Final stage
# =================================================================================================
FROM scratch
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /truenas-backup /truenas-backup
ENTRYPOINT ["/truenas-backup"]
