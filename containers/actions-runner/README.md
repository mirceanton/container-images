# `actions-runner` Container Image

Custom container image for github actions runers with [mise](https://github.com/jdx/mise), a tool version manager for dev environments., baked in.

## Usage

```bash
docker pull ghcr.io/mirceanton/containers/actions-runner:latest
```

### Use as a GitHub Actions job container

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    container: ghcr.io/mirceanton/containers/actions-runner:latest
    steps:
      - uses: actions/checkout@v4
      - run: mise install
      - run: mise exec -- <your-tool> <args>
```

### Run locally

```bash
docker run --rm -v $(pwd):/work -w /work ghcr.io/mirceanton/containers/actions-runner:latest \
  -c "mise install && mise exec -- task build"
```

## Included Tools

- `mise` - tool version manager
- Everything included in `ghcr.io/actions/actions-runner` (bash, git, curl, etc.)
