# EquipSeva milestone and checkpoint log

Append dated results. Keep design, implementation, main integration and release evidence separate. The latest resume pointer lives in [CURRENT_STATE.md](CURRENT_STATE.md).

## 2026-09-19 — P0 product plan published

- Main: `24e0199937c09c137e8045aa7664dcd4f746dbb1`; content: `5541df8f43d656951bf53197f74da5a7b0291768`; PR1879 merged.
- Master plan, 98 existing screens/30 proposed surfaces, architecture/migration, security/billing/fraud, delivery ledger and seven-page PDF. README links them first.
- Planning critic 9.5/10; QA 9.6/10. Eight Markdown documents/19 local links checked; all seven PDF pages visually inspected. Android and secret-scan push/PR checks passed. No application acceptance implied.

## 2026-09-19 — registration/region preparation saved

- Code: `d202cb385d98d3ba6562b194d10294eebec0d60d`; evidence head: `faa2d03e8dddddcc39b02b75eb0b1fab36b77947`; draft PR1877 remains blocked.
- Four files: unused three-purpose registration intent and dependent state/district draft plus tests. No backend role, UI, entitlement or canonical-region migration.
- RED: 24 tests/14 assertions failed against deliberate stubs; GREEN: same tests plus compatibility controls, 45/0. Lint/design/debug/unsigned R8 passed. Full suite: 3,699/3 known cleanup failures, zero errors/skips. See the immutable handoff linked from CURRENT_STATE for exact commands, retry details and artifact hashes.
- Independent bounded critic 9.5, QA 9.6. Existing S1/S3/money/integrity/visual/release gates retained.

## 2026-09-19 — continuity contract and P1a scope opened

- Owner explicitly requested model-independent milestone/handoff updates and persistent progress memory.
- `AGENTS.md` defines mandatory entry and save steps; CURRENT_STATE gives verified references; this log preserves outcomes. Portable repository records take precedence over private model memory.
- Local app checkpoint `e6d0233eba06da209a878aefed0c0739f7890408` syncs the approved plan without app source changes. Two documentation conflicts were resolved by preserving both font/PDF attributes and historical UX evidence below the governing plan.
- Next slice: P1a AMC cleanup deletion safety, real DataStore tests first. Design is in progress; no new application result or score is claimed by this entry.

## 2026-09-20 — P1a AMC deletion boundary verified and handoff saved

- Branch `codex/quality-integration-20260919`, draft PR1877. Base `3c61469927b01bb0592ff501a8af42f401c937a2`; production/test implementation `434663c044460104ce7ebbc60029ac9e6ee90d28`; test-only polish `8d80ba3c85a9dd833d08930f8b7728f9c485247c`. Later documentation/merge commits do not change these verified inputs.
- Capture an independently issued login ticket before the first cleanup suspension; validate inside the real AMC DataStore transform before deleting marker/proof together. Filename, keys and other payment APIs remain unchanged. Ten source/test files across both commits; no UI, schema or dependency change.
- Behavioural RED: 47/26 assertions failed; identical tests after implementation: 47/2. QA initially rated 9.3, unaccepted. Five direct exception/cancellation tests and an immediate persisted reread before any new write closed its named evidence gaps. Targeted polish: **52/2**, zero errors/skips; launch HEAD434663c0 plus frozen test edits subsequently committed as8d80ba3c.
- Full unit at8d80ba3c: **3,734 tests / 426 suites / 2 failures / 0 errors / 0 skips**, command `:app:testDebugUnitTest --no-daemon --console=plain`, exit1. Both failures remain `SignOutCleanupLocalBoundaryRegressionTest`: token capture after delayed draft cleanup and B's outbox row erased by A. No test was deleted or disabled.
- Earlier combined `:app:testDebugUnitTest :app:lintDebug :app:assembleDebug :app:assembleRelease --continue --no-daemon --console=plain` at434663c0:3,729/2, lint0errors/89warnings/2hints, debug/design/unsignedR8 passed. Those build checks were not repeated for tests-only polish; production/build inputs are unchanged. `PRECHECK_LOOSE=1`, missing signing/certificate and observed Crashlytics mapping-upload caveats remain. Unsigned output is not release acceptance.
- Final independent [critic](helper-reviews/codex-20260919/p1a-critic.md) **9.6**, [QA](helper-reviews/codex-20260919/p1a-qa.md) **9.6**, scoped to newer committed AMC data surviving stale cleanup. Initial reports preserved; no full S1/confidentiality/app/release acceptance. The full suite remains non-green.
- [Detailed handoff](HANDOFF_P1A_AMC_CLEANUP_2026-09-19.md), CURRENT_STATE, delivery ledger and CLAUDE entry pointer make the checkpoint portable. README's obsolete latest-handoff label is corrected. These safe docs can reach main separately; the broad app draft must not merge to publish them.
- Next: **P1b real Room outbox deletion safety**, not started. Freeze file ownership, add real transaction-admission races and ordinary/fresh-write controls, then guard the existing captured ticket inside the admitted transaction. Preserve token, other resource, global confidentiality, S3, money/integrity, visual and device/provider/signing gates.

## 2026-09-20 — P1b pre-fix WIP saved at usage threshold

- Branch `codex/quality-integration-20260919`, draft PR1877 stays blocked. Base `f7608644728a20bc24aa2fa74e75c3817a461fcd`; frozen code/test `1493b870092b934d0bd0b7f10ab05631a0c74137`, seven files. New Room cleanup adapter deliberately retains unsafe pre-fix deletion, with nine new tests and a real-Room upgrade of the older regression harness; three other fixtures change constructor/mock wiring only.
- Targeted RED: **61 tests / 8 suites / 8 failures / 0 errors / 0 skipped**, exit1, 2m22s. New class9/6 includes five safety assertion failures and one unresolved SQLite-locking fixture result; original integration class5/2 retains token/outbox failures. Other47 tests pass. All twelve manifest hashes match. The locking result is not behavioural RED acceptance; full command and exact limits are in [the P1b handoff](HANDOFF_P1B_OUTBOX_CLEANUP_2026-09-20.md).
- Stopped opening work at the owner's usage threshold. No implementation, new full unit/lint/debug/release execution or final critic/QA review followed. P1a's prior9.6 ratings do not apply to P1b. No main merge or release. Shared Gradle slot released after the running wrapper finished.
- Next: diagnose the precommit-cancellation fixture's SQLite lock without weakening it; re-establish RED; implement ticket check and cancellation check after actual Room transaction admission; unchanged targeted/full applicable checks and separate critic/QA reviews. Preserve token-capture and wider ownership/release blockers.

## 2026-09-23 — Owner decision recorded: English only

- Owner instruction (verbatim intent): no Hindi or Telugu translations or words; everything in English; record it in the repository urgently. Recorded in `AGENTS.md` (standing product decisions), `CLAUDE.md`, `PRODUCT_PLAN.md`, `docs/CURRENT_STATE.md`, the delivery ledger, `PAGES_AND_WORKFLOWS.md` (N30 becomes theme-only), `AGENTS_READ_FIRST.md` and `UX_UPLIFT_PLAN.md`. Docs-only; no app code changed by this entry.
- Measured before acting (branch `claudedev-build-20260923`, base `70c06420`): `values/strings.xml` 760 keys; `values-hi` and `values-te` 759 keys each, of which **724 were byte-identical English copies** and 35 were translated. The locale directories are removed in the next code commit on that branch together with `localeFilters = en` and an English-only resource guard test replacing `StringsParityTest`.
- No test, build, review or release claim is attached to this entry.

## 2026-09-26 — P1b committed Room outbox deletion safety locally accepted

- Branch `codex/quality-integration-20260919`, draft PR1877 blocked from main. Corrected test fixture `0c2572c7c8285a823a9a1f0a35f1b46c2af469cc`; production guard `5b5fa68b7475049b2d409f82689cc858d75837ed`; bounded setup timeout and KDoc correction `ed9de0c38a13e22d2c0777eaf2321cd08932e77f`. The exact frozen code/test SHA for final verification and reviews is `ed9de0c3`.
- The cleanup enters the real Room write transaction, checks cancellation and the first-operation exact session ticket after admission, then calls the existing suspend DAO deletion. No schema/DAO/dependency change. Nine new real file-backed Room/SQLite tests exercise both transaction orderings, persisted successor rows, stale/null/replaced tickets, cancellation, rollback and ordinary cleanup; the existing B-outbox regression remains enabled.
- Corrected behavioural RED: **61 tests / 7 assertion failures**, exit1 with the unsafe implementation. Targeted guard result: **61 / 1 failure** (only the separate token-capture assertion). First full run: **3,743 / 2 failures**, including that assertion and a 10-second cold Room fixture timeout before the B-row test body. Test-only follow-up raised real fixture I/O bound to 30 seconds without changing assertions. Final full combined command `:app:testDebugUnitTest :app:lintDebug :app:assembleDebug :app:assembleRelease --continue --no-daemon --console=plain`: **3,743 tests / 427 suites / 1 failure / 0 errors / 0 skips**, exit1. All P1b tests, including the B-row case, pass; only the original A-to-B token-capture regression fails. Lint has 0 errors/91 warnings/2 hints; debug and unsigned R8 release assembly pass. Twelve source/test hashes match the final run manifest. The design ratchet passed with no negative signal above baseline at the same executable production source.
- Independent [critic](helper-reviews/codex-20260926/p1b-critic.md) **9.6/10** and [QA](helper-reviews/codex-20260926/p1b-qa.md) **9.6/10** accept only successor-login committed outbox deletion safety. The full unit gate, wider S1/S3, app integration and signed release remain blocked. Room tests used native SQLite, not SQLCipher/device/provider evidence. See the [P1b handoff](HANDOFF_P1B_OUTBOX_CLEANUP_2026-09-20.md) and external `outputs/p1b-outbox-cleanup-20260920/` artifacts for exact evidence and limitations.
- Synced the owner's 23 September English-only main documentation into this candidate without changing app source. The P1b candidate checkpoint was pushed; its six safe continuity records reached main through PR1883. An independently owned P1c token-capture slice followed. The broad app candidate remains blocked from main and production release.

## 2026-09-26 — P1c departing token capture and draft ownership locally accepted

- Branch `codex/quality-integration-20260919`, draft app PR1877 remains blocked. P1b base `11b43ee97a15afde2cf62d796f8905cbe33164dc`; P1c scope commit `a680f88da30914a8029a0940144712b39b2dd2c4`, test-first commits `0b957335` and `78a912de`, production `ed7a5397`, final test-only fixture/disk closure `04aa5729f8d2ec7a1d5e3381178f2a334904c61a` (exact full-run HEAD). Local P1c acceptance is not main integration or release.
- Sign-out captures one exact login ticket before suspension, synchronously fences only that login's draft lease, reads its installation token with ticket validation before/after the suspending DAO call, then clears the matching draft inside DataStore's admitted edit. Cancellation now stops later best-effort global steps. No Room/schema, UI, auth repository or backend change.
- Test-first API RED was missing-method compilation with **zero tests executed**. Four added cancellation cases produced behavioural **47 tests / 2 failures** on the intermediate implementation; the unchanged focused set became **47/0**. The first full run **3,761/2** exposed an existing integration fixture's relaxed ownership mock and both real-disk A-deletion assertions. Test-only `04aa5729` supplied a real matching ownership monitor without removing assertions and added four actual file-backed DataStore timing/rollback/reopen tests. Expanded focused run **59 tests / 9 suites / 0 failures/errors/skips**.
- Final combined `:app:testDebugUnitTest :app:lintDebug :app:assembleDebug :app:assembleRelease --continue --no-daemon --console=plain` at `04aa5729`: **3,765 tests / 429 suites / 0 failures / 0 errors / 0 skips**, exit 0. Lint 0 errors/91 warnings/2 hints, debug and unsigned R8 release assembly pass. Design ratchet passes; all 13 source/test hashes match the run manifest. `app-release-unsigned.apk` is not a signed release; device/FCM/provider and deployed-grant checks remain open. Crashlytics logged a mapping upload without an independent provider receipt.
- Independent [critic](helper-reviews/codex-20260926/p1c-critic.md) **9.6/10** and [QA](helper-reviews/codex-20260926/p1c-qa.md) **9.6/10** accept only this local token/draft/cancellation boundary. [Detailed handoff](HANDOFF_P1C_TOKEN_CAPTURE_2026-09-26.md) records exact evidence and limits.
- Mandatory wider blocker: tracked migration `20260428320000_security_revoke_delete_grants.sql` denies client `device_tokens` DELETE while Android still calls DELETE before registration upsert and for logout. Live grants were not queried. Next P1d-0 sender-only privacy/error-classification tests and fix; P1d-1 claim/release SQL needs actual schema and disposable concurrency tests. No broad app candidate merge or production release from this checkpoint.

## 2026-09-26 — separate Sharp advisory candidate, review pending

- Isolated branch `codex/security-sharp-20260926` from fetched main `6a6b224681d3595b3c358a029e056e74496bac67`; tested code commit `15726a634fe9c6d36516f07c4b92df9314b4718d`. Previous Dependabot PR1867 was not merged.
- `web/package-lock.json` alone changes 27 Sharp-related entries: Sharp 0.35.3 to 0.35.4 and bundled libvips 1.3.2 to 1.3.3. Manifest and all other locked packages remain unchanged.
- Local Node 24/npm 10.8.2: `npm ci` installed 101 packages, typecheck passed, DataTable smoke passed and Next production build passed (all exit 0). Installed Sharp reports libheif 1.23.2. GitHub CI uses Node 20/Linux and remains pending at this checkpoint.
- Independent critic/QA and CI still required before scoped acceptance or main merge. See [the detailed handoff](HANDOFF_SHARP_SECURITY_2026-09-26.md). This does not accept the whole P7.2 dependency ledger or Android app.
