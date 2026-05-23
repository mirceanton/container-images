DATE = formatdate( "YYYY.MM.DD", timestamp() )
variable "GIT_SHA" {}
variable "VERSION" {
    # renovate: datasource=github-releases depName=SoftFever/OrcaSlicer extractVersion=^v(?P<version>.+)$
    default = "2.3.2"
}

target "default" {
    context    = "https://github.com/maziggy/orca-slicer-api.git#bambuddy/profile-resolver"
    dockerfile = "Dockerfile"
    no-cache   = true
    platforms  = ["linux/amd64"]
    args       = { ORCA_VERSION = VERSION }

    tags = [
        "ghcr.io/mirceanton/orca-slicer-api:latest",
        "ghcr.io/mirceanton/orca-slicer-api:sha-${GIT_SHA}",
        "ghcr.io/mirceanton/orca-slicer-api:date-${DATE}",
        "ghcr.io/mirceanton/orca-slicer-api:${VERSION}",
        can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+", VERSION)) ? "ghcr.io/mirceanton/orca-slicer-api:${regex("^([0-9]+\\.[0-9]+)", VERSION)[0]}" : "",
        can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+", VERSION)) ? "ghcr.io/mirceanton/orca-slicer-api:${regex("^([0-9]+)", VERSION)[0]}" : ""
    ]

    labels = {
        "org.opencontainers.image.vendor"      = "Mircea-Pavel Anton"
        "org.opencontainers.image.source"      = "https://github.com/mirceanton/container-images"
        "org.opencontainers.image.created"     = "${DATE}"
        "org.opencontainers.image.revision"    = "${GIT_SHA}"
        "org.opencontainers.image.licenses"    = "MIT"

        "org.opencontainers.image.title"       = "orca-slicer-api"
        "org.opencontainers.image.authors"     = "maziggy"
        "org.opencontainers.image.description" = "OrcaSlicer CLI HTTP wrapper with BambuBuddy profile resolution patches"
        "org.opencontainers.image.url"         = "https://github.com/maziggy/orca-slicer-api/tree/bambuddy/profile-resolver"
        "org.opencontainers.image.version"     = "${VERSION}"
    }
}
