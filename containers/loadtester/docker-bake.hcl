DATE = formatdate( "YYYY.MM.DD", timestamp() )
variable "GIT_SHA" {}
variable "VERSION" {
    default = "1.0.0"
}

target "default" {
    context    = "."
    dockerfile = "Dockerfile"
    no-cache   = true
    platforms  = ["linux/amd64", "linux/arm64"]

    tags = [
        "ghcr.io/mirceanton/loadtester:latest",
        "ghcr.io/mirceanton/loadtester:sha-${GIT_SHA}",
        "ghcr.io/mirceanton/loadtester:date-${DATE}",
        "ghcr.io/mirceanton/loadtester:${VERSION}",
        can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+", VERSION)) ? "ghcr.io/mirceanton/loadtester:${regex("^([0-9]+\\.[0-9]+)", VERSION)[0]}" : "",
        can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+", VERSION)) ? "ghcr.io/mirceanton/loadtester:${regex("^([0-9]+)", VERSION)[0]}" : ""
    ]

    labels = {
        "org.opencontainers.image.vendor"      = "Mircea-Pavel Anton"
        "org.opencontainers.image.source"      = "https://github.com/mirceanton/container-images"
        "org.opencontainers.image.created"     = "${DATE}"
        "org.opencontainers.image.revision"    = "${GIT_SHA}"
        "org.opencontainers.image.licenses"    = "MIT"

        "org.opencontainers.image.title"       = "loadtester"
        "org.opencontainers.image.authors"     = "Mircea-Pavel Anton"
        "org.opencontainers.image.description" = "Minimal REST API for simulating CPU/RAM load — used to demo Kubernetes HPA autoscaling"
        "org.opencontainers.image.url"         = "https://github.com/mirceanton/container-images"
        "org.opencontainers.image.version"     = "${VERSION}"
    }
}
