# Container Images

Monorepo for various container images.

## Available Images

| Image                                                      | Description                          | Documentation                                   |
| ---------------------------------------------------------- | ------------------------------------ | ----------------------------------------------- |
| [actions-runner](https://ghcr.io/mirceanton/actions-runner) | Custom GHA runner image for my org.  | [README](./containers/actions-runner/README.md) |
| [carbon](https://ghcr.io/mirceanton/carbon)                 | Self-hosted carbon.now.sh            | [README](./containers/carbon/README.md)         |
| [filmcraft](https://ghcr.io/mirceanton/filmcraft)           | Headless NLE video editor + MCP server | [README](./containers/filmcraft/README.md)    |
| [zfs-exporter](https://ghcr.io/mirceanton/zfs-exporter)     | Prometheus exporter for ZFS metrics  | [README](./containers/zfs-exporter/README.md)   |

## Quick Start

All images are available from GitHub Container Registry:

```bash
docker pull ghcr.io/mirceanton/<image>:<tag>
```

See each image's README for detailed usage instructions and available tags.

## Tag Conventions

Unless otherwise specified, images follow a consistent tagging scheme:

| Tag            | Description                       |
| -------------- | --------------------------------- |
| `:latest`      | Latest version (where applicable) |
| `:X.Y.Z`       | Specific version                  |
| `:X.Y`         | Latest patch for minor version    |
| `:X`           | Latest for major version          |
| `:sha-<hash>`  | Specific git commit               |
| `:date-<date>` | Build date                        |

Some images have additional tag patterns for variant images. See the individual READMEs for details.

## License

This project is licensed under the MIT License - see the [LICENSE](./LICENSE) file for details.
