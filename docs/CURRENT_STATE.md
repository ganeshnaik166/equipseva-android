# EquipSeva — current work and resume point

Updated 26 September 2026. Read this before coding; verify branch/HEAD and remote state rather than assuming this dated snapshot is still latest.

Historical 21 September resume: the owner explicitly authorised using the remaining allowance, overriding the earlier threshold stop for that session. Base `144dac5a44cc1c115f50470fe8331416e261748c`, fetched and clean. The coordinator took ownership of the test agent's `OutboxSignOutCleanerTest.kt` cancellation fixture and then the bounded adapter fix. That work is completed and reviewed below.

26 September continuation: weekly usage reset and the owner asked to continue. A corrected cancellation fixture was proved RED **61/7**, then the P1b Room transaction guard was committed at `5b5fa68b7475049b2d409f82689cc858d75837ed`; targeted verification was **61/1**, all nine new Room tests passing, only the original token-capture assertion failing. A first combined full run reached **3,743 tests / 2 failures**: the token assertion plus a 10-second cold-Room fixture timeout before the B-outbox test body. The fixture's bounded setup timeout was raised to 30 seconds without changing any assertion, committed with a KDoc correction at `ed9de0c38a13e22d2c0777eaf2321cd08932e77f`. Its final full run reached **3,743 tests / 1 failure / 0 errors / 0 skips**: all P1b tests passed, and only the original token-capture regression failed. Lint, debug and unsigned R8 assembly passed; the combined Gradle exit was 1 because unit tests remain non-green. All twelve frozen source/test hashes match the run manifest. Independent [critic](helper-reviews/codex-20260926/p1b-critic.md) and [QA](helper-reviews/codex-20260926/p1b-qa.md) each scored **9.6/10** for P1b committed-row deletion safety, with no mandatory defect within that boundary. P1b is **locally accepted for that narrow scope only**; S1, whole-app, main integration and release are blocked. Read the [P1b handoff](HANDOFF_P1B_OUTBOX_CLEANUP_2026-09-20.md). Owner-directed **English-only** product documentation at `80e2ec62` has been merged into this candidate without app source changes.

Later 26 September P1c: production `ed7a5397` binds departing device-token capture and draft deletion to the first-operation exact login ticket; test-only closure `04aa5729f8d2ec7a1d5e3381178f2a334904c61a` repairs a real account-switch ownership fixture and adds file-backed draft transaction tests. Test-first cancellation RED was **47/2**. The first full **3,761/2** exposed that fixture; the final combined unit/lint/debug/unsigned-release run is **3,765 tests / 429 suites / 0 failures/errors/skips**, Gradle exit 0. Lint 0 errors/91 warnings/2 hints and design ratchet pass; 13/13 final source hashes match. Independent [critic](helper-reviews/codex-20260926/p1c-critic.md) and [QA](helper-reviews/codex-20260926/p1c-qa.md) each score **9.6/10 for P1c's local boundary only**. Read the [P1c handoff](HANDOFF_P1C_TOKEN_CAPTURE_2026-09-26.md). The repository revokes client `device_tokens` DELETE while Android still uses it; deployed grants were not queried. Remote registration/revocation, sender payload privacy, wider S1/S3, main integration and release remain blocked. Safe P1b continuity docs separately reached `main` through [PR1883](https://github.com/ganeshnaik166/equipseva-android/pull/1883); the P1c app code has **not** merged to `main`.

## Where we are

| Record | Exact checkpoint | Meaning |
|---|---|---|
| Main product plan | `24e0199937c09c137e8045aa7664dcd4f746dbb1`, [PR1879](https://github.com/ganeshnaik166/equipseva-android/pull/1879) merged | Governing four-persona plan, 98 existing-page dispositions, 30 proposed surfaces and seven-page PDF; Android and secret-scan push/PR checks passed |
| Portable continuity contract | `62da836f101e6ba2ac1497cbdc8ae933e1fa3543`, [PR1880](https://github.com/ganeshnaik166/equipseva-android/pull/1880) merged | Mandatory model entry/save contract, current-state pointer and milestone log |
| P1a implementation | `434663c044460104ce7ebbc60029ac9e6ee90d28`, branch `codex/quality-integration-20260919`, [draft PR1877](https://github.com/ganeshnaik166/equipseva-android/pull/1877) | P1a successor-login AMC deletion safety; broader integration remains blocked |
| Test-only review polish | `8d80ba3c85a9dd833d08930f8b7728f9c485247c` | Five direct exception/cancellation tests and immediate disk reopening after cancelled cleanup; production unchanged |
| Scoped result / active slice | **P1a, P1b and P1c accepted locally for separate bounded guarantees** | P1a AMC, P1b committed outbox rows, P1c local token capture/draft fence/cancellation; each critic and QA **9.6** for its own scope. Final P1c full unit is green, but remote push and wider app/main/release gates remain blocked |
| P1b code and tests | `5b5fa68b7475049b2d409f82689cc858d75837ed`; fixture/KDoc `ed9de0c38a13e22d2c0777eaf2321cd08932e77f` | Real Room write-transaction guard, nine new tests and real-store integration fixture; targeted 61/1, full 3,743/1 (original token capture) |
| P1c code and tests | Production `ed7a5397`; frozen test closure `04aa5729f8d2ec7a1d5e3381178f2a334904c61a` | Ticket-bound local token capture and two-phase draft cleanup; final full 3,765/0, lint/debug/unsigned R8 green; critic/QA 9.6 each for this scope only |

P1a base was `3c61469927b01bb0592ff501a8af42f401c937a2` after syncing main's plan and continuity records. The frozen code SHA above is distinct from later documentation/merge commits; fetch and inspect current HEAD before writing. Read [the P1a handoff](HANDOFF_P1A_AMC_CLEANUP_2026-09-19.md) for scope, files, executed commands and limitations. The shared Gradle slot was released after verification; always recheck it before a new run.

This documentation is proposed separately from app code on `codex/docs-p1b-continuity-20260926`. P1a/P1b implementation and tests remain on `codex/quality-integration-20260919`/draft PR1877; a copy of these records on main is not app integration or release acceptance.

Current app checkout on this laptop: `C:/Users/lokes/Documents/Codex/2026-09-07/im/work/equipseva-quality-integration-20260919`. The old coordinator (`equipseva-auth-integration-20260911`) and helper worktrees are preserved. Do not use a guessed checkout or silently transfer their changes.

## Owner decisions after the plan

- **23 September 2026 — English only.** The owner wrote: "no need of Hindi, Telugu translations or words, all should be in English; update this in GitHub memory urgently." Recorded in [AGENTS.md](../AGENTS.md) (standing decisions), [PRODUCT_PLAN.md](../PRODUCT_PLAN.md), the delivery ledger, the page plan and the UX plan. Consequence for code: `app/src/main/res/values-hi` and `values-te` are deleted and `localeFilters` is `en` only (branch `claudedev-build-20260923`; measured before deletion: 724 of 759 hi/te entries were verbatim English copies, so devices set to Hindi/Telugu had been seeing a mixed 35-word translation). Nobody should start translation, language-picker or locale-config work.

## Parallel branch: `claudedev-build-20260923` (Claude, opened 23 September 2026)

Based on `main` `70c06420`; pushed to origin under that name; no PR yet. It does **not** touch the P1b files (`SignOutCleanup`, `OutboxSignOutCleaner`, the local-boundary regression tests) or any billing/SQL. Recorded scope and file ownership:

| Slice | Files owned on this branch | Status |
|---|---|---|
| English-only resource cleanup | `app/src/main/res/values-hi/**`, `values-te/**` (deleted), `app/build.gradle.kts` `localeFilters` line, `app/src/test/kotlin/com/equipseva/app/i18n/StringsParityTest.kt` (replaced by an English-only guard) | in progress |
| P2.2 client foundation: bundled region catalog reconciliation | `app/src/main/kotlin/com/equipseva/app/core/data/location/**` and its tests only; no UI, schema or RPC change | planned |

Evidence, test counts and reviews for this branch are recorded in its handoff when each slice freezes; nothing here is main integration or release acceptance.

## Product direction

Three public purposes: biomedical engineer, hospital administrator, engineering team/organisation. Platform owner is private and separately provisioned. Paid team administrators have authority within their own organisation; subscription is not a global role grant. Independent engineers retain their personal workspace. Use India State/UT and district, with no-map target workflows; existing GPS/server contracts still require a tested migration. Preserve lime/ink/soft-white and Space Grotesk/Inter. **English only** (owner decision 23 September 2026): no Hindi/Telugu translations, words, locale resources or language pickers anywhere. Demo is local synthetic data; digital team subscription and physical service payments are separate. [PRODUCT_PLAN.md](../PRODUCT_PLAN.md) governs details.

## Verified evidence and open gates

- Latest full run at `04aa5729`: **3,765 tests, 0 failures, 0 errors, 0 skipped**, exit 0. All P1c token/draft and prior P1b/P1a regressions pass. Earlier P1b final at `ed9de0c3` was **3,743/1** (the now-fixed token-capture assertion); P1a full at `8d80ba3c` was **3,734/2**. A green local unit suite does not close server push, other sign-out resources, device or release gates.
- New intent/region preparation: 24-test stub RED (14 assertion failures); unchanged tests GREEN 45/0 with compatibility controls. Critic 9.5, QA 9.6 for these four files only; types are not wired into live UI/permissions.
- At `04aa5729`, lint completed with 0 errors/91 warnings/2 hints; debug and unsigned R8 assemblies passed. The design ratchet passed with no negative signal above baseline. The Gradle Crashlytics finalizer reported a mapping upload, with no independent receipt checked. Strict signing/certificate/Sentry/device/provider acceptance is still open.
- Earlier visual record: 116 changed comparisons; only two individually inspected. Do not replace goldens or lower thresholds to turn this green.
- Remaining gates include S1 local cleanup/token capture, S3 logout recovery, M1 payout ordering, M3 provider retry classification, bound integrity enforcement, dependency disposition and full device/provider/human/release validation.
- Planning critic 9.5 and QA 9.6 apply only to the plan. No passing app-wide or security-certification score is claimed.

## Next concrete action

Read the [latest app handoff](https://github.com/ganeshnaik166/equipseva-android/blob/faa2d03e8dddddcc39b02b75eb0b1fab36b77947/docs/HANDOFF_WORKSPACE_FOUNDATION_2026-09-19.md) and [existing S1 boundary plan](https://github.com/ganeshnaik166/equipseva-android/blob/faa2d03e8dddddcc39b02b75eb0b1fab36b77947/docs/helper-reviews/codex-20260919/signout-ownership-plan.md).

P1a's test-only polish is complete. [Critic](helper-reviews/codex-20260919/p1a-critic.md) and [QA](helper-reviews/codex-20260919/p1a-qa.md) independently accepted the bounded deletion guarantee at **9.6/10 each**. QA's initial 9.3 was corrected through executed exception/cancellation, separate-thread monitor reuse and immediate disk-reopen checks. Initial reports are preserved with the evidence. Original production remains frozen at the recorded SHA. Original behavioural RED was 47/26 → 47/2 with unchanged tests; the five new review tests and additive cancellation assertion are separately disclosed.

Completed local implementation slice **P1b: real Room outbox deletion ownership** was resumed from fetched `f7608644728a20bc24aa2fa74e75c3817a461fcd` on 20 September. The coordinator owned the new `core/sync/OutboxSignOutCleaner.kt`, its `SignOutCleanup` wiring, actual-Room upgrade of the existing local-boundary regression harness, three affected constructor fixtures, documentation, Git and all Gradle runs. The test agent initially owned the new `core/sync/OutboxSignOutCleanerTest.kt`; the coordinator later corrected its fixture. Architect/QA and critic were read-only. No `OutboxDao`, schema, producer or worker change was needed. Read [the P1b handoff](HANDOFF_P1B_OUTBOX_CLEANUP_2026-09-20.md).

Historical 20 September checkpoint: P1b's first RED was **61/8**, including one SQLite-locking fixture result that was not behavioural evidence. The fixture was corrected transparently, followed by behavioural RED **61/7** and targeted GREEN **61/1** on the guarded Room implementation. The one remaining targeted failure is the original token-capture assertion. The first full run had a cold Room setup timeout before that test's safety assertion; after a bounded fixture correction, the full rerun was **3,743/1** with only the token assertion failing. Lint/debug/unsigned R8 passed. Do not merge the broad candidate to main while S1 and other gates remain.

P1b checkpoint was pushed at `11b43ee97a15afde2cf62d796f8905cbe33164dc`, with matching remote SHA and clean tree; its safe continuity docs reached main via PR1883. **P1c is locally accepted at production `ed7a5397` plus test closure `04aa5729`** with the evidence above; its candidate branch is pushed at `19b909aa9989f35f447ec8c333d6052c580d9243`. This docs-only update records its status separately from app integration. Next slice **P1d-0: sender payload privacy and precise FCM error classification**. Read the [repository contract finding](helper-reviews/codex-20260926/p1d-remote-token-gap.md), [schema inventory](helper-reviews/codex-20260926/p1d-schema-inventory.md), and [independent security review](helper-reviews/codex-20260926/p1d-contract-critic.md). First freeze sender ownership and route contract, write pure synthetic failing tests for sensitive/spoofed notification data and generic 404 versus token-specific invalidity, then implement the smallest sender-only fix. Do not change SQL grants or client claim/release in P1d-0. A later P1d-1 migration requires the actual `device_tokens` DDL/RLS/grants and a disposable two-session race suite. Preserve the parallel English-only/region branch and other checkouts.

P1a/P1b/P1c must not be presented as whole S1 completion: other stores, photo producers/readers, preferences, realtime teardown and final SDK logout remain separate ownership boundaries. Do not touch billing, production SQL or unrelated UI while fixing P1d-0.

## Continuity rule

Update this file, the [milestone log](MILESTONE_LOG.md), affected [delivery ledger](product-plan/DELIVERY_LEDGER.md) row, detailed handoff and supported model memory after every milestone/checkpoint. Future entries must use observed results and exact revisions. Never copy private memory or secret logs into Git. Website development remains paused.
