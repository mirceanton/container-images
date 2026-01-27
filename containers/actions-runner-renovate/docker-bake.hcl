DATE = formatdate( "YYYY.MM.DD", timestamp() )
variable "GIT_SHA" {}

variable "RUNNER_VERSION" {
    # renovate: datasource=docker depName=ghcr.io/actions/actions-runner
    default = "2.323.0"
}

variable "RENOVATE_VERSION" {
    # renovate: datasource=npm depName=renovate
    default = "42.93.0"
}

target "default" {
    context = "."
    dockerfile = "Dockerfile"
    no-cache = true
    platforms = ["linux/amd64", "linux/arm64"]
    args = {
        RUNNER_VERSION = RUNNER_VERSION
        RENOVATE_VERSION = RENOVATE_VERSION
    }

    tags = [
        "ghcr.io/mirceanton/actions-runner-renovate:latest",
        "ghcr.io/mirceanton/actions-runner-renovate:sha-${GIT_SHA}",
        "ghcr.io/mirceanton/actions-runner-renovate:date-${DATE}",
        "ghcr.io/mirceanton/actions-runner-renovate:runner-${RUNNER_VERSION}",
        "ghcr.io/mirceanton/actions-runner-renovate:renovate-${RENOVATE_VERSION}",
        "ghcr.io/mirceanton/actions-runner-renovate:runner-${RUNNER_VERSION}-renovate-${RENOVATE_VERSION}",
        "ghcr.io/mirceanton/actions-runner-renovate:${RENOVATE_VERSION}",
        can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+", RENOVATE_VERSION)) ? "ghcr.io/mirceanton/actions-runner-renovate:${regex("^([0-9]+\\.[0-9]+)", RENOVATE_VERSION)[0]}" : "",
        can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+", RENOVATE_VERSION)) ? "ghcr.io/mirceanton/actions-runner-renovate:${regex("^([0-9]+)", RENOVATE_VERSION)[0]}" : ""
    ]

    labels = {
        "org.opencontainers.image.vendor" = "Mircea-Pavel Anton"
        "org.opencontainers.image.source" = "https://github.com/mirceanton/container-images"
        "org.opencontainers.image.created" = "${DATE}"
        "org.opencontainers.image.revision" = "${GIT_SHA}"
        "org.opencontainers.image.licenses" = "MIT"

        "org.opencontainers.image.title" = "GitHub Actions Runner with Renovate"
        "org.opencontainers.image.authors" = "Mircea-Pavel Anton"
        "org.opencontainers.image.description" = "GitHub Actions self-hosted runner with Renovate pre-installed"
        "org.opencontainers.image.url" = "https://github.com/mirceanton/container-images"
        "org.opencontainers.image.version" = "runner-${RUNNER_VERSION}-renovate-${RENOVATE_VERSION}"
    }
}
