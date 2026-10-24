# gridcraft-web

[GridCraft](https://github.com/storytold/gridcraft) web app served via Nginx.

## Usage

```bash
docker run --rm -p 8080:8080 ghcr.io/mirceanton/gridcraft-web:latest
```

Then open http://localhost:8080/

## Tags

| Tag | Description |
|-----|-------------|
| `latest` | Latest GridCraft release |
| `0.11.1` | Specific version |
| `0.11` | Major.minor track |
| `0` | Major track |
| `sha-*` | Git commit SHA |
| `date-*` | Build date |