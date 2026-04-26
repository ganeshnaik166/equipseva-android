"""
build_sqlite.py
---------------
Normalises the AccessGUDID delimited dump into a single SQLite database
that is ready to ship inside an Android APK as a Room prepackaged DB.

Schema (matches the Kotlin EquipmentEntity 1:1):

  equipment(
    id INTEGER PRIMARY KEY,
    source TEXT,                -- 'gudid' | 'curated'
    udi TEXT,                   -- primaryDi for gudid
    item_name TEXT,             -- brandName / deviceDescription
    brand TEXT,                 -- companyName
    model TEXT,                 -- versionModelNumber
    category TEXT,              -- mapped from gmdnPTName
    sub_category TEXT,
    type TEXT,                  -- 'Capital Equipment' | 'Consumable' | ...
    specifications TEXT,        -- short spec sentence
    price_inr_low INTEGER,
    price_inr_high INTEGER,
    market TEXT,                -- 'India' for curated, 'Global' for gudid
    image_search_url TEXT,
    notes TEXT
  )

Plus a contentless FTS5 table `equipment_fts` over (item_name, brand, model,
specifications, category) for fast prefix/typo-tolerant search.

Usage:
    python build_sqlite.py --raw ./gudid_raw \\
                           --curated ./Hospital_Equipment_Catalogue.json \\
                           --out equipment.db \\
                           [--limit 0]   (0 = all)

Memory: streams TXT files row by row; ~250-400 MB peak RAM.
Output: ~80-180 MB SQLite (after VACUUM).

The raw GUDID files are pipe-delimited with a header. The two we use:
  device.txt           - core records (PRIMARY_DI, BRAND_NAME, COMPANY_NAME, ...)
  gmdnTerms.txt        - GMDN code+term linked to PRIMARY_DI
"""
from __future__ import annotations

import argparse
import csv
import json
import sqlite3
import sys
import urllib.parse
from pathlib import Path

# Bump csv field-size limit; some GUDID descriptions are long.
csv.field_size_limit(2_000_000)

# ---------- GMDN -> our category mapping ----------
# AccessGUDID has ~28k GMDN preferred terms. We don't enumerate them all —
# we use keyword rules to bucket each device into one of our 6 categories.
# The mapping is intentionally coarse; users can refine later.
CATEGORY_RULES = [
    ("Imaging", [
        "mri", "magnetic resonance", "ct ", "computed tomography", "x-ray", "xray",
        "radiograph", "fluoroscopy", "mammograph", "ultrasound", "echocardiograph",
        "doppler", "pet/ct", "pet-ct", "spect", "gamma camera", "bone densitomet",
        "angiograph", "cath lab", "optical coherence", "fundus", "ivus",
    ]),
    ("ICU & Critical Care", [
        "ventilator", "anaesthesi", "anesthesi", "respirator", "cpap", "bipap",
        "patient monitor", "multi-parameter", "multi parameter", "pulse oxim",
        "defibrill", "infusion pump", "syringe pump", "dialysis", "hemodialysis",
        "ecmo", "iabp", "blood gas", "capnograph", "haemofiltration",
    ]),
    ("Surgical & OR", [
        "surgical", "operating", "anaesthetic gas", "electrosurg", "diathermy",
        "vessel sealing", "harmonic", "laparoscop", "endoscop", "gastroscop",
        "colonoscop", "bronchoscop", "cystoscop", "hysteroscop", "robotic",
        "operating microscope", "phaco", "vitrectom", "bone drill", "saw",
        "stapler", "suture", "scalpel", "trocar", "autoclave", "steriliser",
        "sterilizer",
    ]),
    ("Laboratory", [
        "haematolog", "hematolog", "biochem", "chemistry analyz", "immunoassay",
        "elisa", "pcr", "thermocycler", "thermal cycler", "cytomet", "centrifug",
        "microscope", "tissue processor", "microtome", "cryostat", "incubator",
        "biosafety", "fume hood", "spectrophotomet", "balance, analyt", "ph meter",
    ]),
    ("Ward & Allied", [
        "hospital bed", "bed, hospital", "wheelchair", "stretcher", "trolley",
        "iv stand", "examination", "stethoscop", "sphygmomanomet", "blood pressure",
        "thermomet", "ecg ", "electrocardiograph", "spiromet", "nebuliz",
        "phototherap", "incubator, neonat", "radiant warmer", "fetal", "ctg",
        "dental chair", "audiomet", "tympanomet", "slit lamp", "auto-refractomet",
        "tonomet",
    ]),
    ("Spare Parts & Consumables", [
        "sensor", "probe", "cable", "cuff", "lead wire", "electrode", "circuit",
        "filter", "accessory", "battery", "lamp, bulb", "transducer", "tube,",
        "syringe,", "needle", "catheter", "cannula", "drape", "gown", "mask",
        "glove",
    ]),
]

DEFAULT_CATEGORY = "Spare Parts & Consumables"


def map_category(gmdn_term: str, brand: str, item: str) -> str:
    blob = f"{gmdn_term} {brand} {item}".lower()
    for cat, kws in CATEGORY_RULES:
        if any(k in blob for k in kws):
            return cat
    return DEFAULT_CATEGORY


def map_type(gmdn_term: str) -> str:
    g = (gmdn_term or "").lower()
    if any(k in g for k in ("single-use", "single use", "disposable")):
        return "Consumable"
    if any(k in g for k in ("accessory", "adapter", "cable", "battery", "filter", "sensor")):
        return "Spare/Accessory"
    return "Capital Equipment"


def image_search_url(brand: str, model: str, item: str) -> str:
    return "https://www.google.com/search?tbm=isch&q=" + urllib.parse.quote_plus(
        " ".join(s for s in (brand, model, item) if s).strip()
    )


SCHEMA = """
PRAGMA synchronous = OFF;
PRAGMA temp_store = MEMORY;
PRAGMA cache_size = -200000;       -- 200 MiB
PRAGMA journal_mode = MEMORY;

CREATE TABLE IF NOT EXISTS equipment (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    source          TEXT NOT NULL,
    udi             TEXT,
    item_name       TEXT NOT NULL,
    brand           TEXT,
    model           TEXT,
    category        TEXT NOT NULL,
    sub_category    TEXT,
    type            TEXT,
    specifications  TEXT,
    price_inr_low   INTEGER,
    price_inr_high  INTEGER,
    market          TEXT,
    image_search_url TEXT,
    notes           TEXT
);

CREATE INDEX IF NOT EXISTS idx_equipment_category ON equipment(category);
CREATE INDEX IF NOT EXISTS idx_equipment_brand    ON equipment(brand);
CREATE INDEX IF NOT EXISTS idx_equipment_source   ON equipment(source);

CREATE VIRTUAL TABLE IF NOT EXISTS equipment_fts USING fts5(
    item_name, brand, model, specifications, category,
    content='equipment', content_rowid='id',
    tokenize='unicode61 remove_diacritics 2'
);

CREATE TRIGGER IF NOT EXISTS equipment_ai AFTER INSERT ON equipment BEGIN
    INSERT INTO equipment_fts(rowid, item_name, brand, model, specifications, category)
    VALUES (new.id, new.item_name, new.brand, new.model, new.specifications, new.category);
END;
CREATE TRIGGER IF NOT EXISTS equipment_ad AFTER DELETE ON equipment BEGIN
    INSERT INTO equipment_fts(equipment_fts, rowid, item_name, brand, model, specifications, category)
    VALUES('delete', old.id, old.item_name, old.brand, old.model, old.specifications, old.category);
END;
CREATE TRIGGER IF NOT EXISTS equipment_au AFTER UPDATE ON equipment BEGIN
    INSERT INTO equipment_fts(equipment_fts, rowid, item_name, brand, model, specifications, category)
    VALUES('delete', old.id, old.item_name, old.brand, old.model, old.specifications, old.category);
    INSERT INTO equipment_fts(rowid, item_name, brand, model, specifications, category)
    VALUES (new.id, new.item_name, new.brand, new.model, new.specifications, new.category);
END;
"""


def open_db(path: Path) -> sqlite3.Connection:
    if path.exists():
        path.unlink()
    conn = sqlite3.connect(path)
    conn.executescript(SCHEMA)
    return conn


def insert_curated(conn: sqlite3.Connection, curated_json: Path) -> int:
    if not curated_json.exists():
        print(f"  (no curated file at {curated_json}, skipping)")
        return 0
    payload = json.loads(curated_json.read_text(encoding="utf-8"))
    rows = payload["items"]
    cur = conn.executemany(
        """INSERT INTO equipment
           (source, udi, item_name, brand, model, category, sub_category,
            type, specifications, price_inr_low, price_inr_high, market,
            image_search_url, notes)
           VALUES ('curated', NULL, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'India', ?, ?)""",
        [
            (
                r["itemName"], r["brand"], r["model"], r["category"], r["subCategory"],
                r["type"], r["specifications"], r["priceInrLow"], r["priceInrHigh"],
                r["imageSearchUrl"], r.get("notes", ""),
            )
            for r in rows
        ],
    )
    return len(rows)


def stream_gudid(raw_dir: Path):
    """Yield dicts from device.txt joined with the latest gmdnTerms entry."""
    device_file = raw_dir / "device.txt"
    gmdn_file = raw_dir / "gmdnTerms.txt"
    if not device_file.exists():
        sys.exit(f"Missing {device_file}. Run download_gudid.py first.")

    # Pre-load gmdn into a dict (it's small enough; ~3M rows ~ 200MB RAM).
    gmdn_by_di: dict[str, str] = {}
    if gmdn_file.exists():
        print(f"  loading gmdnTerms.txt ...")
        with open(gmdn_file, "r", encoding="utf-8", errors="replace", newline="") as f:
            r = csv.DictReader(f, delimiter="|")
            for row in r:
                di = row.get("PRIMARY_DI") or row.get("primaryDi")
                term = row.get("GMDN_PT_NAME") or row.get("gmdnPTName")
                if di and term and di not in gmdn_by_di:
                    gmdn_by_di[di] = term
        print(f"    {len(gmdn_by_di):,} gmdn terms")

    with open(device_file, "r", encoding="utf-8", errors="replace", newline="") as f:
        r = csv.DictReader(f, delimiter="|")
        for row in r:
            yield row, gmdn_by_di.get(row.get("PRIMARY_DI", ""), "")


def insert_gudid(conn: sqlite3.Connection, raw_dir: Path, limit: int = 0) -> int:
    print(f"Importing GUDID from {raw_dir} ...")
    cur = conn.cursor()
    batch = []
    n = 0
    skipped = 0
    BATCH = 5000
    for row, gmdn_term in stream_gudid(raw_dir):
        if limit and n >= limit:
            break

        # Skip records with no usable identification
        brand = (row.get("BRAND_NAME") or "").strip()
        item = (row.get("DEVICE_DESCRIPTION") or row.get("CATALOG_NUMBER") or brand).strip()
        if not item or not brand:
            skipped += 1
            continue
        # Skip clearly-not-medical-equipment
        if (row.get("DEVICE_RECORD_STATUS") or "").lower() not in ("published", ""):
            skipped += 1
            continue

        primary_di   = row.get("PRIMARY_DI") or ""
        company      = row.get("COMPANY_NAME") or brand
        model        = row.get("VERSION_MODEL_NUMBER") or row.get("CATALOG_NUMBER") or ""
        category     = map_category(gmdn_term, brand, item)
        sub_category = gmdn_term or ""
        device_type  = map_type(gmdn_term)
        specs_bits   = []
        if gmdn_term:
            specs_bits.append(gmdn_term)
        if row.get("DEVICE_COUNT_IN_BASE_PACKAGE"):
            specs_bits.append(f"{row['DEVICE_COUNT_IN_BASE_PACKAGE']} per package")
        if row.get("MRI_SAFETY"):
            specs_bits.append(f"MRI: {row['MRI_SAFETY']}")
        specifications = " · ".join(specs_bits)
        notes_bits = []
        if row.get("DEVICE_PUBLISH_DATE"):
            notes_bits.append(f"Published {row['DEVICE_PUBLISH_DATE']}")
        if (row.get("RX") or "").lower() == "true":
            notes_bits.append("Rx (prescription) device")
        if (row.get("OTC") or "").lower() == "true":
            notes_bits.append("OTC")
        notes = " · ".join(notes_bits)

        batch.append((
            "gudid", primary_di, item, company, model, category, sub_category,
            device_type, specifications, None, None, "Global",
            image_search_url(company, model, item), notes,
        ))

        if len(batch) >= BATCH:
            cur.executemany(
                """INSERT INTO equipment
                   (source, udi, item_name, brand, model, category, sub_category,
                    type, specifications, price_inr_low, price_inr_high, market,
                    image_search_url, notes)
                   VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
                batch,
            )
            n += len(batch)
            batch.clear()
            if n % 50_000 == 0:
                conn.commit()
                sys.stdout.write(f"\r  {n:,} rows imported  ")
                sys.stdout.flush()
    if batch:
        cur.executemany(
            """INSERT INTO equipment
               (source, udi, item_name, brand, model, category, sub_category,
                type, specifications, price_inr_low, price_inr_high, market,
                image_search_url, notes)
               VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
            batch,
        )
        n += len(batch)
    conn.commit()
    print(f"\n  imported {n:,} GUDID rows  (skipped {skipped:,})")
    return n


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--raw", type=Path, default=Path("./gudid_raw"),
                    help="Directory containing device.txt + gmdnTerms.txt")
    ap.add_argument("--curated", type=Path,
                    default=Path("../Hospital_Equipment_Catalogue.json"),
                    help="Curated India-priced JSON to merge first")
    ap.add_argument("--out", type=Path, default=Path("equipment.db"))
    ap.add_argument("--limit", type=int, default=0,
                    help="Cap GUDID rows (0 = all). Useful for testing.")
    ap.add_argument("--no-vacuum", action="store_true",
                    help="Skip final VACUUM (faster, ~30%% larger file)")
    args = ap.parse_args()

    print(f"Building {args.out} ...")
    conn = open_db(args.out)

    print("Inserting curated India-priced rows ...")
    cur_n = insert_curated(conn, args.curated)
    print(f"  {cur_n} curated rows")

    g_n = insert_gudid(conn, args.raw, limit=args.limit)

    print("Rebuilding FTS index ...")
    conn.execute("INSERT INTO equipment_fts(equipment_fts) VALUES('rebuild');")
    conn.commit()

    if not args.no_vacuum:
        print("VACUUM (this may take a few minutes) ...")
        try:
            conn.execute("VACUUM;")
        except sqlite3.OperationalError as e:
            print(f"  VACUUM skipped: {e}")

    conn.close()
    size_mb = args.out.stat().st_size / (1024 * 1024)
    print(f"\nDone.  {args.out}  ({size_mb:.1f} MB,  {cur_n + g_n:,} rows)")


if __name__ == "__main__":
    main()
