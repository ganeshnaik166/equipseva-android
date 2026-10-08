# Region generator correction — independent local QA

Reviewer: `/root/english_cache_qa_1008`, 8 October 2026.

**QA: 9.6/10 for the bounded local sequential-replay and synthetic-output-path correction. No unresolved mandatory blocker in this declared scope.** This is not whole-region, Android/onboarding, catalogue-concurrency, deployed-database or release acceptance.

## Frozen source

- Base: `3d25ac761837358457afe6b6746a9787ef0120ac`.
- Reviewed source: `c2a8bc7a22e33ac5fc0c61465b27f795f9ebf9e0` in `work/eqs-region-20261008`, branch `codex/region-generator-replay-20261008`.
- Generator blob: `c548f0ef2527ae7c92b305d536813098ac29d6d9`; tested working-file SHA-256 `A0C92665E76C0FFE92A630E85214D0E74E74A641AE96FBC48DAA9AA49873DE1F`.
- Test blob: `d8d0551f920a8cec23d4fa406e61ccd67dbd497f`; tested working-file SHA-256 `9494E1BC7C07E472D081C263AA6A4BCCAFCC61317B0CF31B3F0AD709BB56D7BE`.

QA read the continuation contract/current scope, relevant governing geography/acceptance records, generator handoff/readme, complete two-file implementation delta and surrounding code/fixtures. These hashes were re-read after independent execution and remain unchanged. Follow-up working changes observed were documentation only. Diff hygiene passes.

## Evidence quality

The preserved original-generator control and final corrected run use identical final tests. QA checked their raw logs, exit receipts, byte hashes and control copy:

| Run | Actual result |
|---|---|
| Final 28-property tests against original generator | 20/28 passed, eight intended failures, exit 1 |
| Same tests against corrected generator | 28/28 passed, exit 0 |
| Independent QA rerun on frozen corrected files | **28/28 passed, exit 0** |

The eight RED outcomes are four outward-link groups, the native-resolution-error control, and three replay-refusal cases. The tests fail on missing expected exception/rejection rather than setup or missing dependency errors. All original 18 generator properties remain and pass in both final runs. Ten added properties include valid-operation controls as well as failures; no test was disabled or reclassified to obtain acceptance.

Independent command: `node supabase/tests/region_catalog_generator.test.mjs`, with `EQS_PGLITE_PACKAGE` pointing to the existing verification-only `dependencies/node_modules/@electric-sql/pglite`. Runtime Node 24.19.0 / PGlite 0.5.8. No install or repository dependency changes were made by QA. Log: `outputs/claude-intake-20261008/region-generator-verification/qa-independent-green.log`.

## Correctness checks

### Sequential seed replay

- The emitted guard follows the existing digest mismatch check and precedes catalogue mutations. An already imported non-current or non-writable version is rejected. Current/writable identical replay remains supported.
- Version labels are treated as opaque. The old-replay fixture deliberately installs a newer version named `aaa-current`, preventing lexical ordering from accidentally satisfying the intended behavior.
- Old replay and operator-withdrawn latest/older replay are rejected. Tests compare all seven region tables after rollback, including dependent user-region rows. The independent valid-current replay compares the same complete region snapshot and passes.
- Changed content under a withdrawn version still reports the digest mismatch first. Ordinary new-version transition, retired-code handling, alias changes, quoting, name swaps and district moves remain exercised by the pre-existing suite.
- This is a sequential preflight contract. No claim is made about simultaneous importer/operator/client transactions, isolation or locking in deployed PostgreSQL.

### Synthetic output paths

- Both normalized lexical and resolved destination paths are checked. Outward links cannot remove the protected requested name; inward links cannot hide a protected actual target.
- Four real temporary layouts cover main/release/debug assets and migrations. Each creates native Windows junctions, exercises both directions and both missing/existing target files, preserves existing sentinel bytes, and checks that rejected SQL output does not leave a companion JSON artifact.
- The `realpathSync.native` error control injects EACCES only for a generated scratch directory, restores the original function in `finally`, and proves both outputs stay absent. This is a deterministic error-path test, not a claim that production Windows ACL behavior was exercised.
- Ordinary scratch JSON and SQL generation succeed in the same fixtures. Earlier relative/absolute/current-directory refusal controls remain intact.
- New junctions are removed before recursively deleting only the validated generated temporary root. No real shipping asset, production seed or machine ACL was modified.
- The contract assumes a stable local filesystem during generation. Hostile concurrent path replacement and arbitrary write-time I/O failures are not proven by these checks.

## Rating and limits

The 9.6 reflects strong test-first discrimination, actual native junction execution, complete region-row replay comparisons, preserved valid operations and an independently repeated final suite. Applicable critical correctness and source/data-safety dimensions each meet 9.6. User-interface/visual dimensions are not applicable to this command-line generator delta and receive no invented app rating.

The remaining 0.4 reflects bounded execution coverage: PGlite and Windows local controls are not hosted Linux/deployed PostgreSQL evidence; the filesystem error is injected, and concurrency is intentionally excluded. Those are stated boundaries rather than an automatic score boost or acceptance of broader work.

The new detailed handoff/readme accurately scope sequential safety and stable-path assumptions, preserve the failed baseline, and distinguish the future hosted checks. Original handoff overclaims about an unseeded migration being inert and having no internal triggers are corrected in the inspected documentation WIP.

Still required separately: this candidate's hosted region/guard/generator checks, English prerequisite integration, whole-region onboarding identity and catalogue-concurrency work, real approved district snapshot/provenance, migration allocation, exports, staging/provider/device rollout and final integration acceptance. No production project was accessed, no Gradle run was started and no Claude-owned branch or source file was edited by QA.
