DATE = formatdate( "YYYY.MM.DD", timestamp() )
variable "GIT_SHA" {}

variable "MISE_VERSION" {
    # renovate: datasource=docker depName=ghcr.io/jdx/mise
    default = "2026.5"
}
variable "ACTIONS_RUNNER_VERSION" {
    # renovate: datasource=docker depName=ghcr.io/actions/actions-runner
    default = "2.334.0"
}

target "default" {
    context    = "."
    dockerfile = "Dockerfile"
    no-cache   = true
    platforms  = ["linux/amd64", "linux/arm64"]
    args = {
        MISE_VERSION           = MISE_VERSION
        ACTIONS_RUNNER_VERSION = ACTIONS_RUNNER_VERSION
    }

    tags = [
        "ghcr.io/mirceanton/actions-runner:latest",
        "ghcr.io/mirceanton/actions-runner:sha-${GIT_SHA}",
        "ghcr.io/mirceanton/actions-runner:date-${DATE}",
        "ghcr.io/mirceanton/actions-runner:${ACTIONS_RUNNER_VERSION}",
        "ghcr.io/mirceanton/actions-runner:${ACTIONS_RUNNER_VERSION}-mise-${MISE_VERSION}",
        can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+", ACTIONS_RUNNER_VERSION)) ? "ghcr.io/mirceanton/actions-runner:${regex("^([0-9]+\\.[0-9]+)", ACTIONS_RUNNER_VERSION)[0]}" : "",
        can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+", ACTIONS_RUNNER_VERSION)) ? "ghcr.io/mirceanton/actions-runner:${regex("^([0-9]+)", ACTIONS_RUNNER_VERSION)[0]}" : ""
    ]

    labels = {
        "org.opencontainers.image.vendor"      = "Mircea-Pavel Anton"
        "org.opencontainers.image.source"      = "https://github.com/mirceanton/container-images"
        "org.opencontainers.image.created"     = "${DATE}"
        "org.opencontainers.image.revision"    = "${GIT_SHA}"
        "org.opencontainers.image.licenses"    = "MIT"

        "org.opencontainers.image.title"       = "actions-runner"
        "org.opencontainers.image.authors"     = "Jeff Dickey"
        "org.opencontainers.image.description" = "GitHub Actions runner with mise pre-installed"
        "org.opencontainers.image.url"         = "https://github.com/jdx/mise"
        "org.opencontainers.image.version"     = "${ACTIONS_RUNNER_VERSION}-mise-${MISE_VERSION}"
    }
}
