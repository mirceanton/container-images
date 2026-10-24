# FilmCraft Container Image

Container image for [FilmCraft](https://github.com/storytold/filmcraft), an open-source professional non-linear video editor written in pure Rust, with a headless CLI and MCP server for AI-agent-driven editing.

## What's Inside

- `filmcraft-cli` — headless engine session driver: project inspect, command execution, export, MCP server (`filmcraft-cli mcp`)
- `ffmpeg` / `ffprobe` — for media probing and deterministic preprocessing/QC
- Based on `debian:bookworm-slim` (FilmCraft Linux builds target glibc, not musl)

## Usage

### Headless CLI (no window)

```bash
docker run --rm -v "$PWD:/work" -w /work ghcr.io/mirceanton/filmcraft:latest \
  --project project.fcproj --save exec timeline.razor seconds=3.5
```

### MCP server (stdio, for an MCP client to spawn)

```bash
docker run --rm -i -v "$PWD:/work" -w /work ghcr.io/mirceanton/filmcraft:latest \
  mcp --project project.fcproj
```

### Export

```bash
docker run --rm -v "$PWD:/work" -w /work ghcr.io/mirceanton/filmcraft:latest \
  --project project.fcproj export out.mp4 --format h264
```

> [!Note]
> Exports render on the CPU compositor; no GPU, X11/Wayland, or VA-API devices are required. The image is fully headless.
>
> The MCP server has no folder-confinement option — mount only the project directory you want it to work in.

## Tags

Follows the [repository tag conventions](../README.md):
`latest`, `X.Y.Z`, `X.Y`, `X`, `sha-<hash>`, `date-<date>`
