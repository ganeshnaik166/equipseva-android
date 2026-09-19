# Independent review: M2/M4 fixes and Compose alignment

Reviewed the coordinator's uncommitted integration diff over `69034d84933c961e6f20c504da6f81158b9aed36` on 2026-09-19. This agent did not author the payment/SLA changes, edit source during this review, run Gradle, stage or commit. The UI patch remains frozen.

## Disposition and scores

No introduced correctness blocker found in the bounded M2/M4 source diff. The client changes match the checked-in server contracts, preserve successful fresh requests, and avoid replacing invalid or unconfirmed values with optimistic results.

| Dimension | Score | Exact scope |
| --- | ---: | --- |
| Critic / code review | 9.5 / 10 | Three changed AMC production files: cold-start proof recovery, submit-boundary SLA parsing, pending-confirmation copy |
| QA test-design review | 9.5 / 10 | Six relevant classes, 59 test inventory: recorded effects, cancellation/barrier cases, invalid/restored SLA submission, valid controls |

These are one independent reviewer's two bounded static-review dimensions. They are not an app, executed-QA, device, release, security-program, or Compose-upgrade acceptance score. Runtime acceptance is still pending the coordinator's frozen-tree run and applicable broader checks. Six additional M2 targets were added before the guards but have not demonstrated an independent RED run; that history is explicitly preserved by the implementation handoff.

## Evidence

- `PendingAmcPaymentsReconciler.kt:46-99`: active-coroutine checks surround status/verify continuation; paid and pending may replay existing proof; deletion requires ok, matching order ID and a nonblank ledger. Failed verification, missing proof, null/unknown status and malformed success retain evidence. Refunded/failed do not replay proof.
- `supabase/functions/verify-amc-payment/index.ts:179-198` binds the hospital and provider order. Lines 237-270 repair paid-without-credit and return an existing ledger for idempotent success; lines 287, 316-325, 345 demonstrate paid write, credit RPC, and returned ledger in the fresh path. This supports the new client policy without changing provider/server behavior.
- `AmcRepository.kt:143-150` decodes the actual `payment_order_id` and `ledger_id` fields. The stricter client guard is compatible with both server success paths.
- `CreateAmcWizardScreen.kt:440-474` parses the captured draft before busy state and before `createContract`, then passes those exact values. Lines 1343-1358 share the parser with the SLA step gate. The schema/RPC's integer-hour contract is explicit in `20260728000000_round477_amc_pending_payment_gate.sql:73-74` and the original table constraints.
- The 16 recovery targets call the real reconciler and observe proof/marker state and invocation order. They include paid/pending positive controls, idempotency, a genuinely entered suspended verification, cancellation, success returned into a cancelled coroutine, wrong order, false ok, null/blank ledger, absent proof, and terminal/unknown/null status.
- The 13 SLA targets call the real ViewModel's submit boundary, record repository arguments, and stop synthetically before checkout. They distinguish padded valid hours, invalid restored values for both fields, and a fresh corrected attempt; invalid input asserts no contract/launcher/payment-store side effects. These are stronger than parser-only mirror tests.
- The retention fixture correction compares nullable proof against its nullable starting state; it does not erase the requirement to retain existing proof. Older helper tests explicitly document the changed paid/null policy. No test was deleted, ignored or relabeled to claim acceptance.

## Nonblocking cleanup and remaining boundaries

1. **P3 — stale contract comments.** `PendingAmcPaymentsStore.kt:19-23` still says checkout always clears in finally; line 156 says a status-only sweep can resolve an unreadable proof. `AmcRepository.kt:259-262` still describes null as terminal marker deletion. Update these comments when the coordinator unfreezes edits; they contradict the new recovery policy and can mislead future maintenance.
2. **Explicit existing security boundary:** the pending stores remain global, not account-owned. This patch does not establish A4 ownership or safe account switching. Retaining an RLS-hidden marker avoids evidence destruction but does not solve the global-store boundary.
3. Paid without stored proof may remain unresolved even if already credited. The new support wording is appropriately cautious; there is no new authenticated ledger reader or foreground re-payment gate.
4. Actual DataStore persistence, server/provider execution, process death, localization/device presentation, the foreground verifier's looser response handling, M1 payout state monotonicity and M3 transient/refusal classification are outside this acceptance scope. No inference of payment-program readiness follows from these tests.
5. Follow-up test opportunities: status-fetch returning success into an already cancelled sweep and store-read/remove exceptions would directly cover the additional defensive branches. Their absence is a coverage limit, not an observed defect; the critical verify/cancellation boundary already has meaningful tests.

## Compose alignment review

The two-line configuration change has a supported cause: the coordinator recorded compile Foundation 1.7.6 against runtime 1.9.0 and a FlowRow linkage error. Pinning the whole existing BOM avoids a mixed API family. I independently read the [official 2025.08.00 POM](https://dl.google.com/dl/android/maven2/androidx/compose/compose-bom/2025.08.00/compose-bom-2025.08.00.pom): Foundation/layout, Runtime, UI, tooling and UI test are 1.9.0; Material3 is 1.3.2; material-icons-extended is intentionally 1.7.8. Not every artifact has to share a version number.

No obvious source-level incompatibility was found. Remaining upgrade risks/gates:

- Recompiling against Foundation 1.9 changes indication expectations for clickable/selectable/toggleable overloads. No custom LocalIndication, legacy Indication implementation, rememberRipple or LazyLayoutCacheWindow use was found under app/src. AGP 9.2.1 exceeds the documented 8.8.2 lint floor. See [Foundation 1.9 release notes](https://developer.android.com/jetpack/androidx/releases/compose-foundation#1.9.0).
- This is still an app-wide UI dependency change. Material3 1.3.2 corrects list intrinsic height, navigation-label padding and RTL tab layout, so generated previews and checked-in screenshot gates require review rather than automatic re-recording. See [Material3 1.3.2 notes](https://developer.android.com/jetpack/androidx/releases/compose-material3#1.3.2).
- The native Back bypass persists in the [official Material3 1.3.2 sources](https://dl.google.com/dl/android/maven2/androidx/compose/material3/material3-android/1.3.2/material3-android-1.3.2-sources.jar): ModalBottomSheet lines 156-165 call hide before dismissal; SheetDefaults lines 195-201 do not consult the predicate. The explicit dialog Back guards remain necessary after the BOM change.
- Enforced constraints apply broadly; verify resolved compile/runtime families for debug, unit tests and release. Test/Android-test platform declarations share the same version but dependency-report evidence is still needed for the final configurations. A passing focused JVM run alone does not verify device Back/IME behavior, screenshot parity, release linking/shrinking or the complete app.

At review time `fixes-target-2.log` had reached unit-test compilation; no completed result was available to this reviewer. No build result is invented here.
