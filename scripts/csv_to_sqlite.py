#!/usr/bin/env python3
"""csv_to_sqlite.py — turn the 5M-row Hospital_Equipment_Full.csv(.gz) into
a self-contained SQLite database with an FTS5 search index, ready to ship
inside the Android APK as a Room/AppDatabase prepackaged asset.

Output schema (matches the medeq_bundle reference EquipmentEntity 1:1 so
we can reuse the existing Compose+Room search code from
`reference/medeq_bundle/medeq_android/...`):

  equipment(
    id INTEGER PRIMARY KEY,
    source TEXT NOT NULL,
    udi TEXT,
    item_name TEXT NOT NULL,
    brand TEXT,
    model TEXT,
    category TEXT NOT NULL,
    sub_category TEXT,
    type TEXT,
    specifications TEXT,
    price_inr_low INTEGER,
    price_inr_high INTEGER,
    market TEXT NOT NULL,
    image_search_url TEXT,
    notes TEXT
  )

Plus contentless FTS5 over (item_name, brand, model, specifications,
sub_category, category). Triggers keep the FTS in sync if rows are
inserted/updated/deleted.

Memory: streams the CSV row by row, single transaction commit at the
end. Peak RAM ~80 MB regardless of input size.

Usage:
  python3 scripts/csv_to_sqlite.py \
      --csv data/Hospital_Equipment_Full.csv.gz \
      --out app/src/main/assets/equipment.db \
      [--limit 0]   # 0 = all rows
"""
from __future__ import annotations

import argparse
import csv
import gzip
import pathlib
import sqlite3
import time
from contextlib import contextmanager


SCHEMA = """
DROP TABLE IF EXISTS equipment_fts;
DROP TABLE IF EXISTS equipment;

-- Trimmed schema for the bundled-in-APK SQLite. We dropped image_search_url
-- (computable on-device from brand+model+item_name as a Google Images URL —
-- 620 MB saved across 5M rows) and `notes` (low-value FDA publication dates,
-- 85 MB saved). UDI is kept because it's how we cross-reference back to
-- OpenFDA for live-fallback queries.
CREATE TABLE equipment (
    id INTEGER PRIMARY KEY,
    source TEXT NOT NULL,
    udi TEXT,
    item_name TEXT NOT NULL,
    brand TEXT,
    model TEXT,
    category TEXT NOT NULL,
    sub_category TEXT,
    type TEXT,
    specifications TEXT,
    price_inr_low INTEGER,
    price_inr_high INTEGER,
    market TEXT NOT NULL DEFAULT 'India'
);

-- Hot indexes the Compose UI uses: filter chips on category + type, plus
-- udi lookup for cross-reference.
CREATE INDEX equipment_category_idx     ON equipment(category);
CREATE INDEX equipment_type_idx         ON equipment(type);
CREATE INDEX equipment_brand_lower_idx  ON equipment(LOWER(brand));
CREATE INDEX equipment_udi_idx          ON equipment(udi) WHERE udi IS NOT NULL;

-- FTS5 for search-as-you-type. Contentless so we don't double-store text;
-- triggers below mirror the source table.
CREATE VIRTUAL TABLE equipment_fts USING fts5(
    item_name,
    brand,
    model,
    specifications,
    sub_category,
    category,
    content='equipment',
    content_rowid='id',
    tokenize='unicode61 remove_diacritics 1'
);

-- Sync triggers (insert/update/delete on `equipment` mirror into FTS).
CREATE TRIGGER equipment_ai AFTER INSERT ON equipment BEGIN
    INSERT INTO equipment_fts(rowid, item_name, brand, model, specifications, sub_category, category)
    VALUES (new.id, new.item_name, new.brand, new.model, new.specifications, new.sub_category, new.category);
END;
CREATE TRIGGER equipment_ad AFTER DELETE ON equipment BEGIN
    INSERT INTO equipment_fts(equipment_fts, rowid, item_name, brand, model, specifications, sub_category, category)
    VALUES('delete', old.id, old.item_name, old.brand, old.model, old.specifications, old.sub_category, old.category);
END;
CREATE TRIGGER equipment_au AFTER UPDATE ON equipment BEGIN
    INSERT INTO equipment_fts(equipment_fts, rowid, item_name, brand, model, specifications, sub_category, category)
    VALUES('delete', old.id, old.item_name, old.brand, old.model, old.specifications, old.sub_category, old.category);
    INSERT INTO equipment_fts(rowid, item_name, brand, model, specifications, sub_category, category)
    VALUES (new.id, new.item_name, new.brand, new.model, new.specifications, new.sub_category, new.category);
END;
"""


@contextmanager
def open_csv(path: pathlib.Path):
    if path.suffix == ".gz":
        with gzip.open(path, "rt", encoding="utf-8", errors="replace") as f:
            yield f
    else:
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            yield f


def to_int(s: str | None) -> int | None:
    if not s:
        return None
    try:
        return int(s)
    except ValueError:
        return None


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--csv", required=True, type=pathlib.Path)
    ap.add_argument("--out", required=True, type=pathlib.Path)
    ap.add_argument("--limit", type=int, default=0,
                    help="0 = all rows; otherwise stop after N")
    ap.add_argument("--no-vacuum", action="store_true",
                    help="skip the final VACUUM (saves ~30s but bigger file)")
    args = ap.parse_args()

    if args.out.exists():
        args.out.unlink()
    args.out.parent.mkdir(parents=True, exist_ok=True)

    print(f"[build] csv = {args.csv}  ({args.csv.stat().st_size/1024/1024:.1f} MB)")
    print(f"[build] out = {args.out}")
    db = sqlite3.connect(args.out)
    db.executescript("PRAGMA journal_mode = OFF; PRAGMA synchronous = OFF;")
    db.executescript(SCHEMA)

    insert = (
        "INSERT INTO equipment "
        "(id, source, udi, item_name, brand, model, category, sub_category, "
        " type, specifications, price_inr_low, price_inr_high, market) "
        "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
    )

    start = time.time()
    inserted = 0
    skipped = 0
    BATCH = 5000
    pending: list[tuple] = []
    db.execute("BEGIN")

    with open_csv(args.csv) as f:
        reader = csv.DictReader(f)
        for r in reader:
            rid = to_int(r.get("id"))
            if rid is None or not (r.get("item_name") and r.get("category")):
                skipped += 1
                continue
            pending.append((
                rid,
                r.get("source") or "curated",
                r.get("udi") or None,
                r["item_name"],
                r.get("brand") or None,
                r.get("model") or None,
                r["category"],
                r.get("sub_category") or None,
                r.get("type") or None,
                r.get("specifications") or None,
                to_int(r.get("price_inr_low")),
                to_int(r.get("price_inr_high")),
                r.get("market") or "India",
            ))
            if len(pending) >= BATCH:
                db.executemany(insert, pending)
                inserted += len(pending)
                pending.clear()
                if inserted % 100_000 == 0:
                    elapsed = time.time() - start
                    rate = inserted / max(elapsed, 0.001)
                    print(f"  [{inserted:>9,d}]  rate={rate:>7,.0f}/s  "
                          f"elapsed={elapsed/60:.1f}m")
            if args.limit and inserted + len(pending) >= args.limit:
                break

    if pending:
        db.executemany(insert, pending)
        inserted += len(pending)
        pending.clear()
    db.commit()

    print(f"[build] inserted={inserted:,}  skipped={skipped:,}  "
          f"elapsed={(time.time()-start)/60:.1f}m")

    print("[build] ANALYZE …")
    db.execute("ANALYZE")
    db.commit()

    if not args.no_vacuum:
        print("[build] VACUUM …")
        db.execute("VACUUM")
        db.commit()

    db.close()
    size_mb = args.out.stat().st_size / 1024 / 1024
    print(f"[build] DONE  size={size_mb:.1f} MB  rows={inserted:,}")

    # Quick smoke query
    db = sqlite3.connect(args.out)
    n = db.execute("SELECT count(*) FROM equipment").fetchone()[0]
    nf = db.execute("SELECT count(*) FROM equipment_fts").fetchone()[0]
    print(f"[smoke] equipment={n:,}  equipment_fts={nf:,}")
    sample = db.execute(
        "SELECT id, item_name, brand FROM equipment WHERE id = 1"
    ).fetchone()
    print(f"[smoke] id=1 → {sample}")
    fts = db.execute(
        "SELECT count(*) FROM equipment_fts WHERE equipment_fts MATCH 'mri'"
    ).fetchone()[0]
    print(f"[smoke] FTS 'mri' hits={fts:,}")
    db.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
