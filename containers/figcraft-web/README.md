# figcraft-web

[FigCraft](https://getartcraft.com/apps/figcraft) web app served via Nginx.

## Usage

```bash
docker run --rm -p 8080:8080 ghcr.io/mirceanton/figcraft-web:latest
```

Then open http://localhost:8080/

## Tags

| Tag | Description |
|-----|-------------|
| `latest` | Latest FigCraft release |
| `0.10.0` | Specific version |
| `0.10` | Major.minor track |
| `0` | Major track |
| `sha-*` | Git commit SHA |
| `date-*` | Build date |