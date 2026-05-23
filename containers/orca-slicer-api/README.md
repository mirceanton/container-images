# orca-slicer-api Container Image

Container image for [orca-slicer-api](https://github.com/maziggy/orca-slicer-api/tree/bambuddy/profile-resolver), an HTTP wrapper around the OrcaSlicer CLI built from the `maziggy` fork's `bambuddy/profile-resolver` branch. This fork adds profile-inheritance fixes required by [BambuBuddy](https://github.com/BambuBuddy/BambuBuddy).

## Why a custom image?

The upstream `orca-slicer-api` project does not publish images for the `maziggy/bambuddy/profile-resolver` fork, which contains profile-resolution patches that BambuBuddy depends on. This image builds directly from that fork's branch so BambuBuddy can use a stable, versioned image from GHCR.

## Usage (Docker)

```bash
docker pull ghcr.io/mirceanton/orca-slicer-api:latest
```

```bash
docker run --rm -p 8080:8080 ghcr.io/mirceanton/orca-slicer-api:latest
```

## Usage (Kubernetes)

```yaml
controllers:
  orca-slicer-api:
    containers:
      orca-slicer-api:
        image:
          repository: ghcr.io/mirceanton/orca-slicer-api
          tag: latest #! replace with a specific version

        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            memory: 512Mi

service:
  orca-slicer-api:
    ports:
      http:
        port: 8080
```
