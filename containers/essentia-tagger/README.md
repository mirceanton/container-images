# Essentia Music Tagger Container Image

Container image for [Essentia-to-Metadata](https://github.com/WB2024/Essentia-to-Metadata), a
tool that analyzes audio content with Essentia ML models and writes genre/mood tags directly to
music files.

## Why a custom image?

The upstream project publishes **no container images** — only a source repository with
Dockerfiles. This image builds from the upstream source at a pinned revision, baking the ML
models (~87 MB) into the image so they are always present.

## What's in the image

- **Python 3.10** with `essentia-tensorflow` (the Essentia library compiled with TensorFlow
  bindings), `mutagen` (tag writing), and `numpy`
- **Essentia ML models** downloaded at build time:
  - `discogs-effnet-bs64-1.pb` — audio embedding model
  - `genre_discogs400-discogs-effnet-1.pb` + metadata — 400 Discogs genre classes
  - `mtg_jamendo_moodtheme-discogs-effnet-1.pb` + metadata — mood/theme detection
- **Application code** from the upstream repo at the pinned revision
- **Entrypoint** that suppresses noisy Essentia logs and forwards arguments to `tag_music.py`

## Image size and performance

The built image is approximately 2–3 GB (TensorFlow + system deps + models). Processing speed
is ~5–15 seconds per track on a modern CPU; a library of 500 tracks takes 2–4 hours.
Memory usage is ~2–3 GB during processing.

### CPU-only

This is a **CPU-only** image (`python:3.10-slim` base). The upstream also provides a GPU
Dockerfile (`Dockerfile.gpu`) based on `nvidia/cuda:11.8.0-cudnn8-runtime-ubuntu22.04` that
achieves ~10× speedup with an NVIDIA GPU. A GPU variant can be added later if the cluster's
NVIDIA device plugin and time-slicing configuration prove sufficient.

## Tags

`latest`, `sha-<hash>`, `date-<date>`. Only `linux/amd64` is built.

## License

This image's Dockerfile and repository tooling are MIT (see the [repo LICENSE](../../LICENSE)).
The bundled upstream [Essentia-to-Metadata](https://github.com/WB2024/Essentia-to-Metadata)
code is MIT. The Essentia library itself is **AGPL-3.0**, and the pre-trained models from MTG
are available under **CC BY-NC-ND 4.0** for non-commercial use. Review the upstream licenses
before redistributing.
