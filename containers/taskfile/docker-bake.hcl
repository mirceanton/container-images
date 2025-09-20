DATE = formatdate( "YYYY.MM.DD", timestamp() )
variable "GIT_SHA" {}
variable "VERSION" {
    # renovate: datasource=github-tags depName=go-task/task
    default = "3.45.4"
}

target "default" {
    context = "."
    dockerfile = "Dockerfile"
    no-cache = true
    platforms = ["linux/amd64", "linux/arm64"]
    args = { TASK_VERSION = VERSION }

    tags = [
        "ghcr.io/mirceanton/taskfile:latest",
        "ghcr.io/mirceanton/taskfile:sha-${GIT_SHA}",
        "ghcr.io/mirceanton/taskfile:date-${DATE}",
        "ghcr.io/mirceanton/taskfile:${VERSION}",
        can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+", VERSION)) ? "ghcr.io/mirceanton/taskfile:${regex("^([0-9]+\\.[0-9]+)", VERSION)[0]}" : "",
        can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+", VERSION)) ? "ghcr.io/mirceanton/taskfile:${regex("^([0-9]+)", VERSION)[0]}" : ""
    ]

    labels = {
        "org.opencontainers.image.vendor" = "Mircea-Pavel Anton"
        "org.opencontainers.image.source" = "https://github.com/mirceanton/container-images"
        "org.opencontainers.image.created" = "${DATE}"
        "org.opencontainers.image.revision" = "${GIT_SHA}"
        "org.opencontainers.image.licenses" = "MIT"

        "org.opencontainers.image.title" = "Task"
        "org.opencontainers.image.authors" = "Task Team"
        "org.opencontainers.image.description" = "Task runner / build tool in a container"
        "org.opencontainers.image.url" = "https://github.com/go-task/task"
        "org.opencontainers.image.version" = "${VERSION}"
    }
}