# Independent QA — authentication integration

Review owner: `qa_critic_review`. Review started 2026-09-11 against `8749ff71d98bc418ea66f096fd6d1982baf05a17` on `codex/auth-integration-20260911`. No production/test edits, Gradle execution, merge, commit, real account or device operation by this reviewer. Root owns implementation and the laptop build slot; the separate critic is `auth_a1_redteam`.

**Current disposition: A2 and A10 final integration acceptance pending.** Prior passing component tests remain useful evidence; they do not waive the A2 dark-theme correction or the A10 publication/admission gaps below. No final numeric score is assigned before the final candidate and executable evidence arrive.

## Findings requiring disposition before local acceptance

1. **A10 queued auth-observer gap.** `DeepLinkHost.kt:103–126` checks cancellation and the locally observed owner/revision after a fetch, but never checks the current auth source at publication. If A's result continuation is queued first and upstream becomes B or Unknown before that continuation runs, A's status can publish before the auth collector clears it. Existing replacement tests run the auth observer before releasing A, then inspect settled `.value`; they cannot exclude that transient emission. This is distinct from an entire same-user ABA boundary lost upstream. A current-auth admission check can address observable lag; repository-level stable login identity is still needed for wholly unobserved ABA. The helper handoff must not combine these as the same unavoidable limitation.
2. **A10 fetched-row ownership is unchecked.** A successful `fetchByUserId(A)` returning an `Engineer` whose `userId` is B currently supplies its verification status. The production repository filters by `user_id`, but this ViewModel boundary lacks the matching-result defense and executable negative. Require a mismatched-row negative plus a subsequent valid recovery. This is a source-level finding at this revision, not a claim of an executed server exploit.
3. **A2 dark-theme contrast remains a required closure.** The saved RoleSelect button fixed its green background while inheriting dark `onPrimary`, yielding 2.378:1. Root is implementing an explicit foreground and real dark render/contrast checks. The earlier nine images force light theme and cannot close this gap. Review must bind to the corrected source and newly executed images/tests.

No new production navigation-policy or mapper defect is established by the helper's mapper tests. The previously documented A3 verbatim intent and cross-account replay paths remain outside these component fixes and block any full-auth/security acceptance.

## Frozen additional acceptance checks

| Check | Required evidence |
|---|---|
| A10 observed-owner regression | Retain all 23 helper cases: sign-out/reset, same-ID relogin, A→B→A, cooperative/noncooperative cancellation, fresh retry, missing/failed rows, duplicate/email events, invalid IDs, Unknown retirement and newest manual revision. |
| A10 queued publication | Collect **every** status emission with an immediately scheduled collector. Queue A completion before B, SignedOut and Unknown observation. No stale non-null status may emit; a valid current owner must still recover. Checking only the eventual `.value` is insufficient. |
| A10 queued admission | Exercise a queued initial/manual fetch around changed current auth, with explicit fixture ordering. No stale request may wait for or be admitted under a future login. Preserve the single long-lived auth-observer contract; any deliberate API change must be documented and tested. |
| A10 row identity | Mismatched/blank returned `Engineer.userId` yields null and does not inhibit a fresh correct-row retry. |
| A10 cleared host | Cleared scope cannot publish a late noncooperative result or open fresh work. |
| A2 final root contract | Re-execute the carried R01–R13 and role/recovery tests against the final merged source; preserve exact hashes/XML/logs. Root-entry lifetime, held-frame callback guards and pending Back remain part of that contract. |
| A2 contrast closure | Actual enabled role action in light/dark themes uses a sufficient foreground/background pair, renders readable text and retains click behavior. Preserve screenshot/color evidence; include dynamic theme if the claim covers it. |
| Integration regression | Final combined full unit/lint/debug/appropriately labeled release-assembly result, exact command/exit, source-before/after and archived XML/images. Signed release stays unassessed without a real signing gate. |

These checks are intentionally bounded. Actual post-KYC refresh wiring is not established: a current source search finds `refreshEngineerStatus()` only at its declaration and in tests. An isolated method test cannot certify a production KYC completion callback.

## Independently reconciled carried evidence

QA fully read the A10 source and new A10/notification test files, the helper handoff and regression notes, the carried A2 handoff/QA contract/report, and Claude's handoff. The helper's source blobs match the integrated checkout:

| File | Complete read span | Git blob / SHA-256 |
|---|---|---|
| `app/src/main/kotlin/com/equipseva/app/navigation/DeepLinkHost.kt` | 1–182 | `01ddb4fc42affce720b4f1f8462259e18671f1a1` / `81ea25bb9eff86798d7bad9689cca4a4f979257963cd17fb2d2452d96f426569` |
| `app/src/test/kotlin/com/equipseva/app/navigation/DeepLinkHostEngineerStatusTest.kt` | 1–508 | `47ff91597d110241d2e8874d8cc3e1155570b637` / `033e783f687386c00061a4498f75d0136adcb79c2b52ff484166fe43b2a0cdf1` |
| `app/src/test/kotlin/com/equipseva/app/navigation/NotificationDeepLinkEdgeCasesTest.kt` | 1–374 | `cb515185155a0afdaab8e9201e7bf5c33ad02264` / `c2c3afcd2b559dfaf0ec6ae6295a0a201e4e4bed567cc9c44677fe9ade46ab5a` |

These hashes describe the carried candidate, not any later correction. Full-file reading does not mean full DeepLinkHost/A3 security acceptance. A2's previous full-read manifest is retained under `docs/evidence/auth-a2/`; current changed files require fresh binding.

QA independently parsed the preserved helper XML under sibling `work/verification/gpt53-helper-20260911/`:

- `a10-review-red.xml`: 23 tests, two failures — extra manual auth subscription and cleared-host late publication.
- `a10-delayed-auth-red.xml`: one test, one failure — refresh before first auth emission awaited a future login.
- `a10-targeted.xml`: 23 tests, zero failures/errors/skips after those fixes.
- `notification-edge-cases.xml`: 22 tests, zero failures/errors/skips.
- `full-xml/`: **3,067 tests / 353 suites / zero failures/errors/skips**, before the last eight mapper tests. A 3,075 full-suite count was not executed by that helper run.
- `a10-release-strict.log`: actual failure at the missing-keystore guard with `PRECHECK_LOOSE=0`. This supports the handoff's explicit absence of signed-release/R8 success for that strict attempt.

The carried A2 handoff correctly supersedes the old report's in-progress full-build statement with the completed 3,030-test full bar, while retaining the unresolved dark contrast blocker. Helper and Claude handoffs make no numeric full-app acceptance claim. Their historical checkout/base references must remain labeled as historical after integration.

## Scope boundaries and score policy

Final scores will assess only the final executed A2 local routing/role component and A10 status component across correctness, owner/callback isolation, cancellation/concurrency, recovery/regression and evidence quality. Every applicable dimension must reach 9.5; no average can conceal a failed mandatory check. Pending execution is unassessed, not a passing score.

The 22 mapper tests characterize `(kind, strings) → route?`: they do not receive identity/role, authorize founder destinations, prove row ownership, run FCM delivery or verify caller inbox fallback. Claude's findings and accessibility inventory are static reviews/plans, not executed attacks, native layout validation or QA passes.

Open broader gates remain explicit: A3 intent/URI admission and event replay; A4 opaque repository/preference mutation ownership; A12 already-started global cleanup and live-user token revocation; A7 signup carryover; stable identity for wholly unobserved same-user boundaries; real provider/Auth/Storage/API integration; saved-state/process restoration; emulator workflows, TalkBack, native locale/IME/insets; signed release and production verification. Local A2/A10 acceptance will not close those gates or represent an app score.
