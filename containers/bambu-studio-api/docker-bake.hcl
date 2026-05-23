DATE = formatdate( "YYYY.MM.DD", timestamp() )
variable "GIT_SHA" {}
variable "VERSION" {
    # renovate: datasource=github-releases depName=bambulab/BambuStudio extractVersion=^v(?P<version>.+)$ versioning=loose
    default = "02.06.00.51"
}

target "default" {
    context    = "https://github.com/maziggy/orca-slicer-api.git#bambuddy/profile-resolver"
    dockerfile = "Dockerfile.bambu-studio"
    no-cache   = true
    platforms  = ["linux/amd64"]
    args       = { BAMBU_VERSION = VERSION }

    tags = [
        "ghcr.io/mirceanton/bambu-studio-api:latest",
        "ghcr.io/mirceanton/bambu-studio-api:sha-${GIT_SHA}",
        "ghcr.io/mirceanton/bambu-studio-api:date-${DATE}",
        "ghcr.io/mirceanton/bambu-studio-api:${VERSION}",
    ]

    labels = {
        "org.opencontainers.image.vendor"      = "Mircea-Pavel Anton"
        "org.opencontainers.image.source"      = "https://github.com/mirceanton/container-images"
        "org.opencontainers.image.created"     = "${DATE}"
        "org.opencontainers.image.revision"    = "${GIT_SHA}"
        "org.opencontainers.image.licenses"    = "MIT"

        "org.opencontainers.image.title"       = "bambu-studio-api"
        "org.opencontainers.image.authors"     = "maziggy"
        "org.opencontainers.image.description" = "Bambu Studio CLI HTTP wrapper with BambuBuddy profile resolution patches"
        "org.opencontainers.image.url"         = "https://github.com/maziggy/orca-slicer-api/tree/bambuddy/profile-resolver"
        "org.opencontainers.image.version"     = "${VERSION}"
    }
}
