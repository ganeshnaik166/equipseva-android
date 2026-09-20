> Published copy of the independent report originally authored in the external P1a evidence directory. Original reviewer text and execution provenance follow.

# Independent critic — P1a AMC cleanup deletion safety

Date: 20 September 2026. Reviewer: independent `product_plan_critic` agent. This is the final follow-up review; the original 19 September review is preserved separately.

**Final disposition: 9.6/10, accepted only for the described successor-login AMC cleanup deletion-safety boundary, with production from `434663c044460104ce7ebbc60029ac9e6ee90d28` and the test-only follow-up at `8d80ba3c85a9dd833d08930f8b7728f9c485247c`. No actionable defect found in that scope.** The new tests and their targeted/full-unit receipts were independently inspected. Both new Gradle commands still exit 1 because the original token-capture and outbox regressions remain enabled and fail. This report does not accept the app, S1/A4, confidentiality, payments, main integration or release.

## Revision and scope

Base `3c61469927b01bb0592ff501a8af42f401c937a2`. The coordinator committed the initial nine app/test files as `434663c044460104ce7ebbc60029ac9e6ee90d28`. The follow-up commit `8d80ba3c85a9dd833d08930f8b7728f9c485247c` changes exactly two test files: one new failure-test class and the existing AMC cancellation test. The three production files and build configuration are unchanged. No app source change is authorized by this report. Documentation and other coordinator edits are outside this code review.

Production hashes independently verified against current files and `green-targeted/source-hashes.json`:

| File | SHA-256 |
|---|---|
| `core/auth/LocalSessionOwnership.kt` | `8A56F740EF4EEB5C87923DE0CC9C7265E4192AD26019BDAF24FE4066186132E2` |
| `core/payments/PendingAmcPaymentsStore.kt` | `7ED5175786C25AF6F7115A2B372DFD742673646CF0BD3DD3180FDA822C4BB06E` |
| `core/auth/SignOutCleanup.kt` | `C590BF6C4514B85C375F4109278850B13F0897B64CD130843A8D1A6B23403AB7` |

Paths above have prefix `app/src/main/kotlin/com/equipseva/app/`. The six initially reviewed test files are `LocalSessionOwnershipTest`, `PendingAmcPaymentsCleanupOwnershipTest`, `SignOutCleanupLocalBoundaryRegressionTest`, `SignOutCleanupOwnershipTest`, `SignOutDraftFenceTest` and `RequestServiceAccountSwitchIntegrationTest`. Their archived initial versions are byte-identical between behavioural RED and the initial targeted GREEN. The follow-up adds `LocalSessionOwnershipFailureTest` and strengthens one cancellation test; the current seven test files must not be described as unchanged from the original RED. The original token/outbox regression assertions remain intact.

The guarantee is deliberately narrow: an AMC cleanup ticket captured before suspension cannot delete a successor login's newly committed marker/proof when that login boundary is observed or detected by a raw identity probe; if cleanup was admitted first, a later write serialized behind it survives. It does not protect arbitrary new activity inside the same still-current login, historical records with unknown owner, or operations outside this cleanup path.

The critic inspected source, diffs, the existing ownership handoff and archived evidence. The critic ran no Gradle, app, device, database, provider or production operation, made no app/test changes and did not alter the earlier product-plan review.

## Source assessment

No actionable blocker found for that guarantee.

1. **Capture and issuer identity.** `SignOutCleanup.wipeLocalUserState()` captures the ticket as its first synchronous operation, before the real draft fence can suspend. The same immutable object reaches `clearForSignOut`; there is no live-user recapture at the AMC step. Repeated captures preserve one issued object. Reference identity plus generation rejects a lookalike or another owner's issuer even when its fields match.
2. **Identity transitions.** The observer alone establishes a ticket from an agreeing `SignedIn` and valid raw identity. Initial Unknown/SignedOut cannot adopt a cached SDK identity. Same-session identity and email/token changes preserve ownership. Unknown retains established ownership only while the raw identity agrees. SignedOut invalidates, and a raw null/mismatch/malformed identity irreversibly invalidates the old issued object. Observed A→B→A and same-user/new-session cannot resurrect an old ticket. Explicit retirement blocks the same cached identity until a distinct agreeing login is observed; stale retirement cannot retire B.
3. **Raw SDK input.** Production probes one SDK session snapshot. JWT parsing requires an exact string `sub` matching its user ID and a nonblank string `session_id`; malformed/non-string claims fail closed for deletion. Parsed claims grant no server authority. Unexpected ordinary probe exceptions return no identity; cancellation propagates.
4. **Actual storage boundary.** The cleanup-specific API enters real `DataStore.edit` before invoking `withCurrent`, and both marker and verification-proof keys are removed within the same short, non-suspending guard action. It does not acquire DataStore while holding the ownership monitor. Null/stale tickets do not fall back to `clearAll`. Filename, keys, encoding, unrelated preferences and the existing non-cleanup APIs remain unchanged.
5. **Concurrency reasoning.** The ownership monitor serializes its own ticket transitions with the in-memory preference mutation; it does not lock Supabase authentication. DataStore serialization supplies the storage ordering: B committed before delayed admission causes A's guard to reject; B queued after A's already-admitted transform executes after A and survives. The implementation does not falsely rely on cancelling a coroutine or checking before `edit`.
6. **Scope containment and maintainability.** One new singleton holds this local contract independently of the request-draft store, whose logout fence intentionally retires its own lease. The new types have focused responsibilities, explicit failure semantics and no server/UI/schema/payout change. The three compatibility test files only receive the new constructor dependency. The production comments retain unresolved token/outbox and global-store limitations.

## Initial test quality and inspected results

The tests invoke production mutation logic. The file-backed store wrapper supplies barriers around the real delegate; it does not reproduce the ownership check or deletion oracle. It verifies nonempty markers/proofs before survival/deletion assertions and reopens the persisted file. The after-transform case checks that B has called the same delegate, its transform has not run, and its exact same-order replacement proof commits afterward.

Coverage includes fresh cleanup, unrelated-key preservation, before-admission and after-transform races, same payment ID/new proof, observed ABA, same-user fresh login, raw observer lag, null/foreign/forged/retired/malformed tickets, initial Unknown, cancellation at both barriers, failure before admission, failure after the production transform, persisted rollback, recreated valid retry and fresh writes afterward. Ownership tests also exercise genuine concurrent capture and retirement ordering. Rejection callbacks fail if wrongly invoked; a returned Boolean alone is not the oracle.

The real cleanup fixture preserves the original token and outbox safety assertions while replacing the mocked AMC set with the actual file-backed store. It adds an earlier draft-disk suspension case, proving that capturing only at the AMC step would be too late. Existing request-draft and cleanup compatibility assertions are unchanged apart from dependency injection.

| Suite | Behavioural RED tests / failures | Targeted GREEN tests / failures |
|---|---:|---:|
| `LocalSessionOwnershipTest` | 18 / 16 | 18 / 0 |
| `PendingAmcPaymentsCleanupOwnershipTest` | 11 / 6 | 11 / 0 |
| `SignOutCleanupLocalBoundaryRegressionTest` | 5 / 4 | 5 / 2 |
| Existing cleanup/draft/request compatibility | 13 / 0 | 13 / 0 |
| **Total** | **47 / 26** | **47 / 2** |

Both runs contain zero errors and zero skips. RED here means assertions against the archived unsafe behavioural scaffold; it does not mean every failing ownership assertion was a previously exploited production bug. The earlier fixture-IO-error run is not substituted for behavioural RED.

The two remaining targeted failures are exactly:

- `departing owner is captured before a delayed draft disk clear can observe B`: remote-token capture still occurs after draft suspension and captures B.
- `B's outbox row survives A's delayed draft cleanup`: outbox deletion remains global and erases B's row.

The targeted command exits **1**, not 0. The new ownership/store checks and both AMC-survival/ordinary-cleanup integration controls pass. No assertion was removed or skipped to obtain that outcome.

## Initial full-check receipt

Independently summed the **425 archived JUnit XML files** under `full/xml`: **3,729 tests, two failures, zero errors, zero skips**. The failures are exactly the same preserved token-capture and outbox assertions listed above; no additional full-suite failure appeared. `full/base-sha.txt` identifies `434663c044460104ce7ebbc60029ac9e6ee90d28`, and all nine reviewed file hashes matched that full-run source manifest at the initial review.

Read `full/command.txt`, `full/gradle.log`, `full/verification.json`, archived `full/lint-results-debug.xml`, `design-lint.log` and the separate `release-signature.log`:

- Full command: `:app:testDebugUnitTest :app:lintDebug :app:assembleDebug :app:assembleRelease --continue --no-daemon --console=plain`.
- Overall **exit 1 / BUILD FAILED in 7m 54s**, owing to the two retained unit assertions. This is not a green full suite.
- Lint: **zero errors, 89 warnings, two hints**. Debug assembly, release R8/assembly and the design ratchet complete successfully. No ratchet baseline change is part of this fix.
- Release checks used `PRECHECK_LOOSE=1`. The release APK is **unsigned**; signature verification exits 1 with `DOES NOT VERIFY` / missing signature manifest. Successful unsigned assembly is not distribution acceptance.
- Sentry credentials were absent from the local check process. The existing Crashlytics Gradle finalizer reports mapping upload; that log is retained as observed, without asserting end-to-end symbolication, credential policy or release acceptance.

## Test-only follow-up and final evidence

The initial critic judgment was 9.5/10. Independent QA rated the initial slice 9.3/10 and identified missing direct exception/recovery and cancellation-persistence evidence. The coordinator reopened the slice for tests instead of waiving that gate. The initial critic report remains unchanged as `critic-review-initial-9.5.md` (SHA-256 `F8CE6A815E1D53CF2798CB9F059289F0FFFDFF60F0CACCC70D75442DD0BEDCBB`). This revised judgment does not overwrite or represent QA's separate judgment.

Independently inspected the follow-up diff and both complete test files. No production change or regression-test weakening was found. Exact reviewed hashes, under `app/src/test/kotlin/com/equipseva/app/`:

| File | SHA-256 |
|---|---|
| `core/auth/LocalSessionOwnershipFailureTest.kt` | `4FD763E98DBF1B444B9BC3D667950B1DBFDC3546B1BA48BE8A1FEB8F97868380` |
| `core/payments/PendingAmcPaymentsCleanupOwnershipTest.kt` | `F4FFE4CFA3E3047131D4A4317A7503900962BDE3F2F48357D425407D24FCE5B3` |

The five new failure tests and strengthened disk test supply meaningful evidence for the four identified gaps:

- **C1 — action exception and monitor release:** a valid ticket enters the guarded action, increments an invocation counter and throws a specific exception; the test asserts the original exception object. A dedicated executor then reuses the same ticket from a different thread, with a bounded wait and a successful mutation. This proves reuse beyond a reentrant call on the original thread.
- **S1 — ordinary probe failures:** separate capture and guard tests first establish a real ticket and successful action, inject an ordinary supplier exception, and prove that the failing probe was called. They deny capture and old-ticket mutation even after restoring the same raw identity. Only a new agreeing auth observation reissues a different ticket with a higher generation; the retired ticket remains denied. The tests do not pass merely because ownership was never established.
- **S2 — probe cancellation:** separate capture and guard tests assert propagation of the exact cancellation exception and the extra supplier invocation. The guard action is not invoked and stored test state remains unchanged. Once the supplier is restored, the same issued ticket is still current and can perform a successful guarded action.
- **R1 — cancellation persistence before repair:** both before-admission and after-transform cancellation cases seed real marker/proof data, cancel and join the cleanup, then close and reopen the file-backed DataStore before any fresh write. Exact original markers, proofs and an unrelated preference must equal their pre-cleanup values. Only afterward does a fresh fixture write B's proof and reopen again to verify that both A's retained proof and B's new proof persist. A later write cannot hide a damaged cancellation result.

Independently verified archived XML totals, preserved failure names/messages, launch HEADs and all ten current source hashes against the new manifests. `polish-targeted/base-sha.txt` records launch HEAD `434663c044460104ce7ebbc60029ac9e6ee90d28` with the two frozen polish test files still uncommitted. Those identical test sources were then committed as `8d80ba3c85a9dd833d08930f8b7728f9c485247c`; `polish-full-unit/base-sha.txt` records that commit as its launch HEAD. Both runs tested source matching the reviewed `8d80ba3c` files; only the full-unit run launched from that commit.

| Run — tested source matches `8d80ba3c85a9dd833d08930f8b7728f9c485247c` | Suites | Tests | Failures | Errors / skips |
|---|---:|---:|---:|---:|
| `polish-targeted` | 7 | 52 | 2 | 0 / 0 |
| `polish-full-unit` | 426 | 3,734 | 2 | 0 / 0 |

The new failure suite passes **5/5**, existing ownership **18/18**, and real AMC store **11/11**. The full-unit command is `.\gradlew.bat :app:testDebugUnitTest --no-daemon --console=plain`; it exits **1 / BUILD FAILED in 3m 36s**. Both runs retain exactly the original token-capture and outbox failures described above, with the original failure messages. The five new methods account for the increase from 3,729 to 3,734 tests. No tests are skipped, and the full suite is still not green.

The earlier lint, debug assembly, unsigned release/R8 and design-ratchet receipts remain evidence for the identical production/build source at `434663c0`. They were **not rerun for the test-only follow-up**, so the earlier lint is not a fresh lint check of the new test file, nor is a new APK claimed. Both new unit commands compile and execute the added tests. The unsigned-release, relaxed-precheck and Crashlytics/Sentry caveats in the initial receipt remain unchanged.

The **9.6/10 scoped critic judgment** reflects the added direct failure and durable cancellation evidence, as well as the previously reviewed exact-ticket checks, raw-identity invalidation, guard inside the real serialized mutation and cleanup integration. No newly failing full-suite case appeared. The two known defects remain outside this specific mutation guarantee and continue to block the broader app. The score is not an average that clears them. No runtime/device/provider/security-certification or whole-resource isolation claim follows from this rating.

### Dimension scores and aggregation

This applies the delivery ledger's frozen weights to the actual code scope. Scores are reviewer judgments about the stated boundary, not measured percentages or grades for the whole corresponding app subsystem. Correctness, security/privacy and recovery/data/money are the critical dimensions for this mutation. UI/visual dimensions have no changed surface and are excluded rather than awarded free points.

| Dimension | Original weight | Score / 10 | Basis and limits |
|---|---:|---:|---|
| Correctness — critical | 25 | 9.7 | Exact issued-object/generation checks, strict raw identity, permanent observed-boundary invalidation and first-operation capture match the contract. Positive controls, negative lifecycle cases and both real storage orderings pass. The follow-up directly proves action exception propagation and successful different-thread monitor reuse. Exhaustive SDK lifecycle/model checking was not performed; undetected boundaries are explicitly excluded. |
| Security/privacy — critical, scoped to deletion authority | 25 | 9.6 | Foreign/forged/stale tickets and malformed identities cannot authorize the guarded deletion; issuer checks and both-key mutation occur at the actual storage boundary. Direct ordinary-probe-failure and cancellation tests now exercise both APIs with positively established authority. This is not a confidentiality grade: unowned historical data, global reads/reconciliation and other cleanup resources remain blocking work outside this accepted boundary. |
| Recovery/data/money — critical | 20 | 9.7 | Exact proof retention, same-order replacement, cancellation, pre-admission/after-transform failures and successful current retry/fresh writes are exercised. Immediate persisted reread after cancellation now precedes any repairing write, and exception recovery is directly exercised. Tests do not certify device crash behavior, provider reconciliation or every process-death window. |
| Usability/accessibility/locales | 15 | Not applicable | No UI, text, locale, navigation or interaction change. Existing product acceptance remains open. |
| Visual consistency | 10 | Not applicable | No visual surface or design token changes; no screenshot acceptance is inferred from the design ratchet. |
| Performance/operations — noncritical for this bounded slice | 5 | 9.0 | The mutation is short, non-suspending and serialized; concurrent capture/retirement and bounded test teardown pass. No latency, lock-contention or device profiling was run, so this dimension is intentionally lower. The score does not certify the broader app's performance/operations. |

Applicable weight is **75**. The weighted result is `(25 × 9.7 + 25 × 9.6 + 20 × 9.7 + 5 × 9.0) / 75 = 9.62`, reported to one decimal place as **9.6/10**. Each applicable critical dimension independently meets 9.5. Performance remains 9.0 because the added tests supply no latency/contention/device profile. The three 0.1-point increases reflect the specific new evidence described above; no score was changed to waive a gate or accept an unresolved app-wide blocker.

## Deliberate policy tradeoff and unresolved boundaries

**A null, malformed or unsupported identity retains AMC payment recovery data because this slice cannot safely authorize a global deletion. This is deletion fail-closed behavior only; it is not confidentiality fail-closed behavior.** Existing global readers, `observe/list/verifiable`, producers, unowned `remove(orderId)` and startup reconciliation can still expose, mutate or process historical foreign-owner content. Retention therefore does not establish safe sign-out or isolation of the resource. The app candidate must remain blocked until those owner/read/reconciliation boundaries and the other required gates are addressed.

Further limits must remain in every handoff:

- Historical global keys may already contain another owner's recovery proof; ordinary valid A cleanup can delete those unowned historical records. No persisted owner/revision migration is introduced.
- Capturing at cleanup entry cannot repair a caller that became stale before invoking cleanup. A same-login newer write is not distinguished from older work by this ticket alone.
- A boundary missed by both observer and every probe remains undetectable if the final raw identity is identical. This is not universal ABA protection or a server authorization mechanism.
- The SDK session provider is not atomically locked with storage. The tested same-delegate ordering is essential, not a claim that the monitor freezes all application state.
- Remote token capture, outbox, other payment stores, photos, preference/cache cleanup, notification teardown, realtime and final SDK logout remain outside this slice. S3 recovery and broader payment/integrity/visual/device/provider/release work remain open.
- The remaining unguarded `clearAll` and other store APIs are not accepted as owned operations. Production cleanup now uses the guarded API; later callers must not treat the old method as a safe substitute.

No additional app change is requested by this source review. The final rating applies only to the described successor-login AMC deletion boundary; it cannot authorize merging the broad app draft to main or releasing it.
