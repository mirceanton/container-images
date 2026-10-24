# wordcraft-web

[WordCraft](https://getartcraft.com/apps/wordcraft) web app served via Nginx.

## Usage

```bash
docker run --rm -p 8080:8080 ghcr.io/mirceanton/wordcraft-web:latest
```

Then open http://localhost:8080/

## Tags

| Tag | Description |
|-----|-------------|
| `latest` | Latest WordCraft release |
| `0.10.0` | Specific version |
| `0.10` | Major.minor track |
| `0` | Major track |
| `sha-*` | Git commit SHA |
| `date-*` | Build date |