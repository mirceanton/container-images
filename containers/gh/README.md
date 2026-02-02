# GitHub CLI Container Image

Container image for [GitHub CLI](https://github.com/cli/cli), the official command line tool for GitHub.

> [!Note]
> This image is primarily intended for use as a build stage in multi-stage Dockerfiles to extract the `gh` binary. It is not designed to be a full-featured standalone image.  
> As such, PRs or requests to add additional binaries or utilities will not be accepted.

## Usage as a Build Stage

```dockerfile
FROM ghcr.io/mirceanton/gh:latest AS gh

FROM alpine:3.23
COPY --from=gh /usr/local/bin/gh /usr/local/bin/gh
# ... rest of your image
```

## Standalone Usage

```bash
docker pull ghcr.io/mirceanton/gh:latest
```

### Authenticate

```bash
docker run --rm -it -v ~/.config/gh:/root/.config/gh ghcr.io/mirceanton/gh \
  -c "gh auth login"
```

### List repositories

```bash
docker run --rm -v ~/.config/gh:/root/.config/gh ghcr.io/mirceanton/gh \
  -c "gh repo list"
```

## Included Tools

- `gh` - GitHub CLI
- `git` - version control
- `openssh-client` - SSH client for git operations


