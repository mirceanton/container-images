#!/usr/bin/env python3
"""Beets library audit and reconciliation.

Produces a JSON report with:
  - Library statistics (file/album counts)
  - Missing/invalid MusicBrainz IDs
  - Missing metadata fields
  - Ambiguous match candidates
  - Corrupt/unreadable files
  - Reconciliation plan (what would change)
  - A human-readable summary

Modes:
  --dry-run (default): analyse, produce report + reconciliation plan, no writes.
  --apply:             execute the reconciliation plan — write MBIDs and tags.
                       Does NOT move, copy, or rename files.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import time
import traceback
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

# --- beets imports ---
import beets
from beets.library import Library
from beets.autotag import mb

# --- mutagen ---
import mutagen

# --- Constants ---
MUSICBRAINZ_ID_FIELDS = [
    "mb_trackid", "mb_releasetrackid", "mb_albumid",
    "mb_releasegroupid", "mb_artistid", "mb_albumartistid",
]

CORE_METADATA_FIELDS = [
    "artist", "albumartist", "album", "title",
    "track", "tracktotal", "disc", "disctotal", "year", "genre",
]

AUDIO_EXTENSIONS = {
    ".mp3", ".flac", ".ogg", ".opus", ".m4a", ".aac",
    ".wma", ".wav", ".aiff", ".alac", ".ape", ".wv", ".mpc",
}

MB_RATE_LIMIT = 1.0


# =============================================================================
# CLI
# =============================================================================

def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Beets library audit and reconciliation")
    p.add_argument("music_dir", help="Root music library directory")
    p.add_argument("--db", default="/data/beets.db", help="Beets database path")
    p.add_argument("--config", default="/data/config.yaml", help="Beets config path")
    p.add_argument("--output", default="/data/reports", help="Report output directory")

    mode = p.add_mutually_exclusive_group()
    mode.add_argument(
        "--dry-run", action="store_true", default=True,
        help="Analyse and report only — do not modify files (default)",
    )
    mode.add_argument(
        "--apply", action="store_true", default=False,
        help="Apply reconciliation: write MBIDs and tags for high-confidence matches",
    )

    p.add_argument(
        "--reconcile-mode", choices=["mbsync", "match", "both"], default="both",
        help="What to reconcile: mbsync (refresh items with MBIDs), "
             "match (assign MBIDs from high-confidence matches), both (default)",
    )
    p.add_argument(
        "--verbose", "-v", action="store_true", default=False,
        help="Verbose output",
    )
    return p.parse_args()


# =============================================================================
# Beets configuration
# =============================================================================

def write_beets_config(config_path: str, music_dir: str, db_path: str,
                       apply_mode: bool = False) -> None:
    """Write a beets config. Tag writing is only enabled in --apply mode."""
    cfg = {
        "directory": music_dir,
        "library": db_path,
        "import": {
            "copy": False, "move": False,
            "write": apply_mode,
            "resume": "no", "incremental": False,
            "quiet_fallback": "skip", "timid": True,
            "log": "/data/beet.log",
        },
        "paths": {"default": "$artist/$album/$track $title"},
        "plugins": "info missing badfiles mbsync",
        "musicbrainz": {"searchlimit": 3},
        "match": {"max_rec": {"missing_tracks": "medium", "unmatched_tracks": "medium"}},
        "badfiles": {"check_on_import": False},
        "ui": {"color": False},
    }
    Path(config_path).parent.mkdir(parents=True, exist_ok=True)
    with open(config_path, "w") as f:
        import yaml as _yaml
        _yaml.dump(cfg, f, default_flow_style=False)


# =============================================================================
# Library init
# =============================================================================

def init_beets_lib(music_dir: str, db_path: str) -> Library:
    lib = Library(db_path, directory=music_dir)
    result = subprocess.run(
        ["beet", "-l", db_path, "-d", music_dir,
         "import", "-A", "-C", "-W", "-q", music_dir],
        capture_output=True, text=True, timeout=3600,
    )
    if result.returncode != 0:
        print(f"  [INFO] beets import exit {result.returncode}: {result.stderr.strip()}",
              file=sys.stderr)
    return lib


# =============================================================================
# Phase 1 — Raw scan
# =============================================================================

def scan_files_raw(music_dir: str) -> dict[str, Any]:
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
                corrupt.append({"path": fpath, "reason": f"mutagen parse error: {exc}"})
    return {
        "total_files": total, "corrupt_files": len(corrupt),
        "corrupt_file_details": corrupt, "extensions": dict(extensions),
    }


# =============================================================================
# Phase 3 — MusicBrainz IDs
# =============================================================================

def _looks_valid_mbid(val: str) -> bool:
    return bool(re.match(
        r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$",
        val, re.I,
    ))

def check_missing_ids(lib: Library) -> dict[str, Any]:
    missing: dict[str, list[str]] = {f: [] for f in MUSICBRAINZ_ID_FIELDS}
    invalid: dict[str, list[dict[str, str]]] = {f: [] for f in MUSICBRAINZ_ID_FIELDS}
    for item in lib.items():
        path = item.path.decode() if isinstance(item.path, bytes) else item.path
        for field in MUSICBRAINZ_ID_FIELDS:
            val = item.get(field)
            if not val:
                missing[field].append(path)
            elif field.startswith("mb_") and not _looks_valid_mbid(val):
                invalid[field].append({"path": path, "value": str(val)})
    return {
        "missing": {k: v for k, v in missing.items() if v},
        "invalid": {k: v for k, v in invalid.items() if v},
    }


# =============================================================================
# Phase 4 — Missing metadata
# =============================================================================

def check_missing_fields(lib: Library) -> dict[str, Any]:
    missing: dict[str, list[dict[str, str]]] = {f: [] for f in CORE_METADATA_FIELDS}
    for item in lib.items():
        path = item.path.decode() if isinstance(item.path, bytes) else item.path
        for field in CORE_METADATA_FIELDS:
            val = item.get(field)
            if val is None or val == "" or val == 0:
                missing[field].append({
                    "path": path, "artist": str(item.artist or ""),
                    "album": str(item.album or ""), "title": str(item.title or ""),
                })
    return {k: v for k, v in missing.items() if v}


# =============================================================================
# Phase 5 — Inconsistent albums
# =============================================================================

def check_inconsistent_albums(lib: Library) -> list[dict[str, Any]]:
    warnings: list[dict[str, Any]] = []
    for album in lib.albums():
        items = list(album.items())
        if len(items) < 2:
            continue
        years = {i.year for i in items if i.year}
        if len(years) > 1:
            warnings.append({
                "album": album.album, "albumartist": album.albumartist,
                "issue": "conflicting_years", "years": sorted(years),
                "tracks": [
                    {"title": i.title, "year": i.year,
                     "path": i.path.decode() if isinstance(i.path, bytes) else i.path}
                    for i in items
                ],
            })
        artists = {i.albumartist for i in items if i.albumartist}
        if len(artists) > 1:
            warnings.append({
                "album": album.album, "albumartist": album.albumartist,
                "issue": "conflicting_albumartists", "albumartists": sorted(artists),
            })
    return warnings


# =============================================================================
# Phase 6 — Suspicious numbering
# =============================================================================

def check_suspicious_numbering(lib: Library) -> list[dict[str, Any]]:
    warnings: list[dict[str, Any]] = []
    for album in lib.albums():
        items = list(album.items())
        if len(items) < 2:
            continue
        tracks = sorted(i.track for i in items if i.track)
        if not tracks:
            continue
        expected = list(range(1, len(tracks) + 1))
        if tracks != expected and tracks != list(range(tracks[0], tracks[0] + len(tracks))):
            warnings.append({
                "album": album.album, "albumartist": album.albumartist,
                "issue": "suspicious_track_numbering",
                "tracks_present": tracks, "track_count": len(items), "expected": expected,
            })
        track_counts = Counter(i.track for i in items if i.track)
        dups = {t: c for t, c in track_counts.items() if c > 1}
        if dups:
            warnings.append({
                "album": album.album, "albumartist": album.albumartist,
                "issue": "duplicate_track_numbers", "duplicates": dups,
            })
    return warnings


# =============================================================================
# Phase 7 — Ambiguous matches
# =============================================================================

def find_ambiguous_matches(lib: Library) -> list[dict[str, Any]]:
    ambiguous: list[dict[str, Any]] = []
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
            if len(results) > 1:
                candidates = []
                for r in results[:3]:
                    track_count = len(r.tracks) if r.tracks else 0
                    candidates.append({
                        "artist": r.artist, "album": r.album, "id": r.album_id,
                        "track_count": track_count, "year": r.year,
                        "country": getattr(r, "country", ""),
                        "label": getattr(r, "label", ""),
                        "media": getattr(r, "media", ""),
                    })
                ambiguous.append({
                    "album": album.album, "albumartist": album.albumartist,
                    "candidates": candidates,
                })
        except Exception as exc:
            print(f"  [WARN] MB lookup failed for {album.albumartist} - {album.album}: {exc}",
                  file=sys.stderr)
            continue
    return ambiguous


# =============================================================================
# Phase 8 — High-confidence matches
# =============================================================================

def find_high_confidence_matches(lib: Library) -> list[dict[str, Any]]:
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
                high_conf.append({
                    "album": album.album, "albumartist": album.albumartist,
                    "match": {
                        "artist": r.artist, "album": r.album, "id": r.album_id,
                        "track_count": track_count, "year": r.year,
                        "releasegroup_id": getattr(r, "releasegroup_id", ""),
                    },
                    "proposed_action": (
                        "Assign mb_albumid from this MB release, "
                        "then mbsync to pull in full metadata"
                    ),
                })
        except Exception as exc:
            print(f"  [WARN] MB lookup failed for {album.albumartist} - {album.album}: {exc}",
                  file=sys.stderr)
            continue
    return high_conf


# =============================================================================
# Phase 9 — Existing tags visibility
# =============================================================================

def check_existing_tags_visibility(lib: Library) -> dict[str, Any]:
    genres = Counter()
    moods = Counter()
    for item in lib.items():
        genre = item.get("genre")
        if genre:
            genres[str(genre)] += 1
        mood = item.get("mood")
        if mood:
            moods[str(mood)] += 1
    return {
        "genre_counts": dict(genres.most_common(50)),
        "mood_counts": dict(moods.most_common(50)),
    }


# =============================================================================
# Phase 10a — Reconciliation plan (dry-run)
# =============================================================================

def generate_reconcile_plan(lib: Library, db_path: str, music_dir: str,
                            mode: str, high_conf: list[dict[str, Any]]) -> dict[str, Any]:
    """Preview what reconciliation WOULD do without applying anything."""
    plan: dict[str, Any] = {
        "mbsync_changes": [],
        "mbid_assignments_count": len(high_conf),
        "mbid_assignments": high_conf,
    }
    if mode in ("mbsync", "both"):
        plan["mbsync_changes"] = _run_mbsync_pretend(db_path, music_dir)
        plan["mbsync_albums_affected"] = _count_mbsync_albums(plan["mbsync_changes"])
    return plan


def _run_mbsync_pretend(db_path: str, music_dir: str) -> list[str]:
    try:
        result = subprocess.run(
            ["beet", "-l", db_path, "-d", music_dir, "mbsync", "-p", "-W", "-M"],
            capture_output=True, text=True, timeout=1800,
        )
        lines = [l.strip() for l in result.stdout.splitlines() if l.strip()]
        return lines
    except Exception as exc:
        print(f"  [WARN] mbsync pretend failed: {exc}", file=sys.stderr)
        return [f"mbsync failed: {exc}"]


def _count_mbsync_albums(lines: list[str]) -> int:
    count = 0
    for line in lines:
        if " - " in line and ":" not in line and not line.startswith("mbsync"):
            count += 1
    return count


# =============================================================================
# Phase 10b — Apply reconciliation
# =============================================================================

def apply_reconciliation(lib: Library, db_path: str, music_dir: str,
                         mode: str,
                         high_conf_matches: list[dict[str, Any]],
                         ) -> dict[str, Any]:
    """Apply reconciliation: assign MBIDs then run mbsync. No file moves."""
    result: dict[str, Any] = {
        "mbid_assigned": 0,
        "mbsync_applied": False,
        "mbsync_output": [],
        "errors": [],
    }

    if mode in ("match", "both"):
        for match in high_conf_matches:
            try:
                album = lib.albums(
                    f"albumartist:{match['albumartist']} album:{match['album']}"
                )
                if not album:
                    continue
                album = album[0]
                r = match["match"]
                album.mb_albumid = r["id"]
                if r.get("releasegroup_id"):
                    album.mb_releasegroupid = r["releasegroup_id"]
                album.store()
                result["mbid_assigned"] += 1
            except Exception as exc:
                msg = (f"Failed MBID assign for {match['albumartist']} - "
                       f"{match['album']}: {exc}")
                result["errors"].append(msg)
                print(f"  [WARN] {msg}", file=sys.stderr)

    if mode in ("mbsync", "both"):
        try:
            proc = subprocess.run(
                ["beet", "-l", db_path, "-d", music_dir, "mbsync", "-W", "-M"],
                capture_output=True, text=True, timeout=1800,
            )
            result["mbsync_output"] = (
                [l.strip() for l in proc.stdout.splitlines() if l.strip()]
                if proc.stdout else []
            )
            result["mbsync_applied"] = proc.returncode == 0
            if proc.returncode != 0:
                result["errors"].append(
                    f"mbsync exited {proc.returncode}: {proc.stderr}"
                )
        except Exception as exc:
            result["errors"].append(f"mbsync failed: {exc}")
            print(f"  [WARN] mbsync failed: {exc}", file=sys.stderr)

    return result


# =============================================================================
# Summary generation
# =============================================================================

def generate_summary(report: dict[str, Any]) -> str:
    lines = []
    lines.append("=" * 60)
    lines.append("BEETS LIBRARY AUDIT REPORT")
    lines.append("=" * 60)
    lines.append(f"Run timestamp:  {report['run_timestamp']}")
    lines.append(f"Tool:           beets {report['beets_version']}")
    lines.append(f"Mode:           {report['mode']}")
    lines.append(f"Reconcile mode: {report.get('reconcile_mode', 'both')}")
    lines.append(f"Music directory:{report['music_dir']}")
    lines.append("")

    stats = report["statistics"]
    lines.append("--- LIBRARY STATISTICS ---")
    lines.append(f"Total files:       {stats['total_files']}")
    lines.append(f"Corrupt files:     {stats['corrupt_files']}")
    lines.append(f"Catalogued items:  {stats['catalogued_items']}")
    lines.append(f"Catalogued albums: {stats['catalogued_albums']}")
    lines.append("")

    ids = report["musicbrainz_ids"]
    lines.append("--- MUSICBRAINZ IDs ---")
    for field, paths in sorted(ids.get("missing", {}).items()):
        lines.append(f"  Missing {field}: {len(paths)} items")
    for field, items_ in sorted(ids.get("invalid", {}).items()):
        lines.append(f"  Invalid {field}: {len(items_)} items")
    lines.append("")

    md = report["missing_metadata"]
    lines.append("--- MISSING METADATA ---")
    for field, items_ in sorted(md.items()):
        lines.append(f"  Missing {field}: {len(items_)} items")
    lines.append("")

    for section, label in [
        ("inconsistent_albums", "INCONSISTENT ALBUMS"),
        ("suspicious_numbering", "SUSPICIOUS NUMBERING"),
    ]:
        data = report[section]
        lines.append(f"--- {label}: {len(data)} ---")
        for w in data:
            lines.append(f"  {w['albumartist']} - {w['album']}: {w['issue']}")
        lines.append("")

    am = report["ambiguous_matches"]
    lines.append(f"--- AMBIGUOUS MATCHES (review): {len(am)} ---")
    for a in am:
        lines.append(
            f"  {a['albumartist']} - {a['album']}: "
            f"{len(a['candidates'])} candidates"
        )
    lines.append("")

    hc = report["high_confidence_matches"]
    lines.append(f"--- HIGH-CONFIDENCE MATCHES: {len(hc)} ---")
    for h in hc:
        m = h["match"]
        lines.append(
            f"  {h['albumartist']} - {h['album']} → "
            f"{m['artist']} - {m['album']} ({m['id']})"
        )
    lines.append("")

    # -- Reconciliation plan (dry-run) --
    rp = report.get("reconciliation_plan")
    if rp:
        lines.append("--- RECONCILIATION PLAN (DRY RUN) ---")
        mbsync_count = rp.get("mbsync_albums_affected", 0)
        mbid_count = rp.get("mbid_assignments_count", 0)
        lines.append(f"  mbsync changes:  ~{mbsync_count} albums (refresh from MB)")
        lines.append(f"  MBID assignments:{mbid_count} albums (assign new MBIDs)")
        lines.append("")
        changes = rp.get("mbsync_changes", [])
        if changes:
            lines.append("  mbsync preview (first 30 lines):")
            for line in changes[:30]:
                lines.append(f"    {line}")
            if len(changes) > 30:
                lines.append(f"    ... and {len(changes) - 30} more lines")
        lines.append("")
        lines.append("  These changes would be applied with --apply.")
        lines.append("  No files have been modified.")
        lines.append("")

    # -- Applied reconciliation --
    applied = report.get("reconciliation_result")
    if applied:
        lines.append("--- RECONCILIATION RESULT (APPLIED) ---")
        lines.append(f"  MBIDs assigned: {applied.get('mbid_assigned', 0)}")
        lines.append(f"  mbsync applied: {applied.get('mbsync_applied', False)}")
        for err in applied.get("errors", []):
            lines.append(f"  ERROR: {err}")
        lines.append("")

    cf = stats.get("corrupt_file_details", [])
    if cf:
        lines.append(f"--- CORRUPT/UNREADABLE FILES: {len(cf)} ---")
        for c in cf[:20]:
            lines.append(f"  {c['path']}: {c['reason']}")
        if len(cf) > 20:
            lines.append(f"  ... and {len(cf) - 20} more")
        lines.append("")

    lines.append("--- EXISTING TAGS (visibility only) ---")
    tags = report.get("existing_tags", {})
    if tags.get("genre_counts"):
        lines.append("  Top genres:")
        for genre, count in list(tags["genre_counts"].items())[:10]:
            lines.append(f"    {genre}: {count}")
    if tags.get("mood_counts"):
        lines.append("  Top moods:")
        for mood, count in list(tags["mood_counts"].items())[:10]:
            lines.append(f"    {mood}: {count}")
    lines.append("")

    lines.append("=" * 60)
    lines.append("END OF REPORT")
    return "\n".join(lines)


# =============================================================================
# Main
# =============================================================================

def main() -> None:
    args = parse_args()
    os.makedirs(args.output, exist_ok=True)
    run_ts = datetime.now(timezone.utc).isoformat()

    apply_mode = args.apply

    report: dict[str, Any] = {
        "run_timestamp": run_ts,
        "music_dir": args.music_dir,
        "beets_version": beets.__version__,
        "mode": "apply" if apply_mode else "dry-run",
        "reconcile_mode": args.reconcile_mode,
    }

    print(f"[{run_ts}] Starting beets library audit", file=sys.stderr)
    print(f"  Music dir:      {args.music_dir}", file=sys.stderr)
    print(f"  DB path:        {args.db}", file=sys.stderr)
    print(f"  Mode:           {report['mode']}", file=sys.stderr)
    print(f"  Reconcile mode: {args.reconcile_mode}", file=sys.stderr)

    # --- Phase 1 — Raw scan ---
    print("\n[Phase 1] Scanning files with mutagen...", file=sys.stderr)
    raw = scan_files_raw(args.music_dir)
    report["statistics"] = {
        "total_files": raw["total_files"],
        "corrupt_files": raw["corrupt_files"],
        "corrupt_file_details": raw.get("corrupt_file_details", []),
        "extensions": raw["extensions"],
    }

    # --- Phase 2 — Catalog ---
    print("[Phase 2] Writing beets config...", file=sys.stderr)
    write_beets_config(args.config, args.music_dir, args.db, apply_mode=apply_mode)

    print("[Phase 2] Cataloguing library with beets...", file=sys.stderr)
    lib = init_beets_lib(args.music_dir, args.db)
    cat_items = len(list(lib.items()))
    cat_albums = len(list(lib.albums()))
    report["statistics"]["catalogued_items"] = cat_items
    report["statistics"]["catalogued_albums"] = cat_albums
    print(f"  Catalogued: {cat_items} items, {cat_albums} albums", file=sys.stderr)

    # --- Phases 3-9 — Audit ---
    print("[Phase  3] Checking MusicBrainz IDs...", file=sys.stderr)
    report["musicbrainz_ids"] = check_missing_ids(lib)

    print("[Phase  4] Checking missing metadata...", file=sys.stderr)
    report["missing_metadata"] = check_missing_fields(lib)

    print("[Phase  5] Checking inconsistent albums...", file=sys.stderr)
    report["inconsistent_albums"] = check_inconsistent_albums(lib)

    print("[Phase  6] Checking suspicious numbering...", file=sys.stderr)
    report["suspicious_numbering"] = check_suspicious_numbering(lib)

    print("[Phase  7] Finding ambiguous MB matches...", file=sys.stderr)
    report["ambiguous_matches"] = find_ambiguous_matches(lib)

    print("[Phase  8] Finding high-confidence MB matches...", file=sys.stderr)
    report["high_confidence_matches"] = find_high_confidence_matches(lib)

    print("[Phase  9] Reporting genre/mood tags...", file=sys.stderr)
    report["existing_tags"] = check_existing_tags_visibility(lib)

    # --- Phase 10 — Reconcile plan or apply ---
    if apply_mode:
        print("\n[Phase 10] APPLYING reconciliation...", file=sys.stderr)
        print("  WARNING: This will write tags to audio files!", file=sys.stderr)
        report["reconciliation_result"] = apply_reconciliation(
            lib, args.db, args.music_dir, args.reconcile_mode,
            report["high_confidence_matches"],
        )
    else:
        print("\n[Phase 10] Generating reconciliation plan (dry-run)...", file=sys.stderr)
        report["reconciliation_plan"] = generate_reconcile_plan(
            lib, args.db, args.music_dir, args.reconcile_mode,
            report["high_confidence_matches"],
        )
        print("  Dry-run complete — no files were modified.", file=sys.stderr)

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

    print(generate_summary(report))

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
