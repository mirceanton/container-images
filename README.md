# Container Images

Monorepo for various container images.

## Available Images

| Image                                               | Description                          | Documentation                               |
| --------------------------------------------------- | ------------------------------------ | ------------------------------------------- |
| [age](https://ghcr.io/mirceanton/age)               | Modern encryption tool               | [README](./containers/age/README.md)        |
| [gh](https://ghcr.io/mirceanton/gh)                 | GitHub CLI                           | [README](./containers/gh/README.md)         |
| [taskfile](https://ghcr.io/mirceanton/taskfile)     | Task runner / build tool             | [README](./containers/taskfile/README.md)   |
| [terragrunt](https://ghcr.io/mirceanton/terragrunt) | Infrastructure as Code orchestration | [README](./containers/terragrunt/README.md) |

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

Some images (like terragrunt) have additional tag patterns for variant images. See the individual READMEs for details.

## License

This project is licensed under the MIT License - see the [LICENSE](./LICENSE) file for details.
