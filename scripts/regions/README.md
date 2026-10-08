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
3. **Write the CSVs.** All five files are required, UTF-8 (a byte-order mark, as Excel writes, is fine), with a header row; for an empty list keep just the header row. Fields are quoted only when they contain a comma or quote. No other `.csv` file may be in the folder.

   | File | Columns | Notes |
   |---|---|---|
   | `states.csv` | `code,name,kind` | Active States/UTs. `kind` is `state` or `union_territory`; codes are 1–3 digits |
   | `districts.csv` | `code,state_code,name` | Active districts; codes are 1–6 digits. Names are 1–64 characters and unique within a State/UT |
   | `retired_states.csv` | `code,name,kind` | Header only when there are none |
   | `retired_districts.csv` | `code,state_code,name,replaced_by` | Header only when there are none. `replaced_by` lists codes separated by `;` |
   | `aliases.csv` | `state_code,alias,district_code,kind` | Header only when there are none (a missing file is refused, because the seed makes the server's alias set equal to this file). `alias` is stored normalised: lower case, single spaces. `kind` is `official`, `legacy_bundled`, `renamed` or `common_spelling` |

   Rules for the data:
   - A rename keeps its code: change the name and add a `renamed` alias for the old one.
   - A district that moves to another State/UT keeps its code: list it under the new State/UT and move its aliases too. The seed moves the stored codes with it.
   - Names are compared after lower-casing and collapsing ASCII whitespace only. A non-breaking space is a different character, so clean such characters out of the source data.
   - Names and aliases may use printable ASCII and the Latin-1 letters only: other letters (for example a dotted capital I or a Greek sigma) are lower-cased differently by the device and the server, so the build refuses them.
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

Re-running an identical **current, writable** seed preserves catalogue rows. Replaying an already-imported non-current or withdrawn version is refused before mutations, so replay cannot undo a withdrawal or restore an older imported snapshot. Changed data under an existing version still fails the digest check. Version labels are not sorted; deliberate correction or rollback requires a new reviewed version. A new snapshot retires what is no longer listed, keeps codes stable, and becomes current. Older versions keep accepting client writes until the owner sets `accepts_writes = false`; that does not permit their seed to be replayed.

Synthetic-output checks cover both the requested path and the resolved destination, including links/junctions into or out of source-set asset trees and migrations. Path-resolution errors refuse before either output is written. These checks assume the local filesystem is not concurrently replaced during generation. Catalogue writer/import concurrency and production rollout remain separate acceptance gates; the sequential replay tests do not prove them.
