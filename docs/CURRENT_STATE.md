# EquipSeva — current work and resume point

Updated 20 September 2026. Read this before coding; verify branch/HEAD and remote state rather than assuming this dated snapshot is still latest.

## Where we are

| Record | Exact checkpoint | Meaning |
|---|---|---|
| Main product plan | `24e0199937c09c137e8045aa7664dcd4f746dbb1`, [PR1879](https://github.com/ganeshnaik166/equipseva-android/pull/1879) merged | Governing four-persona plan, 98 existing-page dispositions, 30 proposed surfaces and seven-page PDF; Android and secret-scan push/PR checks passed |
| Portable continuity contract | `62da836f101e6ba2ac1497cbdc8ae933e1fa3543`, [PR1880](https://github.com/ganeshnaik166/equipseva-android/pull/1880) merged | Mandatory model entry/save contract, current-state pointer and milestone log |
| Frozen app implementation | `434663c044460104ce7ebbc60029ac9e6ee90d28`, branch `codex/quality-integration-20260919`, [draft PR1877](https://github.com/ganeshnaik166/equipseva-android/pull/1877) | P1a successor-login AMC deletion safety; broader integration remains blocked |
| Test-only review polish | `8d80ba3c85a9dd833d08930f8b7728f9c485247c` | Five direct exception/cancellation tests and immediate disk reopening after cancelled cleanup; production unchanged |
| Scoped result / next slice | **P1a accepted locally; P1b next, not started** | Targeted 52/2; full 3,734/2. Final critic **9.6**, QA **9.6** for successor-login AMC deletion safety only; broader candidate remains blocked |

P1a base was `3c61469927b01bb0592ff501a8af42f401c937a2` after syncing main's plan and continuity records. The frozen code SHA above is distinct from later documentation/merge commits; fetch and inspect current HEAD before writing. Read [the P1a handoff](HANDOFF_P1A_AMC_CLEANUP_2026-09-19.md) for scope, files, executed commands and limitations. The shared Gradle slot was released after verification; always recheck it before a new run.

This handoff can be published on main separately from app code. P1a implementation and its tests remain on the candidate branch/draft PR; a copy of this document on main is not app integration or release acceptance.

Current app checkout on this laptop: `C:/Users/lokes/Documents/Codex/2026-09-07/im/work/equipseva-quality-integration-20260919`. The old coordinator (`equipseva-auth-integration-20260911`) and helper worktrees are preserved. Do not use a guessed checkout or silently transfer their changes.

## Owner decisions after the plan

- **23 September 2026 — English only.** The owner wrote: "no need of Hindi, Telugu translations or words, all should be in English; update this in GitHub memory urgently." Recorded in [AGENTS.md](../AGENTS.md) (standing decisions), [PRODUCT_PLAN.md](../PRODUCT_PLAN.md), the delivery ledger, the page plan and the UX plan. Consequence for code: `app/src/main/res/values-hi` and `values-te` are deleted and `localeFilters` is `en` only (branch `claudedev-build-20260923`; measured before deletion: 724 of 759 hi/te entries were verbatim English copies, so devices set to Hindi/Telugu had been seeing a mixed 35-word translation). Nobody should start translation, language-picker or locale-config work.

## Parallel branch: `claudedev-build-20260923` (Claude, opened 23 September 2026)

Based on `main` `70c06420`; pushed to origin under that name; no PR yet. It does **not** touch the P1b files (`SignOutCleanup`, `OutboxSignOutCleaner`, the local-boundary regression tests) or any billing/SQL. Handoff with commands, counts and both review rounds: [HANDOFF_CLAUDEDEV_BUILD_2026-09-23.md](HANDOFF_CLAUDEDEV_BUILD_2026-09-23.md).

| Slice | Files owned on this branch | Status |
|---|---|---|
| English-only resource cleanup | `app/src/main/res/values-hi/**`, `values-te/**` (deleted), `app/build.gradle.kts` `localeFilters` line, `app/src/test/kotlin/com/equipseva/app/i18n/EnglishOnlyResourcesTest.kt` (replaces `StringsParityTest`), `docs/ROADMAP_v05.md` annotation | **implemented + locally verified** at `a6e58067`, hardened in `22d343ac` |
| P2.2 client foundation: bundled region catalog reconciliation, LGD State/UT codes, legacy aliases, needs-confirmation parser | `app/src/main/kotlin/com/equipseva/app/core/data/location/**` and its tests only; no UI, schema, RPC or caller change | **implemented + locally verified** at `23cc3ac5`, review fix pass `22d343ac` |
| KYC prefill adoption of the catalog parser | `app/src/main/kotlin/com/equipseva/app/features/kyc/KycViewModel.kt` — ONLY the `hydrate()` legacy-city parse block and the reverse-geocode label match inside `onServiceCoordsChange()` (both outside every hunk the Codex candidate touches in that file); `app/src/test/kotlin/com/equipseva/app/features/kyc/KycViewModelTest.kt` additions | **implemented + locally verified** at `6492070e` (full bar 2,971 / 0, lint 0 errors); reviews: __REVIEW4__ |
| Location round-3 nits | `core/data/location/LegacyCityParse.kt`, `IndiaRegionAliases.kt` and their tests only | **implemented** in `6492070e` |
| N01 registration-intent chooser, prepared and unwired (P3 preparation the delivery ledger explicitly allows: "a separate three-option public registration-intent type … must not extend the backend UserRole enum, issue add_role, claim an organisation membership, persist a subscription entitlement, or navigate into a fake admin workspace") | Cherry-pick of the Codex candidate's `d202cb38` (identical content: `features/auth/PublicRegistrationIntent.kt`, `core/data/location/RegionSelectionDraft.kt` and their two tests) so both branches merge cleanly; new `features/auth/RegistrationIntentContent.kt` (pure composable, no ViewModel, no navigation, not reachable from any route); new `registration_intent_*` string resources in `values/strings.xml`; new `features/auth/RegistrationIntentContentUiTest.kt` (Robolectric, no screenshot golden) | in progress (opened 23 September 2026) |

Verified: full bar at `23cc3ac5` — 2,945 unit tests / 0 failures, lint 0 errors / 86 warnings / 2 hints, `assembleDebug` built; targeted 66 / 0 at `22d343ac`; full bar at `22d343ac`: 2,959 unit tests / 0 failures / 0 errors, lint 0 errors / 86 warnings / 2 hints, `assembleDebug` built. Reviews: round 1 critic 9.2 (not accepted: two majors, both fixed in `22d343ac`) and QA 9.7 (accepted for declared scope); round 2 on `22d343ac`: critic **9.6 accepted**; QA **9.5 not accepted** on one new major in the parser (an unrecognised Geocoder label in the district slot let an earlier locality token become the district without confirmation) — fixed with tests in the follow-up commit 44b1dcbe (full bar: 2,964 unit tests / 0 failures / 0 errors, lint 0 errors / 86 warnings / 2 hints, `assembleDebug` built; round-3 confirmations: critic **9.7 accepted**, QA **9.7 accepted** for the declared scope (branch implementation only; remaining items are non-gating nits listed in the handoff)). This is implementation on a branch, not main integration or release acceptance. Next for this line of work: KYC caller adoption of `parseLegacyCity` / `canonicalDistrict` (KYC file owner), then the coded LGD district import (P2.2 proper).

## Product direction

Three public purposes: biomedical engineer, hospital administrator, engineering team/organisation. Platform owner is private and separately provisioned. Paid team administrators have authority within their own organisation; subscription is not a global role grant. Independent engineers retain their personal workspace. Use India State/UT and district, with no-map target workflows; existing GPS/server contracts still require a tested migration. Preserve lime/ink/soft-white and Space Grotesk/Inter. **English only** (owner decision 23 September 2026): no Hindi/Telugu translations, words, locale resources or language pickers anywhere. Demo is local synthetic data; digital team subscription and physical service payments are separate. [PRODUCT_PLAN.md](../PRODUCT_PLAN.md) governs details.

## Verified evidence and open gates

- Latest full run at `8d80ba3c`: **3,734 tests, 2 failures, 0 errors, 0 skipped**. P1a targeted: **52/2**, with all ownership/AMC assertions passing and original token-capture/outbox assertions still failing. Both commands exit 1; app-wide acceptance stays blocked. Thirty-five tests were added to the 3,699 baseline; the original payment-marker regression now passes.
- New intent/region preparation: 24-test stub RED (14 assertion failures); unchanged tests GREEN 45/0 with compatibility controls. Critic 9.5, QA 9.6 for these four files only; types are not wired into live UI/permissions.
- Lint (0 errors, 89 warnings, 2 hints), design ratchet, debug and unsigned R8 passed at `434663c0`. The later polish changes tests only; those earlier build results apply to identical production/build source, not a newly run assembly. Unsigned signature verification correctly fails. The existing Crashlytics finalizer reported a mapping upload; strict signing/certificate/Sentry/device/provider acceptance is still open.
- Earlier visual record: 116 changed comparisons; only two individually inspected. Do not replace goldens or lower thresholds to turn this green.
- Remaining gates include S1 local cleanup/token capture, S3 logout recovery, M1 payout ordering, M3 provider retry classification, bound integrity enforcement, dependency disposition and full device/provider/human/release validation.
- Planning critic 9.5 and QA 9.6 apply only to the plan. No passing app-wide or security-certification score is claimed.

## Next concrete action

Read the [latest app handoff](https://github.com/ganeshnaik166/equipseva-android/blob/faa2d03e8dddddcc39b02b75eb0b1fab36b77947/docs/HANDOFF_WORKSPACE_FOUNDATION_2026-09-19.md) and [existing S1 boundary plan](https://github.com/ganeshnaik166/equipseva-android/blob/faa2d03e8dddddcc39b02b75eb0b1fab36b77947/docs/helper-reviews/codex-20260919/signout-ownership-plan.md).

P1a's test-only polish is complete. [Critic](helper-reviews/codex-20260919/p1a-critic.md) and [QA](helper-reviews/codex-20260919/p1a-qa.md) independently accepted the bounded deletion guarantee at **9.6/10 each**. QA's initial 9.3 was corrected through executed exception/cancellation, separate-thread monitor reuse and immediate disk-reopen checks. Initial reports are preserved with the evidence. Original production remains frozen at the recorded SHA. Original behavioural RED was 47/26 → 47/2 with unchanged tests; the five new review tests and additive cancellation assertion are separately disclosed.

Next implementation slice is **P1b: real Room outbox deletion ownership**, not yet started. Record its file ownership here before coding. Write tests first for both transaction-admission orderings and fresh enqueue/ordinary cleanup controls. Reuse the captured ticket but validate after entering the actual Room write transaction; a precheck before `clearAll` is insufficient. Do not remove either remaining regression. Token capture and final SDK logout still need their own owned orchestration; changing their order alone is not acceptance.

This bounded slice must not be presented as S1 completion: Room, other stores, photo producers/readers, preferences, token capture, realtime teardown and final SDK logout remain separate ownership boundaries. Do not touch billing, production SQL or unrelated UI while fixing this slice.

## Continuity rule

Update this file, the [milestone log](MILESTONE_LOG.md), affected [delivery ledger](product-plan/DELIVERY_LEDGER.md) row, detailed handoff and supported model memory after every milestone/checkpoint. Future entries must use observed results and exact revisions. Never copy private memory or secret logs into Git. Website development remains paused.
