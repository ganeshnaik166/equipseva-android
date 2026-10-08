# Independent critic — bounded region generator follow-up

Review date: 8 October 2026. Frozen source: `c2a8bc7a22e33ac5fc0c61465b27f795f9ebf9e0`. Base: `3d25ac761837358457afe6b6746a9787ef0120ac`. Owned branch: `codex/region-generator-replay-20261008`, checkout `work/eqs-region-20261008`.

**Critic score: 9.6/10 for this bounded, unreleased generator correction and its local synthetic evidence. No unresolved mandatory defect found within the stated sequential replay and synthetic-output path scope.** This does not accept the whole region feature, main integration, hosted checks, concurrent import/write behavior, onboarding ownership, an official snapshot, staging or device rollout.

## Scope and source binding

The reviewed implementation delta comprises `scripts/regions/build_region_catalog.mjs` and `supabase/tests/region_catalog_generator.test.mjs`: 162 insertions and 11 deletions (generator +20/-10; tests +142/-1). The third frozen changed file only records ownership/scope in CURRENT_STATE. No migration, Android source, shipped catalogue, real snapshot or repository dependency file changed. The README/handoff continuity corrections read after freezing do not change implementation.

| File | Frozen Git blob | SHA-256 of executed file |
|---|---|---|
| Generator | `c548f0ef2527ae7c92b305d536813098ac29d6d9` | `A0C92665E76C0FFE92A630E85214D0E74E74A641AE96FBC48DAA9AA49873DE1F` |
| Generator tests | `d8d0551f920a8cec23d4fa406e61ccd67dbd497f` | `9494E1BC7C07E472D081C263AA6A4BCCAFCC61317B0CF31B3F0AD709BB56D7BE` |

I checked the complete base..frozen diff, relevant generator/build context, the version-table constraints, test fixtures, governing plan/ledger and handoff. `git diff --check` passed. The implementation files still match the frozen commit after the independent test run.

## Correctness assessment

**Sequential replay:** generator lines 379-384 preserve changed-digest refusal first, then reject an already-imported version unless it is both current and writable. These checks run before the generated seed performs catalogue mutations. The version table gives both flags NOT NULL semantics, so the predicate has no nullable bypass. No version-name ordering is introduced. A first import continues normally, and identical current/writable replay remains permitted.

The added tests are discriminating: a newer imported snapshot deliberately has the lexically earlier label `aaa-current`, drops an alias, and then rejects replay of the older import. Separate current/older withdrawal cases reject replay. Snapshots compare all seven region tables, including dependent profile/service/queue rows, after explicit rollback of the refused transaction. Successful identical-current replay compares the same table state. Changed data under a withdrawn label still fails the existing digest check. These assertions establish row-state preservation for the tested sequential contract; they do not claim gapless identity sequences or concurrent-transaction safety.

**Synthetic output paths:** generator lines 495-524 check both the normalized requested path and the resolved destination. This prevents an outward directory link from erasing a protected source-set/migration name and prevents an inward link from disguising its target. Native realpath failure now refuses instead of trusting an unresolved path. Both requested outputs are checked before artifact writes, so a guard refusal cannot create the companion JSON first.

The Windows tests create actual directory junctions in generated temporary repositories. Main, release, debug and migrations each test inward/outward links, missing/existing target files, sentinel preservation, absent companion output after refusal, and ordinary scratch JSON/SQL success. The EACCES case is explicitly a selective injected native-realpath error, not an OS ACL experiment; the function is restored in `finally`, and both outputs must remain absent. Tests are serial, avoiding interference from the temporary patch.

I found no code-level blocker in those two bounded behaviors. The patch changes no production data or grant surface during review; generated SQL is exercised only in synthetic PGlite databases.

## Evidence inspected and independently executed

The implementation report and final raw logs/exit receipts were read under `outputs/claude-intake-20261008/region-generator-verification`.

- Initial test-first run: 20/27 properties passed, seven intended failures; first correction: 27/27. These historical results remain distinct from the final suite.
- Final original-generator control: **20/28 passed, exit 1**. Its eight failures are four linked-output groups, the realpath-error guard, and three replay refusals. The original control generator SHA-256 is `002B45E77B3A239C597DA0A2DA305368A1134B89DFFDF458EBAF616A3B8FF084`.
- Final corrected run: **28/28 passed, exit 0**. The final original control and corrected run use the identical test SHA-256 recorded above. All 18 original properties remain and pass; the ten added properties include positive compatibility controls, not only refusal cases.
- **Independent critic rerun: 28/28 passed, exit 0**, using Node **24.19.0** and external pinned PGlite **0.5.8**. I executed `node supabase/tests/region_catalog_generator.test.mjs` in the owned worktree with `EQS_PGLITE_PACKAGE` set to the existing package under the verification directory. No package installation, Gradle task, external database or network mutation was used.

Independent raw log: `region-generator-verification/critic-independent-generator.log`; exit receipt: `critic-independent-exit-code.txt`. Executed generator/test hashes were checked again after the run and match the frozen source. Failures were not deleted, suppressed or reinterpreted as success.

## Documentation and remaining limits

The original README incorrectly described unrestricted seed replay as unchanged behavior. The coordinator corrected it during review: identical current/writable replay preserves catalogue rows; an imported non-current/withdrawn version refuses; changed-digest rejection remains first; labels are not chronology; a deliberate correction/rollback requires a new reviewed version. I read and confirmed the correction and the new bounded handoff.

The source/path protection assumes a stable local filesystem while the generator runs. Hostile concurrent path replacement, arbitrary file-write failures, and catalogue import/writer concurrency are not proved by these tests. In particular, the new predicate is a sequential pre-mutation check, not a locking protocol. Those exclusions are material and remain explicit rather than being treated as resolved by this score.

Official dataset approval/provenance, allocation/application of migrations, data-export coverage, onboarding ownership, broader region Android/SQL verification, exact-candidate hosted CI, staging and device acceptance remain separate blocked or pending scopes. No detailed unrelated review finding is included here, and this report does not authorize shipping the wider region branch.

## Rubric and decision

Applied dimensions for this CLI/generator-only delta:

| Dimension | Plan weight | Score | Basis |
|---|---:|---:|---|
| Correctness | 25 | 9.7 | Predicate order, opaque version labels, retained fresh/current controls and independent 28/28 execution |
| Security/privacy within this scope | 25 | 9.6 | Synthetic-output refusal across lexical/resolved junction paths, fail-closed resolver error, preserved target/companion files |
| Recovery/data preservation | 20 | 9.6 | Seven-table equality on refused and permitted sequential replay; withdrawal/digest precedence preserved |
| Performance/operations | 5 | 9.5 | Minimal indexed-version checks and path resolution, pinned offline reproduction and corrected operational instructions; no large-dataset benchmark claimed |
| Usability/accessibility | 15 | Not applicable | No user-facing flow or UI modification in this delta |
| Visual consistency | 10 | Not applicable | No visual or resource asset modification |

Normalizing the applicable weights (75) gives 9.63, reported as **9.6/10**. The result is earned by source review plus negative/positive differential evidence and independent execution, not inherited from previous region reviews or a forced threshold. Residual deductions reflect synthetic-engine/local-filesystem limits and the intentionally sequential scope.

**Accept as a bounded local generator implementation checkpoint.** It may support review of the owned generator/docs delta into the region branch after the remaining independent review and exact-candidate hosted gates. Whole-region/main/production acceptance remains ungranted.
