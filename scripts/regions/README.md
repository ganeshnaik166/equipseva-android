# Region catalogue snapshots

`build_region_catalog.mjs` turns one reviewed snapshot of India's States/UTs and districts into:

- the Android asset `app/src/main/assets/regions/india_regions.json`;
- a seed migration for the round3830 `region_*` tables.

Records persist stable codes plus the catalogue version (PRODUCT_PLAN §6, ledger P2.2). The script needs only Node 24 and has no dependencies. On the founder's laptop, run it with `ELECTRON_RUN_AS_NODE=1 "<VS Code>/Code.exe"`.

## Until a real snapshot is approved

No catalogue is bundled and no seed migration exists. The app keeps its existing label-based State/district flow, and the server refuses every coded write with `region_catalog_version_unsupported`.

`fixtures/synthetic-v1` and `fixtures/synthetic-v2` are **synthetic test data** for the tests:

- `supabase/tests/region_catalog_generator.test.mjs`;
- the Android tests' `app/src/test/resources/regions/synthetic_catalog.json`, which is generated from `synthetic-v2`.

The script refuses to write a synthetic snapshot to the shipped asset path or to `supabase/migrations/`.

## Adding a real snapshot (owner-approved)

1. **Get the data.** Obtain the district list from the Local Government Directory (lgdirectory.gov.in) or another source the owner approves. Record its URL, retrieval date and licence or attribution terms.
2. **Create the folder.** Make `data/regions/<version>/`, for example `data/regions/lgd-2026-10-15/`. The version must match `^[a-z0-9][a-z0-9._-]{2,63}$`.
3. **Write the CSVs.** All files are UTF-8, with a header row, and fields are quoted only when they contain a comma or quote.

   | File | Columns | Notes |
   |---|---|---|
   | `states.csv` | `code,name,kind` | Active States/UTs. `kind` is `state` or `union_territory`; codes are 1–3 digits |
   | `districts.csv` | `code,state_code,name` | Active districts; codes are 1–6 digits. Names are 1–64 characters and unique within a State/UT |
   | `retired_states.csv` | `code,name,kind` | Optional |
   | `retired_districts.csv` | `code,state_code,name,replaced_by` | Optional. `replaced_by` lists codes separated by `;` |
   | `aliases.csv` | `state_code,alias,district_code,kind` | Optional. `alias` is stored normalised: lower case, single spaces. `kind` is `official`, `legacy_bundled`, `renamed` or `common_spelling` |

   Rules for the data:
   - A rename keeps its code: change the name and add a `renamed` alias for the old one.
   - A split or merger retires the old code with `replaced_by`.
   - Never invent codes.
   - Add aliases only for exact, reviewed spellings. The `legacy_bundled` aliases come from names the old app saved.
4. **Write `PROVENANCE.md`.** Include these lines:
   ```
   - version: lgd-2026-10-15
   - source_url: https://...
   - retrieved_on: 2026-10-15
   - licence: ...
   - synthetic: false
   ```
   Then generate the checksum lines with `node scripts/regions/build_region_catalog.mjs --hash data/regions/lgd-2026-10-15` and paste them in.
5. **Build.** Choose the next free migration version and round number after checking every open branch for collisions, then run:
   ```
   node scripts/regions/build_region_catalog.mjs --snapshot data/regions/lgd-2026-10-15 \
     --json-out app/src/main/assets/regions/india_regions.json \
     --sql-out supabase/migrations --migration-version <14 digits> --round <n>
   ```
6. **Review and verify.** Review the generated files, run the region suites (`pnpm run test:regions` in `supabase/tests`) and the Android unit tests, then apply through the normal reviewed deployment.
7. **Backfill.** After the seed is live, run `region_legacy_backfill_report(false)` as `service_role`, review the counts, then run it with `true`.

Re-running a seed changes nothing. A later snapshot seeds a new version. That seed retires what is no longer listed, keeps codes stable, and makes the new version current. Older versions keep accepting writes until the owner sets `accepts_writes = false`.
