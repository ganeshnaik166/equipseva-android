# Region generator follow-up — 8 October 2026

## Frozen scope

Owned `codex/region-generator-replay-20261008`, base `3d25ac761837358457afe6b6746a9787ef0120ac`, frozen source **`c2a8bc7a22e33ac5fc0c61465b27f795f9ebf9e0`**. Implementation changes only `scripts/regions/build_region_catalog.mjs` and its `supabase/tests/region_catalog_generator.test.mjs`. Documentation follows separately. No Android, migration, production data, shipped asset, real snapshot, dependency manifest or lockfile changes.

An already-imported seed now refuses replay when its version is no longer current or writable, after the existing digest check and before mutations. Identical current writable replay remains valid. Version strings do not establish chronology; deliberate correction/rollback requires a new reviewed version. This is sequential replay safety, not a catalogue-concurrency proof.

Synthetic output checks examine both lexical and resolved paths, refuse resolution errors and preserve companion artifacts on refusal. Tests cover inward/outward directory links/junctions and existing output files for main/release/debug assets and migration paths, plus ordinary output controls. Hostile concurrent filesystem replacement is outside this local build-tool contract.

## Executed verification

Node **24.19.0**, PGlite **0.5.8**, command `node supabase/tests/region_catalog_generator.test.mjs` with `EQS_PGLITE_PACKAGE` pointing to the existing pinned package installed outside the checkout. All inputs are synthetic; no Supabase project was accessed.

| Evidence | Result |
|---|---|
| Initial unchanged-generator test-first run | 20/27 passed, 7 intended assertion failures, exit 1 |
| Initial correction | 27/27 passed, exit 0 |
| Final tests against original generator in isolated control | **20/28 passed, 8 intended failures**, exit 1 |
| Identical final tests against frozen correction | **28/28 passed**, exit 0 |

All 18 original properties remain and pass. Ten additional properties exercise linked outputs/resolution error, replay refusal, unchanged-current row preservation and digest precedence. Final RED/GREEN use identical tests. Tests check all seven region tables across replay refusal and the successful identical-current control. No failure was deleted, ignored or relabelled.

Frozen Git blobs: generator **`c548f0ef2527ae7c92b305d536813098ac29d6d9`**, tests **`d8d0551f920a8cec23d4fa406e61ccd67dbd497f`**. Local evidence index: `outputs/claude-intake-20261008/region-generator-verification/verification-report.md`, with raw logs, exit receipts, byte hashes, final diff and preserved original-generator control. Diff hygiene passes.

Independent final [critic](helper-reviews/codex-20261008/region-generator-critic.md) and [QA](helper-reviews/codex-20261008/region-generator-qa.md) each score **9.6/10 for this bounded local sequential-replay/path scope**. Both inspected the exact frozen source and differential evidence and each independently reran the existing offline suite: **28/28**, exit 0. No mandatory defect remains within that declared local boundary. This candidate's hosted checks remain pending. No local Gradle or new whole-region Android/SQL bar is claimed by this bounded generator verification. Hosted `test:regions` includes the broader catalogue/guard/generator suites, but previous branch success is not this candidate's verification.

## Integration boundaries

Keep this owned follow-up separate from Claude's delivered checkout/branch. Propose only its generator/docs delta into the region branch; it is not a proposal to merge the whole region feature to main. English prerequisite PR1915 is separate. Region onboarding ownership, import/write concurrency, data export, official snapshot approval/provenance, migration allocation, staging and device rollout remain unresolved or pending. No numeric score for the whole region feature or application follows from the generator tests.

Source-review details outside this bounded unreleased generator scope stay in the coordinator's local/private records. Website work remains paused. The shared Gradle slot was not used for this slice; always reread it before any future Android build.
