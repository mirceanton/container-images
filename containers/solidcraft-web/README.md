# solidcraft-web

[SolidCraft](https://solidcraft.io) web app served via Nginx.

## Usage

```bash
docker run --rm -p 8080:8080 ghcr.io/mirceanton/solidcraft-web:latest
```

Then open http://localhost:8080/

## Tags

| Tag | Description |
|-----|-------------|
| `latest` | Latest SolidCraft release |
| `0.21.0` | Specific version |
| `0.21` | Major.minor track |
| `0` | Major track |
| `sha-*` | Git commit SHA |
| `date-*` | Build date |