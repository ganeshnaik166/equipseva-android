#!/usr/bin/env python3
"""Bulk-import catalog_reference_items via Supabase PostgREST.

Reads /Users/.../Downloads/Hospital_Equipment_Full.csv and POSTs in chunks
of 1000 to /rest/v1/catalog_reference_items. Service-role key required
(read from ~/.equipseva-service-role).

Idempotent: uses Prefer: resolution=merge-duplicates with on_conflict=id
so re-runs upsert. Image columns explicitly cleared to NULL/false.
"""
import csv, json, os, pathlib, sys, time
import requests

SUPABASE_URL = "https://eyswaywvtartpvtoxtdr.supabase.co"
KEY_FILE = pathlib.Path.home() / ".equipseva-service-role"
CSV_PATH = pathlib.Path("/Users/ganeshdhanavath/Downloads/Hospital_Equipment_Full.csv")
CHUNK = 1000

# Read service role key
key = None
for line in KEY_FILE.read_text().splitlines():
    if line.startswith("SUPABASE_SERVICE_ROLE_KEY="):
        key = line.split("=", 1)[1].strip()
        break
if not key:
    print("ERROR: SUPABASE_SERVICE_ROLE_KEY not in", KEY_FILE)
    sys.exit(1)

headers = {
    "apikey": key,
    "Authorization": f"Bearer {key}",
    "Content-Type": "application/json",
    "Prefer": "resolution=merge-duplicates,return=minimal",
}

# Read CSV → list[dict] in PostgREST shape
records = []
with open(CSV_PATH) as f:
    for r in csv.DictReader(f):
        records.append({
            "id": int(r["id"]),
            "source": r["source"] or "curated",
            "udi": r["udi"] or None,
            "category": r["category"],
            "sub_category": r["sub_category"] or None,
            "item_name": r["item_name"],
            "brand": r["brand"] or None,
            "model": r["model"] or None,
            "type": r["type"] or None,
            "key_specifications": r["specifications"] or None,
            "price_inr_low": int(r["price_inr_low"]) if r["price_inr_low"] else None,
            "price_inr_high": int(r["price_inr_high"]) if r["price_inr_high"] else None,
            "market": r["market"] or "India",
            "image_search_url": r["image_search_url"] or None,
            "notes": r["notes"] or None,
            # explicit clear: no images, no review queue
            "image_url": None,
            "image_url_source": None,
            "image_url_confidence": None,
            "needs_image_review": False,
        })

print(f"loaded {len(records)} records from {CSV_PATH}")

endpoint = f"{SUPABASE_URL}/rest/v1/catalog_reference_items?on_conflict=id"
total = len(records)
ok = 0
errors = 0
start = time.time()
for i in range(0, total, CHUNK):
    chunk = records[i:i + CHUNK]
    r = requests.post(endpoint, headers=headers, json=chunk, timeout=120)
    if r.status_code in (200, 201, 204):
        ok += len(chunk)
        elapsed = time.time() - start
        rate = ok / max(elapsed, 0.001)
        eta = (total - ok) / max(rate, 0.001)
        print(f"  [{i//CHUNK+1:>2d}/{(total+CHUNK-1)//CHUNK}]  {ok:>6,d}/{total:,d}  "
              f"rate={rate:.0f}/s  eta={eta:.0f}s")
    else:
        errors += 1
        print(f"  [{i//CHUNK+1:>2d}/{(total+CHUNK-1)//CHUNK}] ERR {r.status_code}: {r.text[:200]}")

print(f"\n[done] inserted={ok}/{total}  errors={errors}  elapsed={time.time()-start:.1f}s")
