# A1 review ledger addendum — 10 September 2026

Candidate: `d140c19b20bb0a6e458df0f0a8b4f7b233b78876`.
Independent QA rechecked the frozen review hashes and retained evidence during
checkpoint maintenance. No new Gradle run or production edit was needed.

| File | Reviewed lines | Audit disposition |
| --- | --- | --- |
| SessionViewModel.kt | 1–339 | Full source read; Partial disposition due to integration/recovery boundaries |
| SessionViewModelIdentityTest.kt | 1–799 | Complete test-code review only |

QA scored all six bounded A1 dimensions 9.5. Critic/red-team scored 9.6–9.8.
Their frozen source hashes match the committed files. These scores apply to
observed-login ownership, effect admission, request ordering, cancellation,
coherent gates, preference-failure handling, and focused regression evidence.

Preserved author XML: 43 identity + 4 preference tests, zero failures/errors/skips.
Root forced rerun: 47 tests, all 45 Gradle tasks executed. Current full XML was
recounted at 2,951 tests / 345 suites, zero failures/errors/skips. Lint, debug and
CI-mode release assembly logs are green; Android CI and secret scan passed.

Source SHA-256: `202e145a53728af7badefb46df913bc0e1669b5b31e49285e0443a986afcb557`.
Test SHA-256: `cfb107574b96311b1f3cbde1036b7ed7b2bef144b401fb10090efe1492fa4d72`.

The CSV's stale VM row was updated and the missing test row added. Other rows
retain their historical commit/hash provenance; no refreshed whole-program
denominator or full-app acceptance is claimed. Pre-update records remain in history/.

Still open: repository identity for unobserved same-user boundaries; already-started
opaque cleanup/sign-out/token work; root account-owned rendering; authoritative
role-writer refresh; visible offline/storage recovery; and device/integration gates.
