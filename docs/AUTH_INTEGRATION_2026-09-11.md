# Auth integration slice — 11 September 2026

Candidate branch `codex/auth-integration-20260911`, isolated at
`C:/Users/lokes/Documents/Codex/2026-09-07/im/work/equipseva-auth-integration-20260911`.
Started from coordinator base `1e770076358e74f6f40a99a4907f831da59e791c`.
Integrated GPT helper `a9b35f3c55b1750f9bc2a51ed802e7acd94b6bca` first, then
Claude review `0d4269ea70d2fd2f87addcc9c0c4e6325b19c4aa` in merge `8749ff71`.
Prior checkouts and their untracked evidence remain intact.

## Frozen scope and review gate

Finish the saved A2 button contrast blocker and independently review A10 before
later A3 changes DeepLinkHost. Production edits in this slice are limited to
RoleSelectScreen's button colors and DeepLinkHost's engineer-status ownership.
No new auth policy, route, repository mutation, dependency or production
deployment belongs to this slice. Existing A2 root/role/auth regression selectors
remain mandatory. A2 is assessed as a bounded local component/routing slice;
A10 is assessed separately as local status isolation. Neither is a full-auth,
whole-app or release rating.

Independent critic and QA must each reach at least 9.5/10 on the final candidate
and every applicable critical dimension, following RENEWAL_EXECUTION_PLAN and
AUTH_A2_QA_CONTRACT. A failed required case or missing applicable evidence blocks
acceptance regardless of an average. Root does not assign its own passing score.

## Added requirements before production corrections

- A2: actual production Compose renders in light and dark mode must keep enabled
  Save, Try again and Check again text at least 4.5:1 against the drawn button.
  The initial dark-mode render reproduced 2.378:1; light mode measured 6.255:1.
- A2: preserve readable disabled/no-selection and Saving labels in both modes.
  The same 4.5:1 target is a deliberate readability rule for this component;
  it is not a claim that every accessibility standard requires disabled-control
  contrast. Existing scroll, localization, action and semantics checks remain.
- The contrast oracle uses production TextLayoutResult, the drawn button pixel
  and actual composited glyph pixels. The first harness incorrectly matched
  translucent foreground values directly to opaque pixels; its two disabled
  oracle failures are preserved separately from the real enabled-dark failure.
- A10: record every status emission while an A response is queued ahead of the
  full observer but raw auth has changed to B, SignedOut or Unknown. No stale
  non-null publication is allowed. Apply the same ownership test before starting
  a queued manual fetch. This observable lag is not excused as unobserved ABA.
- A10: a response with a different Engineer.userId must not grant that row's
  verification status; valid same-owner retry must still work.
- A10: the auth interface remains Flow. A current-auth probe, if needed, must
  finish immediately or be cancelled and fail closed; it must never park a
  manual refresh awaiting a future account. The helper's implementation-specific
  “never second subscription” oracle is replaced before production changes by
  this stronger no-pending-probe/no-future-account-work contract. Delayed sources
  remain fail closed; actual mapped StateFlow behavior has explicit coverage.

## Unchanged open program gates

A3 verbatim external routes, privileged-route admission and buffered replay;
A4/A12 global cleanup/device-token ownership; wholly unobserved same-ID login
boundaries; provider/Storage/FCM integration, real device/TalkBack/IME/locales and
human usability; production signing/configuration. An unsigned R8 assembly is
compile/shrink evidence only. Strict release guards remain intact.

Claude's A3 plan is a proposal to reconcile with source before implementation.
In particular its cold-start table says at most one pending event while
T-A3-02c expects two events in order; signed-out drop versus authenticated cold
bootstrap also needs an explicit frozen boundary. No route policy is silently
introduced by accepting this A2/A10 slice.

Final commands, failures, hashes, local evidence, reviewer ratings and delivered
head will be recorded in `docs/evidence/auth-integration/verification.json` and
the independent `critic-review.md` / `qa-review.md` after verification.
