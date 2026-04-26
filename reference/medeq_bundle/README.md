# medeq bundle (reference material)

User-supplied reference architecture for an offline-first hospital-equipment
catalogue Android app. Not part of the EquipSeva build — kept here as a design
reference and as the source for the curated 536-item India catalogue + the
12 sample GUDID rows that were ingested into Supabase
(`public.catalog_reference_items`) by migration
`supabase/migrations/20260427050000_catalog_reference_items_full_reseed.sql`.

## Layout

- `medeq_android/` — standalone Compose + Room sample app showing local-first
  search with FTS5 over a bundled SQLite, plus OpenFDA fallback. Useful as a
  reference for:
  - `data/local/AppDatabase.kt` — `createFromAsset` pattern + FTS query
    sanitiser (`toFtsQuery`).
  - `data/repository/EquipmentRepository.kt` — local-first / remote-fallback
    pattern, threshold-driven (`LOCAL_FALLBACK_THRESHOLD = 10`).
  - `data/remote/OpenFdaApi.kt` + `OpenFdaModels.kt` — Retrofit + Moshi DTOs
    for the OpenFDA UDI endpoint.
  - `app/src/main/assets/equipment.db` — 548-row sample SQLite with FTS5
    index. The 536 curated rows are a strict subset of our Supabase data.

- `medeq_pipeline/` — Python pipeline that builds the bundled SQLite:
  - `download_gudid.py` — fetches AccessGUDID delimited dump (~3-5 GB zip).
  - `build_sqlite.py` — joins curated JSON + GUDID into a single table with
    a unified schema and FTS5 index.
  - `_make_sample.py` — emits a tiny GUDID-shaped sample for local testing
    without downloading the full dump.

## Why this is here, not wired into the main app

EquipSeva is Supabase-backed end-to-end (RLS, Realtime, Storage). Adopting the
bundled-SQLite approach would split the source of truth between the device and
the server. We took the data ingestion side (curated JSON → Supabase table)
and skipped the offline-cache architecture. If we ever need offline-first
device search, this bundle is the starting point.
