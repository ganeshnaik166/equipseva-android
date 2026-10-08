# Handoff — WP25.T01 region catalogue v1 (Claude, 7–8 October 2026)

Status: **built and pushed; four review rounds fixed; the round-5 acceptance review has not completed (the session ended while it ran). Not merged, no PR.** Resume point: [CURRENT_STATE.md](CURRENT_STATE.md).

## What this is

PRODUCT_PLAN §6 and delivery ledger P2.2 describe location as India → State/UT → district, stored as stable codes plus the catalogue version they came from. There are no maps or GPS, and fuzzy or substring matching never decides anything. This slice builds the server, the data pipeline, the device-side catalogue and the onboarding save path for it.

No production catalogue asset or seed is bundled. Applying the schema migration still changes schema/permissions and takes locks. Without a seeded catalogue:
- no catalogue is bundled and no seed migration exists;
- the server refuses every coded write (`region_catalog_version_unsupported`);
- onboarding keeps its existing label-only save.

Branch `claudedev-region-catalog-20261007` is stacked on `claudedev-english-only-20261007` (`d8f85fcf`) and **must merge after it**. Head: **`ce0b4db0`**.

## Sub-slices

| Sub-slice | Files | What it does |
|---|---|---|
| **A** Server (`round3830`, version `20263915000000`) | `supabase/migrations/20263915000000_round3830_region_catalog_v1.sql`; tests `supabase/tests/region_catalog*.{fixture.sql,test.mjs}`; `package.json` `test:regions`; `supabase-sql-s3a.yml` | Public read-only catalogue tables; `profile_regions` and `engineer_service_districts` (own-row read, RPC write, cascade on delete); `region_resolution_queue` (no client access). RPCs `region_catalog_current`, `set_my_home_region`, `set_my_service_districts` (1–30 codes, any State/UT), `my_region_profile`; service-only `region_legacy_backfill_report(p_apply)` (counts only, dry run equals apply). Exact-only resolution; the queue has its own lifecycle (open/resolved/superseded/dismissed); label snapshots; State/UT moves cascade. No new application column, policy, grant or enum on `profiles`/`engineers`; foreign keys create internal constraint triggers and take locks |
| **B** Generator | `scripts/regions/build_region_catalog.mjs`, `README.md`, `fixtures/synthetic-v1`, `fixtures/synthetic-v2` | Turns a reviewed snapshot folder (provenance and checksums) into the Android asset and a seed migration. It validates every rule and refuses rather than repairs. Synthetic data can never reach the shipped asset or `supabase/migrations/` |
| **C** Client core | `app/src/main/kotlin/com/equipseva/app/core/data/location/Region*.kt` | Code-based catalogue (normalisation identical to the server's), strict asset parser, code-based selection draft, asset loader (none bundled means null; synthetic is refused outside debug builds), repository for the four RPCs, Hilt module |
| **D1** Onboarding | `features/onboarding/OnboardingHomeRegion.kt`, the hospital and engineer onboarding ViewModels, `OnboardingLocationFields.kt` | With a catalogue, onboarding saves the home State/UT and district as codes before the existing phone/label save. Without one, nothing changes. A server that isn't ready falls back to today's save; the NeedsOnboarding gate is untouched |

## Evidence (all synthetic; no Supabase project touched)

| Check | Result at `ce0b4db0` |
|---|---|
| Android full bar | `PRECHECK_LOOSE=1 ./gradlew.bat :app:testDebugUnitTest :app:lintDebug :app:assembleDebug --console=plain`: **3,057 tests / 359 suites / 0 failures**, lint **0 errors** / 86 warnings / 2 hints, debug APK built |
| Region Kotlin suites | 93 tests / 12 suites / 0 failures (location + onboarding) |
| `region_catalog.test.mjs` (PGlite 0.5.8) | NEW **17/17**; negative controls fail on LEGACY 5/5; regressions pass on LEGACY 2/2; unseeded 2/2; mutant controls 2/2 |
| `region_catalog_guards.test.mjs` | 5/5 (real public guard triggers in a PostgREST-shaped session) |
| `region_catalog_generator.test.mjs` | **18/18** (path-guard properties run in a throwaway repository copy) |
| `service_only_money_rpc_grants.test.mjs` (round3828) | unchanged, all expectations met |
| Mutation testing | 15 round-2, 11 round-3, 7 of 8 round-4 server and 9/9 round-4 generator mutants killed; the survivor removes the dedupe's early exit, which only costs time |
| CI | `android`, `supabase-sql-s3a` and `secret-scan` green through `0363d39c`; later pushes not re-checked |

Run the SQL suites with Node 24 and an extracted `@electric-sql/pglite@0.5.8` package: `cd supabase/tests && EQS_PGLITE_PACKAGE=<dir>/package node region_catalog.test.mjs` (likewise `region_catalog_guards`, `region_catalog_generator`, `service_only_money_rpc_grants`). On the owner's laptop Node is `ELECTRON_RUN_AS_NODE=1 "C:/Users/lokes/AppData/Local/Programs/Microsoft VS Code/Code.exe"`.

## Reviews

| Round | Scores | Outcome |
|---|---|---|
| 1 (server) | critic 8.6, QA 8.8, production-compatibility 9.5 | all findings fixed in `dbb68831` |
| 2 | server 8.8 / 8.8; client critic 9.3, client QA 9.5 | fixed in `e44052ef` |
| 3 | server QA 9.5, critic 9.3 (no blockers); client and generator findings | fixed in `067af7da` and `0363d39c` |
| 4 (acceptance, 4 reviewers + skeptics) | server critic 9.0, generator critic 9.3, generator QA 9.3, client 9.6 | two verified blockers — the queue's unique index failed on an 8,000-character engineer label (every backfill apply aborted), and `--hash` disagreed with the loader on a byte-order mark — fixed with the should-fixes in `9addf36b`; Kotlin gaps closed in `ce0b4db0` |
| 5 (acceptance) | not completed | rerun it: four reviewers (server critic, server QA, generator/client critic, generator/client QA) against `ce0b4db0`, each ≥ 9.5, with a skeptic per reported blocker; reviewers must mutate copies in a scratch folder, never the repo |

## Owner decisions needed

1. **Approve a district snapshot.** The recommended source is the data.gov.in dataset "Local Government Directory (LGD) – Districts". Its contributor is the Ministry of Panchayati Raj, it is published under the Government Open Data License – India, and it is updated monthly; the official LGD download directory (lgdirectory.gov.in) carries the same data. Someone with access downloads the CSV, maps it to the folder format in `scripts/regions/README.md` and records the date and checksums. The generator then produces the asset and the seed.
2. **Confirm the service-district cap (30) and cross-State/UT coverage.** Both are implemented as suggested by the plan.
3. **Allocate the migration version at integration.** `20263915000000` is free today; other pending branches hold up to `20263914000000`.

## Production runbook (after approval; not done)

Apply round3830 to staging, then run a read-only catalogue check (definer, `search_path`, EXECUTE and table privileges). Apply the generated seed and run `NOTIFY pgrst, 'reload schema'` if `/rpc/region_catalog_current` answers PGRST202. As `service_role`, run `region_legacy_backfill_report(false)`, review the counts, then run it with `true` off-peak. Then do the same in production, and ship the app with the bundled asset.

## Not done / next

- **Round-5 acceptance review** (see Reviews) and a check that CI is green on the latest pushes (`9addf36b`, `ce0b4db0`). Then record acceptance in CURRENT_STATE, MILESTONE_LOG and ledger P2.2.
- **D2.** A service-district picker in the engineer profile; today's free-text service areas stay as they are. The plan puts that screen with another package, and it is only useful once a catalogue ships.
- **Feeds and attendance.** The district-based job feed and attendance work (WP25.T02 onwards) is unchanged by this slice.
- **Export.** `export_my_data` does not yet include the new tables (account-deletion cascades are in place).

## 8 October generator follow-up

The owned follow-up [records a bounded replay/path correction](HANDOFF_REGION_GENERATOR_2026-10-08.md). It does not accept the complete region feature. The prior tests and review rounds above retain their historical scope; final integration, dataset and rollout gates remain open.
