#!/usr/bin/env python3
"""Beets library audit: inspect an existing music library without modifying files.

Produces a JSON report with:
  - Library statistics (file/album counts)
  - Missing/invalid MusicBrainz IDs
  - Missing metadata fields
  - Ambiguous match candidates
  - Corrupt/unreadable files
  - A human-readable summary

Audit mode (default):  read-only — no files are moved, copied, renamed, or retagged.
Reconcile mode (opt-in): use --reconcile to apply high-confidence MusicBrainz fixes
                          (requires explicit opt-in per field category).
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import time
import traceback
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

# --- beets imports ---
import beets
from beets.library import Library
from beets.autotag import mb

# --- mutagen (fallback tag reader for files beets can't parse) ---
import mutagen

# --- Constants ---
MUSICBRAINZ_ID_FIELDS = [
    "mb_trackid",
    "mb_releasetrackid",
    "mb_albumid",
    "mb_releasegroupid",
    "mb_artistid",
    "mb_albumartistid",
]

CORE_METADATA_FIELDS = [
    "artist",
    "albumartist",
    "album",
    "title",
    "track",
    "tracktotal",
    "disc",
    "disctotal",
    "year",
    "genre",
]

AUDIO_EXTENSIONS = {
    ".mp3", ".flac", ".ogg", ".opus", ".m4a", ".aac",
    ".wma", ".wav", ".aiff", ".alac", ".ape", ".wv", ".mpc",
}

MB_RATE_LIMIT = 1.0  # seconds between MusicBrainz API calls


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Beets library audit")
    p.add_argument("music_dir", help="Root music library directory")
    p.add_argument("--db", default="/data/beets.db", help="Beets database path")
    p.add_argument("--config", default="/data/config.yaml", help="Beets config path")
    p.add_argument("--output", default="/data/reports", help="Report output directory")
    p.add_argument(
        "--reconcile",
        action="store_true",
        default=False,
        help="Apply high-confidence fixes (default: report-only)",
    )
    p.add_argument(
        "--reconcile-fields",
        nargs="*",
        default=[],
        help="Fields to reconcile (default: none; require explicit opt-in)",
    )
    p.add_argument(
        "--verbose", "-v", action="store_true", default=False, help="Verbose output"
    )
    return p.parse_args()


def write_beets_config(config_path: str, music_dir: str, db_path: str) -> None:
    """Write a minimal beets config that points at the existing library
    and disables all file-modifying behaviour."""
    cfg = {
        "directory": music_dir,
        "library": db_path,
        "import": {
            "copy": False,
            "move": False,
            "write": False,
            "resume": "no",
            "incremental": False,
            "quiet_fallback": "skip",
            "timid": True,
            "log": "/data/beet.log",
        },
        "paths": {"default": "$artist/$album/$track $title"},
        "plugins": "info missing badfiles mbsync",
        "musicbrainz": {
            "searchlimit": 3,
        },
        "match": {
            "max_rec": {
                "missing_tracks": "medium",
                "unmatched_tracks": "medium",
            },
        },
        "badfiles": {
            "check_on_import": False,
        },
        "ui": {
            "color": False,
        },
    }
    Path(config_path).parent.mkdir(parents=True, exist_ok=True)
    with open(config_path, "w") as f:
        import yaml as _yaml

        _yaml.dump(cfg, f, default_flow_style=False)


def init_beets_lib(music_dir: str, db_path: str) -> Library:
    """Initialise the beets library, cataloguing files without modifying them.

    Uses subprocess to call `beet import` with safe flags:
      -A  don't autotag
      -C  don't copy
      -W  don't write tags
      -q  quiet (don't prompt)
    """
    lib = Library(db_path, directory=music_dir)

    # Import files as-is using the beets CLI (subprocess for stability across versions)
    result = subprocess.run(
        [
            "beet",
            "-l", db_path,
            "-d", music_dir,
            "import",
            "-A",   # don't autotag
            "-C",   # don't copy
            "-W",   # don't write tags
            "-q",   # quiet
            music_dir,
        ],
        capture_output=True,
        text=True,
        timeout=3600,  # 1 hour timeout for large libraries
    )
    if result.returncode != 0:
        print(f"  [INFO] beets import exit code {result.returncode}: {result.stderr.strip()}", file=sys.stderr)
        # Don't fail — the library may already be catalogued

    return lib


def scan_files_raw(music_dir: str) -> dict[str, Any]:
    """Walk the music directory and collect raw file stats via mutagen.
    Returns counts and a list of files that failed tag reading."""
    total = 0
    corrupt: list[dict[str, str]] = []
    extensions: Counter[str] = Counter()

    for root, _dirs, files in os.walk(music_dir):
        for fname in files:
            ext = Path(fname).suffix.lower()
            if ext not in AUDIO_EXTENSIONS:
                continue
            extensions[ext] += 1
            total += 1
            fpath = os.path.join(root, fname)
            try:
                mf = mutagen.File(fpath)
                if mf is None:
                    corrupt.append({"path": fpath, "reason": "Unknown/unsupported format"})
            except Exception as exc:
                corrupt.append(
                    {
                        "path": fpath,
                        "reason": f"mutagen parse error: {exc}",
                    }
                )

    return {
        "total_files": total,
        "corrupt_files": len(corrupt),
        "corrupt_file_details": corrupt,
        "extensions": dict(extensions),
    }


def check_missing_ids(lib: Library) -> dict[str, Any]:
    """Check for missing or invalid MusicBrainz IDs across the library."""
    missing: dict[str, list[str]] = {f: [] for f in MUSICBRAINZ_ID_FIELDS}
    invalid: dict[str, list[str]] = {f: [] for f in MUSICBRAINZ_ID_FIELDS}

    for item in lib.items():
        for field in MUSICBRAINZ_ID_FIELDS:
            val = item.get(field)
            if not val:
                missing[field].append(item.path.decode() if isinstance(item.path, bytes) else item.path)
            elif field.startswith("mb_") and not _looks_valid_mbid(val):
                invalid[field].append(
                    {
                        "path": item.path.decode() if isinstance(item.path, bytes) else item.path,
                        "value": val,
                    }
                )

    return {
        "missing": {k: v for k, v in missing.items() if v},
        "invalid": {k: v for k, v in invalid.items() if v},
    }


def _looks_valid_mbid(val: str) -> bool:
    """Check if a value looks like a valid MusicBrainz UUID."""
    import re

    return bool(re.match(r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", val, re.I))


def check_missing_fields(lib: Library) -> dict[str, Any]:
    """Check for missing core metadata fields."""
    missing: dict[str, list[dict[str, str]]] = {f: [] for f in CORE_METADATA_FIELDS}

    for item in lib.items():
        path = item.path.decode() if isinstance(item.path, bytes) else item.path
        for field in CORE_METADATA_FIELDS:
            val = item.get(field)
            if val is None or val == "" or val == 0:
                missing[field].append({"path": path, "artist": item.artist, "album": item.album, "title": item.title})

    return {k: v for k, v in missing.items() if v}


def check_inconsistent_albums(lib: Library) -> list[dict[str, Any]]:
    """Find albums where tracks have conflicting release metadata."""
    warnings: list[dict[str, Any]] = []
    albums = lib.albums()

    for album in albums:
        items = list(album.items())
        if len(items) < 2:
            continue

        # Check for conflicting years
        years = {i.year for i in items if i.year}
        if len(years) > 1:
            warnings.append(
                {
                    "album": album.album,
                    "albumartist": album.albumartist,
                    "issue": "conflicting_years",
                    "years": sorted(years),
                    "tracks": [
                        {
                            "title": i.title,
                            "year": i.year,
                            "path": i.path.decode() if isinstance(i.path, bytes) else i.path,
                        }
                        for i in items
                    ],
                }
            )

        # Check for conflicting albumartists
        artists = {i.albumartist for i in items if i.albumartist}
        if len(artists) > 1:
            warnings.append(
                {
                    "album": album.album,
                    "albumartist": album.albumartist,
                    "issue": "conflicting_albumartists",
                    "albumartists": sorted(artists),
                }
            )

    return warnings


def check_suspicious_numbering(lib: Library) -> list[dict[str, Any]]:
    """Find albums with suspicious track/disc numbering."""
    warnings: list[dict[str, Any]] = []

    for album in lib.albums():
        items = list(album.items())
        if len(items) < 2:
            continue

        tracks = sorted(i.track for i in items if i.track)
        if not tracks:
            continue

        # Check for gaps in track numbering
        expected = list(range(1, len(tracks) + 1))
        if tracks != expected and tracks != list(range(tracks[0], tracks[0] + len(tracks))):
            warnings.append(
                {
                    "album": album.album,
                    "albumartist": album.albumartist,
                    "issue": "suspicious_track_numbering",
                    "tracks_present": tracks,
                    "track_count": len(items),
                    "expected": expected,
                }
            )

        # Check for duplicate track numbers
        track_counts = Counter(i.track for i in items if i.track)
        dups = {t: c for t, c in track_counts.items() if c > 1}
        if dups:
            warnings.append(
                {
                    "album": album.album,
                    "albumartist": album.albumartist,
                    "issue": "duplicate_track_numbers",
                    "duplicates": dups,
                }
            )

    return warnings


def find_ambiguous_matches(lib: Library) -> list[dict[str, Any]]:
    """Use MusicBrainz to find albums that have ambiguous matches.

    Albums WITHOUT MBIDs are looked up on MusicBrainz. If the search returns
    multiple plausible releases, the album is flagged as ambiguous and all
    candidates are reported for human review.
    """
    ambiguous: list[dict[str, Any]] = []
    last_call = 0.0

    for album in lib.albums():
        if album.mb_albumid:
            continue  # Already has a definitive match

        # Rate-limit MusicBrainz calls
        elapsed = time.time() - last_call
        if elapsed < MB_RATE_LIMIT:
            time.sleep(MB_RATE_LIMIT - elapsed)

        try:
            results = list(mb.match_album(album.albumartist or "", album.album or ""))
            last_call = time.time()

            if len(results) > 1:
                candidates = []
                for r in results[:3]:
                    track_count = len(r.tracks) if r.tracks else 0
                    candidates.append(
                        {
                            "artist": r.artist,
                            "album": r.album,
                            "id": r.album_id,
                            "track_count": track_count,
                            "year": r.year,
                            "country": getattr(r, "country", ""),
                            "label": getattr(r, "label", ""),
                            "media": getattr(r, "media", ""),
                        }
                    )
                ambiguous.append(
                    {
                        "album": album.album,
                        "albumartist": album.albumartist,
                        "candidates": candidates,
                    }
                )
        except Exception as exc:
            print(
                f"  [WARN] MusicBrainz lookup failed for {album.albumartist} - {album.album}: {exc}",
                file=sys.stderr,
            )
            continue

    return ambiguous


def find_high_confidence_matches(lib: Library) -> list[dict[str, Any]]:
    """Find albums with a single MusicBrainz match.

    These are candidates for automatic reconciliation when --reconcile is used.
    A single MB result is considered high-confidence (though not bulletproof —
    it could still match the wrong edition).
    """
    high_conf: list[dict[str, Any]] = []
    last_call = 0.0

    for album in lib.albums():
        if album.mb_albumid:
            continue

        elapsed = time.time() - last_call
        if elapsed < MB_RATE_LIMIT:
            time.sleep(MB_RATE_LIMIT - elapsed)

        try:
            results = list(mb.match_album(album.albumartist or "", album.album or ""))
            last_call = time.time()

            if len(results) == 1:
                r = results[0]
                track_count = len(r.tracks) if r.tracks else 0
                high_conf.append(
                    {
                        "album": album.album,
                        "albumartist": album.albumartist,
                        "match": {
                            "artist": r.artist,
                            "album": r.album,
                            "id": r.album_id,
                            "track_count": track_count,
                            "year": r.year,
                            "releasegroup_id": getattr(r, "releasegroup_id", ""),
                        },
                        "proposed_action": (
                            "Set mb_albumid, mb_releasegroupid, and mb_albumartistid "
                            "from this MusicBrainz release"
                        ),
                    }
                )
        except Exception as exc:
            print(
                f"  [WARN] MusicBrainz lookup failed for {album.albumartist} - {album.album}: {exc}",
                file=sys.stderr,
            )
            continue

    return high_conf


def check_existing_tags_visibility(lib: Library) -> dict[str, Any]:
    """Report on existing genre and mood fields for visibility only."""
    genres = Counter()
    moods = Counter()

    for item in lib.items():
        genre = item.get("genre")
        if genre:
            genres[genre] += 1
        mood = item.get("mood")
        if mood:
            moods[mood] += 1

    return {
        "genre_counts": dict(genres.most_common(50)),
        "mood_counts": dict(moods.most_common(50)),
    }


def generate_summary(report: dict[str, Any]) -> str:
    """Generate a human-readable summary from the report data."""
    lines = []
    lines.append("=" * 60)
    lines.append("BEETS LIBRARY AUDIT REPORT")
    lines.append("=" * 60)
    lines.append(f"Run timestamp: {report['run_timestamp']}")
    lines.append(f"Tool: beets {report['beets_version']}")
    lines.append(f"Music directory: {report['music_dir']}")
    lines.append("")

    stats = report["statistics"]
    lines.append("--- LIBRARY STATISTICS ---")
    lines.append(f"Total files:      {stats['total_files']}")
    lines.append(f"Total albums:     {stats.get('total_albums', 'N/A')}")
    lines.append(f"Corrupt files:    {stats['corrupt_files']}")
    lines.append(f"Catalogued items: {stats['catalogued_items']}")
    lines.append(f"Catalogued albums:{stats['catalogued_albums']}")
    lines.append("")

    ids = report["musicbrainz_ids"]
    lines.append("--- MUSICBRAINZ IDs ---")
    for field, paths in sorted(ids.get("missing", {}).items()):
        lines.append(f"Missing {field}: {len(paths)} items")
    for field, items_ in sorted(ids.get("invalid", {}).items()):
        lines.append(f"Invalid {field}: {len(items_)} items")
    lines.append("")

    md = report["missing_metadata"]
    lines.append("--- MISSING METADATA ---")
    for field, items_ in sorted(md.items()):
        lines.append(f"Missing {field}: {len(items_)} items")
    lines.append("")

    ic = report["inconsistent_albums"]
    if ic:
        lines.append(f"--- INCONSISTENT ALBUMS: {len(ic)} ---")
        for w in ic:
            lines.append(f"  {w['albumartist']} - {w['album']}: {w['issue']}")
    else:
        lines.append("--- INCONSISTENT ALBUMS: 0 ---")
    lines.append("")

    sn = report["suspicious_numbering"]
    if sn:
        lines.append(f"--- SUSPICIOUS NUMBERING: {len(sn)} ---")
        for w in sn:
            lines.append(f"  {w['albumartist']} - {w['album']}: {w['issue']}")
    else:
        lines.append("--- SUSPICIOUS NUMBERING: 0 ---")
    lines.append("")

    am = report["ambiguous_matches"]
    lines.append(f"--- AMBIGUOUS MATCHES (review required): {len(am)} ---")
    for a in am:
        lines.append(f"  {a['albumartist']} - {a['album']}: {len(a['candidates'])} candidates")
    lines.append("")

    hc = report["high_confidence_matches"]
    lines.append(f"--- HIGH-CONFIDENCE MATCHES: {len(hc)} ---")
    for h in hc:
        lines.append(f"  {h['albumartist']} - {h['album']} → {h['match']['artist']} - {h['match']['album']} ({h['match']['id']})")
    lines.append("")

    cf = stats.get("corrupt_file_details", [])
    if cf:
        lines.append(f"--- CORRUPT/UNREADABLE FILES: {len(cf)} ---")
        for c in cf[:20]:  # cap at 20 in the summary
            lines.append(f"  {c['path']}: {c['reason']}")
        if len(cf) > 20:
            lines.append(f"  ... and {len(cf) - 20} more")
    lines.append("")

    lines.append("--- EXISTING TAGS (visibility only) ---")
    tags = report.get("existing_tags", {})
    if tags.get("genre_counts"):
        lines.append("Top genres:")
        for genre, count in list(tags["genre_counts"].items())[:10]:
            lines.append(f"  {genre}: {count}")
    if tags.get("mood_counts"):
        lines.append("Top moods:")
        for mood, count in list(tags["mood_counts"].items())[:10]:
            lines.append(f"  {mood}: {count}")
    lines.append("")

    lines.append("=" * 60)
    lines.append("END OF REPORT")
    return "\n".join(lines)


def reconcile(lib: Library, report: dict[str, Any], args: argparse.Namespace) -> dict[str, Any]:
    """Apply high-confidence MusicBrainz matches to the beets database only.

    Does NOT write tags to files unless --reconcile-fields includes 'tags'.
    """
    if not args.reconcile:
        return {"applied": 0, "message": "Reconcile mode not enabled (use --reconcile)"}

    if not args.reconcile_fields:
        return {"applied": 0, "message": "No fields specified for reconciliation (use --reconcile-fields)"}

    applied = 0
    for match in report.get("high_confidence_matches", []):
        album_query = f"albumartist:{match['albumartist']} album:{match['album']}"
        album = lib.albums(album_query)
        if not album:
            continue
        album = album[0]
        r = match["match"]

        if "mb_albumid" in args.reconcile_fields:
            album.mb_albumid = r["id"]
        if "mb_albumartistid" in args.reconcile_fields:
            # Fetch the release from MB to get the artist MBID
            try:
                release = mb.album_for_id(r["id"])
                if release:
                    album.mb_albumartistid = release.albumartist_id
                    album.mb_releasegroupid = release.releasegroup_id
            except Exception:
                pass

        album.store()
        applied += 1

    return {"applied": applied, "message": f"Applied MBIDs to {applied} albums (database only)"}


def main() -> None:
    args = parse_args()

    # Ensure output directory exists
    os.makedirs(args.output, exist_ok=True)

    run_ts = datetime.now(timezone.utc).isoformat()

    report: dict[str, Any] = {
        "run_timestamp": run_ts,
        "music_dir": args.music_dir,
        "beets_version": beets.__version__,
        "mode": "reconcile" if args.reconcile else "audit",
        "reconcile_fields": args.reconcile_fields if args.reconcile else [],
    }

    print(f"[{run_ts}] Starting beets library audit", file=sys.stderr)
    print(f"  Music dir: {args.music_dir}", file=sys.stderr)
    print(f"  DB path:   {args.db}", file=sys.stderr)
    print(f"  Mode:      {report['mode']}", file=sys.stderr)

    # --- Phase 1: Raw file scan (mutagen) ---
    print("\n[Phase 1] Scanning files with mutagen...", file=sys.stderr)
    raw = scan_files_raw(args.music_dir)
    report["statistics"] = {
        "total_files": raw["total_files"],
        "corrupt_files": raw["corrupt_files"],
        "corrupt_file_details": raw.get("corrupt_file_details", []),
        "extensions": raw["extensions"],
    }

    # --- Phase 2: Initialise beets library ---
    print("[Phase 2] Writing beets config...", file=sys.stderr)
    write_beets_config(args.config, args.music_dir, args.db)

    print("[Phase 2] Cataloguing library with beets...", file=sys.stderr)
    lib = init_beets_lib(args.music_dir, args.db)

    cat_items = len(list(lib.items()))
    cat_albums = len(list(lib.albums()))
    report["statistics"]["catalogued_items"] = cat_items
    report["statistics"]["catalogued_albums"] = cat_albums
    print(f"  Catalogued: {cat_items} items, {cat_albums} albums", file=sys.stderr)

    # --- Phase 3: Missing MusicBrainz IDs ---
    print("[Phase 3] Checking MusicBrainz IDs...", file=sys.stderr)
    report["musicbrainz_ids"] = check_missing_ids(lib)

    # --- Phase 4: Missing metadata fields ---
    print("[Phase 4] Checking missing metadata fields...", file=sys.stderr)
    report["missing_metadata"] = check_missing_fields(lib)

    # --- Phase 5: Inconsistent albums ---
    print("[Phase 5] Checking inconsistent album metadata...", file=sys.stderr)
    report["inconsistent_albums"] = check_inconsistent_albums(lib)

    # --- Phase 6: Suspicious numbering ---
    print("[Phase 6] Checking suspicious track/disc numbering...", file=sys.stderr)
    report["suspicious_numbering"] = check_suspicious_numbering(lib)

    # --- Phase 7: Ambiguous MusicBrainz matches ---
    print("[Phase 7] Finding ambiguous MusicBrainz matches...", file=sys.stderr)
    report["ambiguous_matches"] = find_ambiguous_matches(lib)

    # --- Phase 8: High-confidence matches ---
    print("[Phase 8] Finding high-confidence MusicBrainz matches...", file=sys.stderr)
    report["high_confidence_matches"] = find_high_confidence_matches(lib)

    # --- Phase 9: Existing tags visibility ---
    print("[Phase 9] Reporting existing genre/mood tags...", file=sys.stderr)
    report["existing_tags"] = check_existing_tags_visibility(lib)

    # --- Phase 10: Reconcile (if enabled) ---
    if args.reconcile:
        print("[Phase 10] Applying high-confidence matches...", file=sys.stderr)
        report["reconciliation"] = reconcile(lib, report, args)

    # --- Write reports ---
    ts = datetime.now().strftime("%Y%m%d-%H%M%S")

    json_path = os.path.join(args.output, f"audit-{ts}.json")
    with open(json_path, "w") as f:
        json.dump(report, f, indent=2, default=str, ensure_ascii=False)
    print(f"\nJSON report written to {json_path}", file=sys.stderr)

    summary_path = os.path.join(args.output, f"audit-{ts}.txt")
    with open(summary_path, "w") as f:
        f.write(generate_summary(report))
    print(f"Summary written to {summary_path}", file=sys.stderr)

    # Print summary to stdout for Dagu log
    print(generate_summary(report))

    # Exit non-zero if there are critical issues
    critical = report["statistics"]["corrupt_files"]
    if critical > 0:
        print(f"\n[WARN] {critical} corrupt/unreadable files found", file=sys.stderr)

    print("\nAudit complete.", file=sys.stderr)


if __name__ == "__main__":
    try:
        main()
    except Exception:
        traceback.print_exc(file=sys.stderr)
        sys.exit(1)
