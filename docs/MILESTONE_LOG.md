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

## 2026-09-23 — Owner decision recorded: English only

- Owner instruction (verbatim intent): no Hindi or Telugu translations or words; everything in English; record it in the repository urgently. Recorded in `AGENTS.md` (standing product decisions), `CLAUDE.md`, `PRODUCT_PLAN.md`, `docs/CURRENT_STATE.md`, the delivery ledger, `PAGES_AND_WORKFLOWS.md` (N30 becomes theme-only), `AGENTS_READ_FIRST.md` and `UX_UPLIFT_PLAN.md`. Docs-only; no app code changed by this entry.
- Measured before acting (branch `claudedev-build-20260923`, base `70c06420`): `values/strings.xml` 760 keys; `values-hi` and `values-te` 759 keys each, of which **724 were byte-identical English copies** and 35 were translated. The locale directories are removed in the next code commit on that branch together with `localeFilters = en` and an English-only resource guard test replacing `StringsParityTest`.
- No test, build, review or release claim is attached to this entry.

## 2026-09-23 — Owner decision recorded: English only

- Owner instruction (verbatim intent): no Hindi or Telugu translations or words; everything in English; record it in the repository urgently. Recorded in `AGENTS.md` (standing product decisions), `CLAUDE.md`, `PRODUCT_PLAN.md`, `docs/CURRENT_STATE.md`, the delivery ledger, `PAGES_AND_WORKFLOWS.md` (N30 becomes theme-only), `AGENTS_READ_FIRST.md` and `UX_UPLIFT_PLAN.md`. Docs-only; no app code changed by this entry.
- Measured before acting (branch `claudedev-build-20260923`, base `70c06420`): `values/strings.xml` 760 keys; `values-hi` and `values-te` 759 keys each, of which **724 were byte-identical English copies** and 35 were translated. The locale directories are removed in the next code commit on that branch together with `localeFilters = en` and an English-only resource guard test replacing `StringsParityTest`.
- No test, build, review or release claim is attached to this entry.

## 2026-09-23 — claudedev-build-20260923: English-only cleanup and P2.2 region-catalog foundation implemented

- Branch `claudedev-build-20260923` off `main` `70c06420` (Claude). Commits: `a6e58067` values-hi/values-te removed, `localeFilters = en`, `EnglishOnlyResourcesTest` replaces `StringsParityTest`; `23cc3ac5` `core/data/location` — header reconciled to the measured catalog (36 States/UTs, 764 districts, 257 Telangana mandals), `CATALOG_VERSION`, `IndiaStateCodes` (36 LGD codes, no district codes), `IndiaRegionAliases`, `canonicalDistrict`, `parseLegacyCity`; `22d343ac` review fix pass (strict-by-default resolution, parser rewritten for the real `engineers.city` shapes with `knownState`, `KNOWN_MISSING`, alias pruning, guard hardening). No UI, schema, RPC or caller change; P1b files untouched.
- Verified: full `:app:testDebugUnitTest :app:lintDebug :app:assembleDebug` at `23cc3ac5` — **2,945 tests / 345 suites / 0 failures / 0 errors / 0 skipped**, lint 0 errors / 86 warnings / 2 hints, debug APK built; targeted 66 / 0 at `22d343ac`; full bar at `22d343ac`: 2,959 unit tests / 0 failures / 0 errors, lint 0 errors / 86 warnings / 2 hints, `assembleDebug` built. `assembleRelease`, Roborazzi and the design ratchet not run (no UI change; no Python on the machine).
- Independent reviews (read-only, rubric per the delivery ledger): round 1 critic **9.2, not accepted** (two majors: authority helpers defaulting to the embedded prefill step; stale parser premise) and QA **9.7, accepted for declared scope** with nine minor/nit items; every item mapped and addressed in `22d343ac`. Round 2 on `22d343ac`: critic **9.6 accepted**; QA **9.5 not accepted** on one new major in the parser (an unrecognised Geocoder label in the district slot let an earlier locality token become the district without confirmation) — fixed with tests in the follow-up commit 44b1dcbe (full bar: 2,964 unit tests / 0 failures / 0 errors, lint 0 errors / 86 warnings / 2 hints, `assembleDebug` built; round-3 confirmations: critic **9.7 accepted**, QA **9.7 accepted** for the declared scope (branch implementation only; remaining items are non-gating nits listed in the handoff)).
- Handoff: [HANDOFF_CLAUDEDEV_BUILD_2026-09-23.md](HANDOFF_CLAUDEDEV_BUILD_2026-09-23.md). Not main integration, not release acceptance; PR to be opened after the branch CI run is checked.
