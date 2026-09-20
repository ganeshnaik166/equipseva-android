> Published copy of the independent report originally authored in the external P1a evidence directory. Original reviewer text and execution provenance follow.

# P1a AMC cleanup independent QA review

Final review: 2026-09-20. Reviewed commit: **8d80ba3c85a9dd833d08930f8b7728f9c485247c**. Production implementation remains **434663c044460104ce7ebbc60029ac9e6ee90d28**; the later commit changes only two test files.

Scope: protection of **newer committed AMC marker and verification-proof data from a stale cleanup deletion**. This is not whole-app acceptance or general account isolation.

Role disclosure: I supplied earlier architecture/design input and the first test-quality review. I am independent of the implementation agent and critic, but this is not a design-blind assessment. I did not run Gradle, change repository source/tests, or operate live accounts/payments. The coordinator owns execution. This report is outside the repository.

## Final scoped disposition

**Accepted by QA for this bounded deletion-safety slice: 9.6/10.** All applicable critical dimensions are 9.6. No unresolved mandatory in-scope coverage gap or demonstrated implementation defect remains in this review. This satisfies the QA side of the project's 9.5 gate for the stated slice only; the separate critic review and wider project gates still apply.

The original **9.3/10, not accepted** report is preserved as `qa-review-initial-9.3.md`. The increase follows concrete, executed closure of C1/S1/S2/R1, described below. Production was not changed for the review fixes, existing assertions were retained, and no score was adjusted merely to reach the threshold.

The complete unit command is still **non-green**: 3,734 tests, two preserved token-capture/outbox failures, zero errors and zero skipped. This review does not accept S1/A4, confidentiality, all sign-out resources, the whole app, a broad merge, or a release.

## Applicable rubric and rating

Governing rubric: `docs/product-plan/DELIVERY_LEDGER.md:78` and `PRODUCT_PLAN.md:196`. N/A dimensions are excluded and the remaining original weights are renormalized over 75. Correctness, security/privacy and recovery/data/money are applicable critical dimensions. No visual/UI score is imported from another review.

| Dimension | Original weight | Normalized weight | Initial | Final / 10 | Evidence-based judgment |
|---|---:|---:|---:|---:|---|
| Correctness (critical) | 25 | 33.333% | 9.4 | **9.6** | Exact-ticket state transitions, cleanup capture ordering and real-store admission are covered; C1 now proves action entry, original exception propagation and subsequent monitor acquisition from a different worker. |
| Security/privacy (critical) | 25 | 33.333% | 9.3 | **9.6** | Existing issuer/generation/raw-identity rejection coverage is supplemented by S1/S2 for both APIs, including permanent invalidation, observer-only recovery and cancellation propagation. This scores the deletion ownership fence, not global confidentiality. |
| Recovery/data/money (critical) | 20 | 26.667% | 9.1 | **9.6** | R1 now proves exact committed marker/proof survival from a reopened file before any repairing write, at both cancellation boundaries, then proves a recreated writer remains usable. Existing failure and ordering tests remain. |
| Usability/accessibility/locales | 15 | N/A | N/A | N/A | No UI, copy, focus, semantics or locale behavior changes. |
| Visual consistency | 10 | N/A | N/A | N/A | No rendered surface changes; screenshot gates are separate. |
| Performance/operations | 5 | 6.667% | 9.6 | **9.6** | Bounded concurrency/resource cleanup and reproducible source evidence remain strong. Prior lint/assembly evidence is reused only for identical production/build inputs; no new performance or telemetry acceptance is claimed. |
| Weighted scoped QA | 75 applicable | 100% | **9.3** | **9.6** | `(25*9.6 + 25*9.6 + 20*9.6 + 5*9.6) / 75 = 9.6`. |

These are judgments of the declared source and execution evidence, not measured probabilities. The residual reserve reflects finite scenario-based testing rather than an exhaustive proof over every schedule or runtime failure. There is no hidden mandatory finding behind that reserve. Excluded wider boundaries are not deducted merely because this bounded slice cannot resolve them.

## Initial deductions: concrete resolution

All line references below are to the reviewed repository source. The new ownership tests passed in both the seven-class targeted run and the complete unit rerun. The strengthened AMC test passed in both runs.

| Gap | Resolution and non-vacuity | Status |
|---|---|---|
| **C1: throwing action and monitor release** | `LocalSessionOwnershipFailureTest.kt:137`: requires a real current ticket; verifies the action actually entered once and the exact original IOException escaped. A DIFFERENT worker then captures the same ticket and executes a successful action exactly once. Bounded `Future.get` prevents a same-thread reentrant monitor from concealing failed release. | **Resolved** |
| **S1: ordinary raw-probe exception** | `LocalSessionOwnershipFailureTest.kt:44` and `:48`: both capture and guard begin from a positively usable ticket. Probe read counters prove the injected IOException path was reached; no mutation is admitted. Restoring the same raw pair does not reissue or revive the ticket. A real changed-email auth observation then issues a distinct, higher-generation usable ticket while the original stays rejected. | **Resolved** |
| **S2: raw-probe cancellation** | `LocalSessionOwnershipFailureTest.kt:90` and `:94`: both APIs propagate the exact original CancellationException. Read counters and action/sentinel assertions prove the failing probe executed without a guarded mutation. Restoring the same raw identity returns the same ticket and permits later valid work. Cancellation alone does not become an identity boundary. The sentinel rows prove guard behavior; they are not presented as disk evidence. | **Resolved** |
| **R1: cancellation durability before repair** | `PendingAmcPaymentsCleanupOwnershipTest.kt:291`: for both BeforeAdmission and AfterTransform, cancel/join the clear, close the original disk delegate and reopen the same file BEFORE any new write. Compare the exact original markers, proof and unrelated preference. Only afterward create a fresh writer, persist B and reopen again to prove A and B proofs survive with the unrelated preference. | **Resolved** |

No production change was needed to resolve these unproven branches. The new failure class contains five tests. The existing AMC class still contains eleven tests; only its cancellation test was strengthened. Git confirms the review-fix commit contains exactly these two test paths, with no production/build/config change.

The initial six test files matched behavioral RED byte-for-byte at 434663c0. After review fixes, five still match; the sixth is the additive cancellation strengthening above. The new failure class was added during post-GREEN review polishing. It is not claimed to have participated in the original behavioral RED run.

## Implementation and existing test assessment

- `SignOutCleanup` captures the departing ticket as its first synchronous operation, before draft disk cleanup or token-cache suspension. The same ticket reaches AMC cleanup, without recapture or an unowned fallback.
- Issuance is observer-only: agreeing SignedIn plus valid raw SDK identity. Initial Unknown cannot mint from a cached login. Unknown retains an already-issued ticket only while raw identity agrees; SignedOut invalidates even a cached same login.
- Exact issued-object and generation checks reject foreign, forged and stale tickets. All issuance, retirement and guarded actions use one monitor. Raw mismatch/null permanently invalidates the old object; same-session refresh preserves the object, and observed ABA or same-owner/new-session cannot reuse old work.
- Explicit retirement blocks cached same-pair re-emissions through Unknown/SignedOut/raw-null until a distinct valid agreeing identity is observed. Retiring stale A cannot revoke current B. Retirement grants no storage authority.
- The SDK parser reads one current session snapshot, requires exact string `sub` and nonblank string `session_id`, and rejects wrong JSON claim types. These claims are local isolation keys, not an authorization grant.
- `clearForSignOut` checks the ticket inside the actual serialized DataStore edit transform and removes marker/proof keys together. It does not hold the ownership monitor while waiting for admission. Existing file/key names and proof encoding remain unchanged.
- A B write committed before A's delayed transform survives; a B write queued behind an already-admitted A transform commits afterward. Same-payment-ID replacement compares exact new proof data and rejects destructive ID-only subtraction.
- The real-store ordinary control proves current-owner deletion actually removes both keys and retains unrelated preferences. Foreign-issuer tests require a truly issued foreign ticket, not null. Before-admission/reverse-order tests establish their barriers and persist/reopen real files.
- Real cleanup integration proves B's exact payment proof survives A paused in draft cleanup, separately from the intentionally failing token-capture test. The outbox-paused AMC survival case and ordinary cleanup also pass.
- Existing after-transform IOException tests prove the production transform ran, preserve committed disk state and permit a recreated retry. Their cause-chain oracle requires the intended runtime class/message and injected original exception in a bounded chain, accommodating coroutine stack recovery without accepting arbitrary failure.

The bounded guarantee uses both ownership checks and DataStore serialization. Raw SDK state can change outside the ownership monitor. This is not a general migration of payment producers/readers to durable account ownership.

## Resource and lifecycle review

The new different-worker test has a daemon worker, a five-second future bound, cancellation, shutdown and a five-second termination assertion. It verifies successful termination on the actual passing execution; it cannot indefinitely keep the test process alive if a broken-lock implementation is substituted.

Disk fixtures use unique temporary files; the original disk job is cancelled/joined before same-file reopening, and reopened readers are closed. Both cancellation-test fixtures close under nested finally blocks. Pending operations and barriers use bounded cleanup; observers belong to `runTest.backgroundScope`. No definite resource leak was found, and both targeted/full executions completed with no test errors, skips or new failures. Real Android-dependent DataStore I/O uses Robolectric SDK34.

## Executed evidence independently verified

I read command/log/summary/results and parsed the archived XML independently; I did not infer execution from the coordinator's status message.

| Execution | Exact evidence directory | Suites | Tests | Failures | Errors / skipped | Result |
|---|---|---:|---:|---:|---:|---|
| Original behavioral RED | `red-behavioral` | 6 | 47 | 26 | 0 / 0 | Unsafe scaffold; assertion evidence. Earlier Android rename-error runs are excluded. |
| Original GREEN targeted | `green-targeted` | 6 | 47 | 2 | 0 / 0 | Only retained token/outbox failures. |
| Original full verification at 434663c0 | `full` | 425 | 3,729 | 2 | 0 / 0 | Prior full unit/lint/debug/unsigned R8 evidence. |
| Review-fix targeted | `polish-targeted` | 7 | **52** | **2** | **0 / 0** | Command exit 1; 50 passed. |
| Review-fix full unit at 8d80ba3c | `polish-full-unit` | **426** | **3,734** | **2** | **0 / 0** | Command exit 1; 3,732 passed; 3m36s. |

Targeted and full results agree: LocalSessionOwnershipTest 18/0; LocalSessionOwnershipFailureTest 5/0; PendingAmcPaymentsCleanupOwnershipTest 11/0; SignOutCleanupLocalBoundaryRegressionTest 5/2; cleanup ownership 4/0; draft fence 1/0; request-service integration 8/0. Existing paid-credit recovery 16/0, AMC reconciliation 8/0 and reverification 5/0 also pass in the new full unit run.

The only failures remain:

1. `B's outbox row survives A's delayed draft cleanup`: A's resumed global cleanup erased B's new work.
2. `departing owner is captured before a delayed draft disk clear can observe B`: expected A/token-A revocation but captured B/token-B.

Both remain enabled. Neither targeted nor complete unit execution is reported as globally green.

New commands: the targeted `:app:testDebugUnitTest` invocation selects the seven recorded classes; the full rerun is `.\gradlew.bat :app:testDebugUnitTest --no-daemon --console=plain`. Exact commands, timestamps, logs, XML and source manifests are archived under their respective directories.

I rehashed all ten live source/test files: every hash matches both `polish-targeted/source-hashes.json` and `polish-full-unit/source-hashes.json`. The latter base SHA is 8d80ba3c85a9dd833d08930f8b7728f9c485247c. Git diff against 434663c0 has exactly two test paths and no app production/build/config change.

| Frozen file | SHA-256 |
|---|---|
| LocalSessionOwnership.kt | 8A56F740EF4EEB5C87923DE0CC9C7265E4192AD26019BDAF24FE4066186132E2 |
| PendingAmcPaymentsStore.kt | 7ED5175786C25AF6F7115A2B372DFD742673646CF0BD3DD3180FDA822C4BB06E |
| SignOutCleanup.kt | C590BF6C4514B85C375F4109278850B13F0897B64CD130843A8D1A6B23403AB7 |
| LocalSessionOwnershipFailureTest.kt | 4FD763E98DBF1B444B9BC3D667950B1DBFDC3546B1BA48BE8A1FEB8F97868380 |
| PendingAmcPaymentsCleanupOwnershipTest.kt | F4FFE4CFA3E3047131D4A4317A7503900962BDE3F2F48357D425407D24FCE5B3 |

## Reused build evidence and release boundary

Lint, design ratchet, debug assembly and unsigned R8 assembly were executed earlier at **434663c0**, not rerun after the two test-only changes. Reuse is justified by the verified unchanged production/build inputs; it is not described as new assembly execution at 8d80ba3c.

The earlier independently checked `full/verification.json`, complete log and lint XML record **0 lint errors, 89 warnings, 2 hints**, no lint issue location matching the changed P1a production files, design RATCHET OK without baseline changes, and successful debug plus minified unsigned release assembly. The original combined command still exited 1 because of the two retained test failures.

The earlier APK SHA-256 values verified against that receipt are debug `0438A7D672359BBEBE2FC440A6D871956659B80703675D592CD32D5B7EC174C9` and unsigned release `D071FAF6CDD1B5BFBA76337DFBEBB4B799928FC980DD5BB10CFE226F2086D633`.

`PRECHECK_LOOSE=1` allowed missing expected certificate/keystore checks to continue. Signature verification returned **DOES NOT VERIFY / Missing META-INF/MANIFEST.MF / exit 1**, recorded in `release-signature.log` and `release-signature-exit.txt`. This is unsigned output, not strict prerelease or signed release acceptance.

The earlier receipt records cleared process Sentry credentials. Its Gradle log also reports an existing Crashlytics mapping-upload finalizer. Neither zero uploads nor complete telemetry/symbol-delivery acceptance is inferred. No new release finalizer was required just to validate the test additions.

## Boundaries still open

Global historical unowned keys, producers/readers, remove/reconciliation APIs and confidentiality are excluded. A current-owner clear can still remove historical global rows with no durable owner metadata. Missing reliable identity retains recovery data rather than guessing ownership.

Unobserved ABA ending at an identical raw identity, a caller already stale before cleanup entry, all other cleanup resources, token capture, outbox deletion and final SDK logout remain outside P1a. The two reproduced token/outbox failures remain mandatory visible follow-up work. Device/provider testing, broader sign-out acceptance, S1/A4, whole-app security and release gates remain open. The resolved QA deduction labelled S1 above is a review finding identifier; it does not close the broader S1 program boundary.
