# Beets Library Audit Container Image

Container image for running [beets](https://beets.io/) library audits against an
existing music collection. Produces JSON and human-readable reports of metadata
quality without modifying any audio files.

## Why a custom image?

The linuxserver/beets image covers general beets usage but this image:

- Is purpose-built for **read-only audit** workflows
- Has a minimal dependency footprint (no web UI, no s6-overlay)
- Pins Python dependencies (`beets`, `mutagen`, `pyyaml`, `requests`) at reproducible versions
- Includes `flac` and `mp3val` for audio file integrity checks
- Ships the `audit.py` script that orchestrates the full audit

## What's in the image

- **Python 3.13** slim base
- **beets 2.3.1** with plugins: `fetchart`, `lyrics`, `lastgenre`, `chroma`, `scrub`
- **mutagen 1.47.0** — tag reading for files beets can't parse
- **pyyaml 6.0.3** — configuration handling
- **requests 2.32.5** — HTTP client for MusicBrainz
- **audit.py** — the audit script (see below)

## Plugins

| Plugin | Purpose |
|--------|---------|
| `info` | Dump tag values for any file |
| `missing` | Find albums with missing tracks |
| `badfiles` | Check audio file integrity (flac, mp3val) |
| `mbsync` | Sync metadata from MusicBrainz |
| `chroma` | Acoustic fingerprinting |

## Audit Script

The `audit.py` script scans a music library and produces:

- **JSON report** (`audit-<timestamp>.json`) — machine-readable, full details
- **Text summary** (`audit-<timestamp>.txt`) — human-readable overview

### Usage

```bash
# Report-only audit (default)
docker run --rm \
  -v /path/to/music:/music:ro \
  -v /path/to/data:/data \
  ghcr.io/mirceanton/beets:latest /music

# With custom paths
docker run --rm \
  -v /path/to/music:/music:ro \
  -v /path/to/data:/data \
  ghcr.io/mirceanton/beets:latest /music \
  --db /data/mylibrary.db \
  --config /data/myconfig.yaml \
  --output /data/reports

# Verbose
docker run --rm \
  -v /path/to/music:/music:ro \
  -v /path/to/data:/data \
  ghcr.io/mirceanton/beets:latest /music --verbose
```

### Report Contents

1. **Library statistics** — file counts, album counts, corrupt files, extensions
2. **MusicBrainz IDs** — missing or invalid `mb_trackid`, `mb_albumid`, `mb_artistid`, etc.
3. **Missing metadata** — missing artist, album, title, track number, year, genre
4. **Inconsistent albums** — conflicting years or album artists within an album
5. **Suspicious numbering** — track gaps, duplicate track numbers
6. **Ambiguous matches** — albums with multiple plausible MusicBrainz candidates
7. **High-confidence matches** — single clear MusicBrainz matches (reconciliation candidates)
8. **Existing tags** — genre and mood distribution (visibility only)

### Future Reconciliation

The `--reconcile` flag and `--reconcile-fields` option are stubs for a future
opt-in reconciliation mode. They currently allow applying MBIDs to the beets
database only; tag writing to audio files is intentionally gated behind
additional explicit configuration.

When implemented, reconciliation should:
- Apply only to high-confidence matches
- Support a field allowlist (`--reconcile-fields mb_albumid mb_artistid ...`)
- Support dry-run (`--reconcile --dry-run`)
- Never move or rename files
- Produce a diff of proposed vs applied changes

## Tags

`latest`, `sha-<hash>`, `date-<date>`. Only `linux/amd64` is built.

## License

This image's Dockerfile, audit script, and repository tooling are MIT (see the
[repo LICENSE](../../LICENSE)). The bundled [beets](https://github.com/beetbox/beets)
library is MIT. Mutagen is GPL-2.0.
