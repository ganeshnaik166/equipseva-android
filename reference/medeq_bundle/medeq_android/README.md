# Hospital Equipment Catalogue – Android App

A Kotlin/Compose app that ships a SQLite catalogue of medical devices inside
the APK, searches it offline with FTS5, and falls back to the OpenFDA UDI API
for anything not found locally.

```
                                     ┌──────────────────────┐
   user types ──► SearchViewModel ──►│ EquipmentRepository  │
                                     └──────────┬───────────┘
                                                │ 1) FTS query
                                                ▼
                                     ┌──────────────────────┐
                                     │ Room (equipment.db)  │  ← bundled in /assets
                                     │  • 536 curated INR   │
                                     │  • ~3-4M GUDID rows  │
                                     │  • FTS5 index        │
                                     └──────────┬───────────┘
                                                │ < 10 hits?
                                                ▼ 2) network
                                     ┌──────────────────────┐
                                     │ OpenFDA /device/udi  │
                                     └──────────────────────┘
```

## What's in this folder

```
medeq_android/
  app/
    build.gradle.kts                        — Room, Retrofit, Compose, Paging
    src/main/AndroidManifest.xml
    src/main/assets/
      equipment.db                          ← drop the file built by build_sqlite.py here
    src/main/java/com/medeq/app/
      MainActivity.kt
      domain/Equipment.kt                   — UI-facing model + INR formatter
      data/local/
        EquipmentEntity.kt                  — Room entity matching the SQLite schema
        EquipmentDao.kt                     — FTS-backed search, byCategory, paging source
        AppDatabase.kt                      — createFromAsset, FTS query sanitiser
      data/remote/
        OpenFdaApi.kt                       — Retrofit interface for /device/udi.json
        OpenFdaModels.kt                    — Moshi DTOs
        NetworkModule.kt                    — OkHttp + cache + Moshi
      data/repository/
        EquipmentRepository.kt              — local-first, OpenFDA fallback, caches results
      ui/search/
        SearchViewModel.kt                  — debounced query → SearchState flow
        SearchViewModelFactory.kt           — no-Hilt factory (swap in DI as you like)
        SearchScreen.kt                     — Compose UI, taps row → opens image search
```

The matching data pipeline lives in `../medeq_pipeline/`:

```
medeq_pipeline/
  download_gudid.py        — pulls the AccessGUDID delimited dump (~3-5 GB zip)
  build_sqlite.py          — normalises GUDID + curated JSON into equipment.db
  _make_sample.py          — generates a tiny GUDID-shaped sample for local testing
  gudid_raw_sample/        — sample TXTs (12 rows) so you can build without downloading
```

## End-to-end build

### 1.  Build the SQLite catalogue once on your dev machine

```bash
cd medeq_pipeline

# (a) Dry-run with the sample data to confirm the pipeline runs (~1 second):
python build_sqlite.py \
    --raw     ./gudid_raw_sample \
    --curated ../Hospital_Equipment_Catalogue.json \
    --out     equipment.db \
    --no-vacuum
# → ~280 KB DB, 548 rows.

# (b) When you're happy, pull the real GUDID dump (one-time, ~30-60 min on a
#     fast connection; the script is resumable):
python download_gudid.py --out ./gudid_raw

# (c) Build the production DB (10-20 min depending on machine):
python build_sqlite.py \
    --raw     ./gudid_raw \
    --curated ../Hospital_Equipment_Catalogue.json \
    --out     equipment.db
# Expect ~80-180 MB, 3-4 million rows.
# Use --limit 200000 first if you want a 'top brands only' build.
```

### 2.  Drop the result into the Android project

```bash
cp equipment.db ../medeq_android/app/src/main/assets/equipment.db
```

`AppDatabase.createFromAsset("equipment.db")` copies it on first launch.

### 3.  Open in Android Studio

1. Open `medeq_android/` as the project root.
2. Let Gradle sync. (KSP + Room compiler is fastest with JDK 17.)
3. Run on an emulator / device. The first launch is slightly slower (Room
   copies the bundled DB into `/data/data/com.medeq.app/databases/`); after
   that it's instant.

## What the search does

Type at least 2 chars → `SearchViewModel` debounces 250 ms → `EquipmentRepository.search()`:

1. **Local FTS.** `AppDatabase.toFtsQuery()` strips FTS operators and adds prefix
   wildcards: `"mind ven"` becomes `mind* ven*`, joined as AND. Row source
   ordering is `curated → gudid → remote`, then BM25 relevance.
2. If fewer than `LOCAL_FALLBACK_THRESHOLD = 10` hits, we hit OpenFDA with
   `(brand_name:t OR device_description:t OR company_name:t)` per token.
3. Remote rows are mapped through the same category rules as the Python
   importer, written to Room with `source = 'remote'`, and the merged result
   is re-read from the DB.

Tap a row → opens a Google Images search for `brand model item` in the
device's browser. We don't bundle images; copyright is the user's problem
on click rather than the developer's at build time.

## Updating the catalogue

You ship a new APK with a fresh `equipment.db`. Bump `@Database(version = N+1)`
in `AppDatabase.kt` so Room destroys the old copied DB on update.

For incremental updates without an APK release, write a `WorkManager` worker
that calls `repository.refreshFromOpenFda(category)` periodically — the
`upsertAll` path in the repo already handles it.

## Known limitations / honest caveats

- **Categories are coarse.** GUDID's GMDN terms map onto our 6 buckets via
  keyword rules in `build_sqlite.py` and `EquipmentRepository.kt`. Refine the
  `CATEGORY_RULES` list if you need finer breakdown.
- **No INR prices on GUDID rows.** They show up as price-unknown in the UI.
  Only the 536 curated rows have low/high INR.
- **OpenFDA rate limit:** 240 req/min, 1000/day per IP without a key. Get a
  free key (https://open.fda.gov/apis/authentication/) and pass it via the
  `openFdaApiKey` constructor argument when you exceed that.
- **GUDID is US-centric.** Most major OEMs sold in India (Philips, GE,
  Siemens, Mindray, Drager, Medtronic, BD, Roche…) are in there, but local
  Indian manufacturers (BPL, Allengers, Phoenix, Atom, Yorco etc.) are
  thinly represented unless they also sell in the US.
- **DB size vs APK size.** Google Play Asset Delivery has a 200 MB install-time
  limit but allows large on-demand asset packs. If your equipment.db exceeds
  ~150 MB, move it to a Play Asset Pack and lazy-extract on first launch.
- **Schema validation.** Room requires the bundled DB's column types to match
  exactly. `build_sqlite.py` mirrors `EquipmentEntity`; if you change one,
  change both.

## Troubleshooting

- `Pre-packaged database has an invalid schema` → the column types in
  `EquipmentEntity` drifted from `build_sqlite.py`. Rebuild equipment.db.
- `no such table: equipment_fts` → the `@Fts4(contentEntity = …)` annotation
  must reference `EquipmentEntity::class` exactly. Already wired in this code.
- `disk I/O error` while running `build_sqlite.py` on macOS sandboxed paths →
  point `--out` to a regular directory (`/tmp/equipment.db` works).

## Licences

- **AccessGUDID** data is in the public domain (US FDA).
- **OpenFDA** data is public; respect the rate limit and credit "openFDA".
- The `Hospital_Equipment_Catalogue.json` curated file is yours to ship.
