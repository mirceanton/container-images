# bambu-studio-api Container Image

Container image for [bambu-studio-api](https://github.com/maziggy/orca-slicer-api/tree/bambuddy/profile-resolver), a headless Bambu Studio CLI wrapped in an HTTP API built from the `maziggy` fork's `bambuddy/profile-resolver` branch. This fork adds profile-inheritance fixes required by [BambuBuddy](https://github.com/BambuBuddy/BambuBuddy).

## Why a custom image?

The upstream `orca-slicer-api` project does not publish images for the `maziggy/bambuddy/profile-resolver` fork, and provides no pre-built image for the Bambu Studio variant at all. This image builds directly from that fork's `Dockerfile.bambu-studio` so BambuBuddy can use a stable, versioned image from GHCR.

## Usage (Docker)

```bash
docker pull ghcr.io/mirceanton/bambu-studio-api:latest
```

```bash
docker run --rm -p 3001:3000 ghcr.io/mirceanton/bambu-studio-api:latest
```

## Usage (Kubernetes)

```yaml
controllers:
  bambu-studio-api:
    containers:
      bambu-studio-api:
        image:
          repository: ghcr.io/mirceanton/bambu-studio-api
          tag: latest #! replace with a specific version

        resources:
          requests:
            cpu: 100m
            memory: 256Mi
          limits:
            memory: 1Gi

service:
  bambu-studio-api:
    ports:
      http:
        port: 3001
        targetPort: 3000
```
