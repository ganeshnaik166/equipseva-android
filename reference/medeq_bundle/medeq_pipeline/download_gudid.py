"""
download_gudid.py
-----------------
Downloads the AccessGUDID Delimited Files (full release).

AccessGUDID publishes the entire FDA Global Unique Device Identification
Database as a set of pipe-delimited TXT files inside a ZIP, refreshed daily
at: https://accessgudid.nlm.nih.gov/download/delimited

Usage:
    python download_gudid.py [--out OUT_DIR]

The download is large (~3-5 GB compressed, ~25 GB uncompressed). You only
need to run this ONCE on your machine; subsequent SQLite builds reuse the
extracted TXT files.

Tested on macOS, Linux, Windows (Python 3.10+). No third-party deps.
"""
from __future__ import annotations

import argparse
import hashlib
import os
import shutil
import sys
import zipfile
from pathlib import Path
from urllib.request import Request, urlopen

DELIMITED_URL = "https://accessgudid.nlm.nih.gov/download/delimited"
DEFAULT_OUT = Path(__file__).parent / "gudid_raw"
CHUNK = 1024 * 1024  # 1 MiB


def human(n: int) -> str:
    for unit in ("B", "KB", "MB", "GB", "TB"):
        if n < 1024:
            return f"{n:,.1f} {unit}"
        n /= 1024
    return f"{n:,.1f} PB"


def download(url: str, dest: Path) -> Path:
    dest.parent.mkdir(parents=True, exist_ok=True)
    req = Request(url, headers={"User-Agent": "medeq-importer/1.0"})
    print(f"GET {url}")
    with urlopen(req) as resp:
        total = int(resp.headers.get("Content-Length", 0))
        print(f"  size: {human(total) if total else 'unknown'}")
        tmp = dest.with_suffix(dest.suffix + ".part")
        sha = hashlib.sha256()
        seen = 0
        with open(tmp, "wb") as out:
            while True:
                chunk = resp.read(CHUNK)
                if not chunk:
                    break
                out.write(chunk)
                sha.update(chunk)
                seen += len(chunk)
                if total:
                    pct = seen * 100 / total
                    sys.stdout.write(f"\r  {human(seen)} / {human(total)} ({pct:5.1f}%)")
                else:
                    sys.stdout.write(f"\r  {human(seen)}")
                sys.stdout.flush()
        sys.stdout.write("\n")
    tmp.replace(dest)
    print(f"  sha256: {sha.hexdigest()}")
    return dest


def extract(zip_path: Path, out_dir: Path) -> None:
    print(f"Extracting {zip_path.name} -> {out_dir}")
    out_dir.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(zip_path) as z:
        members = z.infolist()
        for i, m in enumerate(members, 1):
            sys.stdout.write(f"\r  [{i}/{len(members)}] {m.filename}  ")
            sys.stdout.flush()
            z.extract(m, out_dir)
        sys.stdout.write("\n")


def main():
    ap = argparse.ArgumentParser(description="Download + extract AccessGUDID delimited dump.")
    ap.add_argument("--out", type=Path, default=DEFAULT_OUT, help="Output directory")
    ap.add_argument("--keep-zip", action="store_true", help="Keep the .zip after extracting")
    args = ap.parse_args()

    args.out.mkdir(parents=True, exist_ok=True)
    zip_path = args.out / "gudid_delimited.zip"

    if zip_path.exists():
        print(f"Already downloaded: {zip_path} ({human(zip_path.stat().st_size)})")
    else:
        download(DELIMITED_URL, zip_path)

    extract(zip_path, args.out)

    if not args.keep_zip:
        zip_path.unlink(missing_ok=True)
        print("Removed zip (use --keep-zip to retain).")

    print("\nDone. Next: python build_sqlite.py --raw", args.out, "--out equipment.db")


if __name__ == "__main__":
    main()
