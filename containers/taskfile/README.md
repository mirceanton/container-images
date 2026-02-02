# Taskfile Container Image

Container image for [Task](https://github.com/go-task/task), a task runner / build tool that aims to be simpler and easier to use than GNU Make.

> [!Note]
> This image is primarily intended for use as a build stage in multi-stage Dockerfiles to extract the `task` binary. It is not designed to be a full-featured standalone image.  
> As such, PRs or requests to add additional binaries or utilities will not be accepted.

## Usage as a Build Stage

```dockerfile
FROM ghcr.io/mirceanton/taskfile:latest AS task

FROM alpine:3.23
COPY --from=task /usr/local/bin/task /usr/local/bin/task
# ... rest of your image
```

## Standalone Usage

```bash
docker pull ghcr.io/mirceanton/taskfile:latest
```

### Run the default task

```bash
docker run --rm -v $(pwd):/workspace ghcr.io/mirceanton/taskfile \
  -c "task"
```

### Run a specific task

```bash
docker run --rm -v $(pwd):/workspace ghcr.io/mirceanton/taskfile \
  -c "task build"
```

### List available tasks

```bash
docker run --rm -v $(pwd):/workspace ghcr.io/mirceanton/taskfile \
  -c "task --list"
```

## Included Tools

- `task` - Task runner
- `bash` - shell
- `git` - version control


