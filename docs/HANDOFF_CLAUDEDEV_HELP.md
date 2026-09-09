# Handoff — helper branch `claudedev-help`

**Read this first if you are the ChatGPT / Codex ("Astra") session resuming the
renewal program.** A second agent (Claude, at the owner's request) worked on this
repository after your session ran out of tokens. Everything it did is on the
branch `claudedev-help`, which was cut from your tip
`c927f7f4` (`codex/security-foundation-20260907`). Nothing was pushed to `main`,
`ops/**`, or `codex/**`, and no production migration or release was deployed.

## Ground rules the helper followed

- **Your plan governs.** `RENEWAL_EXECUTION_PLAN.md`, its milestones, quality
  gates, working rules and the design/flow decisions you recorded were not
  changed. The one edit to that file is the read-first pointer blockquote at
  its top (milestone 0, `a482f73c`, 5 added lines, nothing removed). The helper
  only executed the next queued item you left.
- **Your branch is untouched.** `codex/security-foundation-20260907` still
  points at `c927f7f4`. Diff the helper's work with
  `git diff c927f7f4...origin/claudedev-help`.
- **Additive only.** New files and new tests; existing behaviour was not
  redesigned. Where a defect in existing code was found, it is recorded below
  with evidence rather than silently reworked, unless the fix was required for
  the queued item and is called out explicitly.
- **One commit per milestone**, each pushed to `origin/claudedev-help`, each
  with the checks that were actually run in the message.

## Where you stopped (your own last status, 7 September 2026)

> Current focus is security and data reliability before the interface redesign.
> Implemented: evidence-access checks, account-safe draft recovery, and cron fixes.
> Verified: the latest Android and backend CI checks both passed.
> Next: integration tests for account switching, draft recovery and photo evidence
> before merging to main.
> UI: workflow planning and navigation review are done; redesigned screens are
> still pending.

## What the helper did on `claudedev-help`

Baseline re-verified on `c927f7f4` on the owner's Windows machine before any
change: `:app:testDebugUnitTest` BUILD SUCCESSFUL, 2,835 tests / 336 suites /
0 failures / 0 errors (matches your recorded count).

Milestone log (newest last; each entry is one commit):

| # | Commit | Scope | Checks run |
| --- | --- | --- | --- |
| 0 | `a482f73c` | Handoff note for the resuming session; memory of the working agreement | docs only |
| 1 | `53be5025` | CI push filters gain `claudedev-help` (and `secret-scan` gains `codex/**`); frozen slice below | workflow + docs edits only |
| — | `410332b9` | **Session stopped by the owner** before implementation began (2026-09-07). | docs only; CI secret-scan 34124137324 success |
| 2 | `52105cf5` | Rubric corrections from the design critique; `testing/TestSupabaseClient.kt` (real supabase-kt client over MockEngine); `supabase/tests/android_evidence_contract.json` | compileDebugUnitTestKotlin only; tests 2835/336/0 unchanged; CI android 34346219562 success, backend regressions 34346219561 success, secret-scan 34346219560 success |
| 3 | `37a0a4c2` | INT-03 `EvidenceRegisterOutboxHandlerIntegrationTest` (10 tests, real client, no fallback taken); DEV-01 recorded BLOCKED (section below) | targeted `--tests` run: 10/10 pass in 22 s; CI android 34352358903 success, secret-scan 34352358917 success (backend regressions not triggered: no Supabase path changed) |
| 4 | `eece93f7` | INT-04 both halves: `features/repair/RepairPhotoEvidenceContractTest` (4 tests, drives the REAL `RepairJobDetailViewModel` before/after enqueue) + `supabase/tests/evidence_client_contract.test.mjs` (32 checks against the actual r492 and r3821 SQL) sharing `android_evidence_contract.json`; `EvidenceRegisterPayloadTest` fixture corrected to 4 segments (+4/−3 lines, no assertion changed); `package.json` gains `test:contract` last in the chain; one README paragraph | targeted Gradle run: 4/4 + 6/6 pass in 14 s; Node suite run LOCALLY via VS Code's Electron as Node 24 with `EQS_PGLITE_PACKAGE` (32/32; and 60/60 for the existing evidence suite as control; withholding the r3821 migration makes exactly the 8 discriminating variants fail); full Gradle chain deferred to the final milestone; CI android 34354195061 success, backend regressions 34354195063 success (the contract suite ran under npm ci + npm test), secret-scan 34354195073 success |
| 5 | `17728c2b` | INT-02 `core/data/repair/RequestServiceDraftIdentityIntegrationTest` (one Robolectric test, five labelled phases, PRODUCTION `@Inject` constructor + real supabase-kt client): valid token → `Identity(uid, session_id)` and the REAL `request_service_draft.preferences_pb` receives owner id + draft text; sub-mismatch token and no-`session_id` token → `Identity(uid, null)` with persistence disabled (file never receives the text); a fresh valid token re-enables persistence; blank SDK user id → no lease while the SignedIn emission is proven delivered. One method by design: the production delegate is one DataStore per JVM pinned to the first Context. | targeted run BUILD SUCCESSFUL in 24 s, 1/1 pass; full chain deferred to the final milestone; CI android 34380751839 success, secret-scan 34380751780 success |
| 6 | (this commit) | INT-01 `features/hospital/RequestServiceAccountSwitchIntegrationTest` (8 Robolectric tests, one flow through a REAL on-disk DataStore + REAL store + REAL ViewModel + REAL hand-built `SignOutCleanup` + `android.os.Parcel` round trip): another account after a real sign-out never sees or alters A's draft (presence on raw prefs first, replayed A lease changes nothing); late profile/upload/submit callbacks resolving after sign-out land nowhere, each with a positive control that lands without sign-out and a resumed-counter proving the continuation ran; same account again with a new session id starts clean; same-session re-emission keeps the lease instance and the disk draft; typed `req.*` keys survive Parcel and a foreign-owner bundle renders nothing. Also: handoff table reordered, plan-file edit disclosed, INT-04 row amended (uppercase uuid segment not expressible against digit-only fixture ids; kind/array-mismatch variant added instead) | targeted run BUILD SUCCESSFUL in 16 s, 8/8 pass. First attempt hung 18 min in `@After` (`runBlocking { join }` on Robolectric's main thread with nothing pumping the Main test dispatcher); fixed by joining the disk scope inside `runTest` and bounding the teardown join. Killing that worker left stale `test-results/…/binary` files that made the next two runs fail with `java.io.EOFException` before any test ran; cleared by deleting the directory. Full chain deferred to the final milestone |

### Historical: where the helper stopped on 2026-09-07 (after milestone 1)

Done: branch created and pushed; baseline re-verified (2,835 / 336 / 0);
six read-only investigations of the plan, draft/account code, r3820↔r3821
photo-evidence contract, backend harness, Android test infrastructure and CI
conventions (digest kept in the helper's private notes, key facts below);
slice frozen; a three-lens design critique was launched and cancelled unrun
when the owner asked to stop.

Not done: every test in the slice table, the local verify chain for them,
the device drive. **No application source has been changed on this branch.**

Facts worth carrying forward (all cited from the tree at `c927f7f4`):

- r3820 client and r3821 server are shape-compatible on the happy path
  (`repair-photos/<uid>/<job>/<before|after>-<millis>-<uuid>-<sanitized40>`,
  lowercase sha, `producer_kind=engineer`, metadata object), but the only
  client fixture (`EvidenceRegisterPayloadTest`, `repair-photos/u1/before-1.jpg`)
  has 3 segments and would be rejected by r3821; no client test covers
  `EvidenceRegisterOutboxHandler`; nothing binds the two layers.
- Behavioural consequences if r3821 deploys as-is: a swallowed or race-dropped
  `before_photos`/`after_photos` append (PhotoUploadOutboxHandler is
  best-effort) → 42501 `evidence_photo_not_attached` → HTTP 403 → silent client
  GiveUp (CrashReporter only); identical bytes picked twice for one job →
  42501 `evidence_registration_conflict` (r492 returned the existing id);
  real Storage `owner_id` / `metadata.size` semantics and the
  `SECURITY DEFINER … FOR SHARE` privilege on `storage.objects` are unverified.
- Draft isolation: `RefreshFailure → SignedOut` (SupabaseAuthRepository) wipes a
  live form + SavedStateHandle without a fence; the sign-out-fails-at-both-scopes
  path leaves a lease-less "dead form" with no copy; `request_service_draft`
  has no DataStore corruption handler. These are observations for your issue
  register, not changes made.
- Test infra: real on-disk DataStore + real VM + real SavedStateHandle already
  run on the JVM (RequestServiceDraftPersistenceTest / IsolationTest); a real
  `SignOutCleanup` must be hand-built (DatabaseModule loads sqlcipher, SyncModule
  needs WorkManager); Hilt's `TestSupabaseModule` relaxed mock yields a blank
  user id, so a Hilt-injected draft store never issues a lease (a test could pass
  proving nothing); no Turbine, no shared MainDispatcherRule; Robolectric SDK
  pins must be 34/35.
- Backend harness: PGlite single connection; `denied()` asserts `.code` only;
  fixture omits r3818 (`gps_checkin` CHECK) and hard-codes `is_founder()` to one
  uid; `evidence_for_repair_job` has no service-role bypass while the other two
  RPCs do (possible unintended asymmetry); r3821 dropped r492's `lower()` on the
  hash, so uppercase hex is now rejected.
- CI: a push to `claudedev-help` triggers nothing until milestone 1 landed;
  `release-aab.yml` fires on any `v*` tag; docs pushed to `main` become public
  on GitHub Pages.

Next action for whoever resumes: implement INT-01..04 exactly as frozen
(or revise the frozen table first, with a reason), run the Codex-required
Gradle chain, push, read the CI result, then DEV-01.

## Frozen slice: M1 integration tests (account switching, draft recovery, photo evidence)

Frozen before implementation, per the plan's quality-gate rule. This is the
queued item from your last status. It does not close M1.

### Scope (in)

| Id | Layer | Test | Proves |
| --- | --- | --- | --- |
| INT-01 | Android JVM (Robolectric) | `RequestServiceAccountSwitchIntegrationTest` | Real on-disk Preferences DataStore + real `RequestServiceDraftStore` + real `RequestServiceViewModel` + real `SavedStateHandle` (Bundle round-trip) + real `SignOutCleanup.wipeLocalUserState()` + `FakeAuthRepository` SignedOut/SignedIn emissions. Scenarios: (a) A drafts, signs out, B signs in: B never sees A's draft, B's autosave lands, A's replayed lease/callbacks change nothing; (b) late callbacks after logout (profile fetch, upload, submit) land nowhere; (c) same account again with a new `session_id`: A's draft is gone by design and the handle is rewritten; same-session re-emission (token refresh) keeps the lease and the disk draft; (d) process death via Bundle round-trip: `req.*` keys survive Parcel for the same session and never render for a foreign owner. Every absence assertion is preceded by a presence proof on the raw preferences (owner, session, draft text bytes) and every late callback has a positive control that lands without logout. Real behind `SignOutCleanup`: `RequestServiceDraftStore`, `DefaultPhotoUploadStash`, `UserBlockRepository`; no-op fakes: `DeviceTokenRegistrar`, `OutboxDao`, `OutboxScheduler`, `UserPrefs`, the three pending-payment stores, a `SupabaseClient` without Realtime. |
| INT-02 | Android JVM (Robolectric) | `RequestServiceDraftIdentityIntegrationTest` | The production `@Inject` constructor path: a `SupabaseClient` whose current session carries a synthetic 3-segment JWT (`sub`, `session_id`) yields `Identity(uid, session_id)`; a token without `session_id` yields `Identity(uid, null)` and persistence is disabled; a blank user yields no lease. |
| INT-03 | Android JVM | `EvidenceRegisterOutboxHandlerIntegrationTest` | Real `EvidenceRegisterOutboxHandler` against a real `SupabaseClient` over ktor `MockEngine`: the HTTP request is `POST …/rest/v1/rpc/register_evidence` with the caller's bearer token and exactly the ten `p_*` parameters (uuid strings, numeric size, lowercase sha, `android/<versionName>`, metadata keys `mime_type`/`captured_from`/`client`); outcomes 200 uuid → Success, 403 (42501 body) and 400 (22023 / 02000 body) → GiveUp + `CrashReporter.report`, 500 (incl. a 40001 `evidence_registration_retry` body), 408 and 429 → Retry, 200 blank or `null` → GiveUp + report, no session → Retry, producer mismatch → GiveUp; the two gate cases assert zero HTTP requests, the HTTP cases assert exactly one, and the engine fails the test on any path other than the RPC. Falls back to a mocked Postgrest plugin capturing the parameter object only if the Auth plugin cannot initialise on the JVM (recorded if so). |
| INT-04 | Android JVM + backend | `RepairPhotoEvidenceContractTest` (Kotlin) and `evidence_client_contract.test.mjs` (Node/PGlite), sharing `supabase/tests/android_evidence_contract.json` | The REAL `RepairJobDetailViewModel` before/after photo enqueue produces `<uid>/<job>/<before|after>-<millis>-<uuid>-<sanitized40>` and `EvidenceRegisterPayload.forUploadedPhoto` produces `repair-photos/<that path>`; the Kotlin side asserts conformance to the rules in the JSON fixture (4 segments, bucket literal, uid, job id, filename charset, sha regex, kinds, producer, source) and the sanitizer table; the Node side executes the same real-shape receipts against the actual round3821 `register_evidence` on PGlite (accepted, `evidence_for_repair_job` returns the bucket-prefixed url) and the fixture's non-conforming variants (`.` filename, empty/leading/trailing-slash url, bucket prefix missing, the three-segment legacy shape, a kind the client never sends, a non-engineer producer, a kind whose object sits in the other attachment array; plus uppercase hex as a contract pin both migrations reject) are denied with the expected SQLSTATE and RAISE literal, and each is also proven accepted or inserted by round492 with a distinct hash so the discrimination is executed on both databases. An uppercase uuid segment is not expressible against the digit-only fixture identities; the Kotlin side rejects it through the fixture regex. Also corrects the off-contract fixture in `EvidenceRegisterPayloadTest` (`repair-photos/u1/before-1.jpg` has 3 segments; round3821 requires 4). |
| CI-01 | GitHub Actions | `android.yml`, `evidence-regressions.yml`, `secret-scan.yml` | Push to `claudedev-help` triggers the same checks you gave `codex/**` (additive branch-filter entries only; `secret-scan` also gains `codex/**`, which it lacked). |
| DEV-01 | Device (`eqs` emulator, production backend at round492) | Manual drive of the r3820 photo-evidence path as `play-review-engineer` | The queued handoff item: a before-photo check-in produces a `photo_before` ledger row. Read path: `supabase db query --linked -f <select-only>.sql` reading `evidence_ledger` (kind, `content_size_bytes`, `storage_url`) and `storage.objects.metadata->>'size'` for that path; the two sizes are compared and recorded with the ledger row id and object path. Guards: SDK log level stays INFO, no token capture from logcat, no token or key in any committed file, no `supabase db push`, no `workflow_dispatch` of any cron workflow, APK = debug build of this tree (app source unchanged from `c927f7f4`). Fixture policy: reuse an existing Assigned job for the test engineer; if none exists, record BLOCKED rather than creating job/bid/accept rows. Honesty: this exercises round492 in production (no path validation there); r3821 device compatibility is proven only by INT-04 on PGlite. The ledger row cannot be rolled back through the app path; its id is recorded. |

### Scope (out, named)

Migration-built full-chain Supabase test project with real Storage upload and
GoTrue JWTs (your README item 2), `owner_id` semantics of real Storage,
`SECURITY DEFINER … FOR SHARE` privileges on `storage.objects`, REL-01
attach/register reconciliation, SessionViewModel zombie paths, Compose screen
tests, deployment of round3821/3822, any merge to `main`, and direct REST/RPC
calls against a live Supabase project (the plan's "direct API calls" rule is
met here only by DEV-01, against round492). The "populated foreign-user
fixture" rule is met through the existing `evidence_authorization.fixture.sql`
identities on PGlite. Client uid = `session.user.id`, server actor =
`auth.uid()` (JWT `sub`); their equality is a GoTrue invariant assumed by
INT-04 and observed only by DEV-01.

### Frozen rubric (this slice)

| Dimension | Weight | Applicable | Items |
| --- | ---: | --- | --- |
| Task correctness and completion | 25 | yes | INT-01..04 exist, compile, pass locally (Gradle) and in CI (Node); each assertion proves the claim in the table, not a tautology |
| Security and privacy | 25 | yes | cross-account denial paths asserted positively and negatively; no credentials, tokens or local account data in Git; synthetic identities only |
| Resilience, retained work and money correctness | 20 | yes | draft survives same-session recreation and refresh; late callbacks cannot corrupt the replacement account; evidence outcome mapping never drops a retryable failure or retries a permanent one |
| Usability, accessibility and localization | 15 | N/A | no UI or copy changed |
| Visual consistency | 10 | N/A | no UI changed |
| Performance and operations | 5 | yes | new JVM tests add < 60 s locally; CI still green; no flaky timing (virtual time only) |

Score = earned / 75 applicable points × 10. Critic and QA each must reach
9.5 overall, and each applicable critical dimension (Task correctness,
Security and privacy, Resilience/retained work) must itself reach 9.5. All
hard blockers listed in `RENEWAL_EXECUTION_PLAN.md` apply in full; slice
additions: a test that passes without exercising the real component it names;
a change to plan flow or design. This is a scoped-slice score for
INT-01..04 / CI-01 / DEV-01 only. It is not an M1 score and not a full-app
score.

### Working method

Implementer agents write files without running Gradle concurrently; one
verification run executes the Codex-required chain
(`testDebugUnitTest`, `lintDebug`, `assembleDebug`, `assembleRelease` with
`PRECHECK_LOOSE=1`). Node suites: no `node`/`npm` is installed here, but VS
Code's `Code.exe` with `ELECTRON_RUN_AS_NODE=1` is Node 24 and the harness's
`EQS_PGLITE_PACKAGE` variable can point at an extracted `@electric-sql/pglite`
0.5.8 tarball kept outside the repo; that is used as a pre-push check, and CI
(`npm ci` + `npm test`) stays authoritative. Each milestone is one commit on
`claudedev-help`. `git fetch origin` before every commit; never run two Gradle
builds at once.

Synthetic JWTs are assembled at runtime from a JSON claims string (as
`RequestServiceDraftStoreTest` already does); no base64 token literal (no
encoded JWT header prefix), no real project ref or key appears in any
committed file. The MockEngine base URL is a fake host. Before each push: grep
the new files for the three-character encoded-JWT header prefix.

Existing files touched are limited to: `EvidenceRegisterPayloadTest` (two
fixture path values and the expected string, no assertion added or removed),
`supabase/tests/package.json` (a `test:contract` script appended last to the
`test` chain), `supabase/tests/README.md` (one added paragraph). The PGlite
harness header is copied into the new Node file rather than refactoring the
Codex-authored suite.

Every milestone commit body ends with a `Validation:` paragraph carrying: the
Gradle command verbatim; unit tests / suites / failures before → after from the
XML reports (baseline 2835 / 336 / 0); lint, assembleDebug and
assembleRelease (`PRECHECK_LOOSE=1`) results with wall time; Node suites "not
run locally (no Node)" with the CI run ids and conclusions filled into the
handoff table after the push; existing files touched; and the negatives
"no application source changed / no migration / no deployment / no main
merge". The milestone table below records Commit, Files, Tests before → after,
CI run ids + conclusions, and Not run.

## DEV-01 result: BLOCKED (2026-09-09), owner decision needed

Read-only probes through `supabase db query --linked` (the CLI at
`C:\Users\lokes\supabase-cli\supabase.exe`, token from the documented local
file, nothing printed or committed):

- `migration list --linked`: remote applied through `20263897000000`
  (round3819); `20263898000000` (round3821) and `20263899000000` (round3822)
  are local-only, exactly as your commit messages state.
- Jobs assigned to `play-review-engineer`: RPR-00040 and RPR-00041, both
  `in_progress`, each already holding 2 `before_photos`. No job is in
  `assigned` or `en_route`, so the before-photo check-in path cannot be driven.
- `evidence_ledger` for those two jobs holds only the round3818/3819 backfill
  rows (`gps_checkin`, `signature_*`); no `photo_before`/`photo_after` row
  exists, i.e. the r3820 client path has still never run in production.
- The `eqs` emulator was attached at the start of the session and had exited
  by the time the probes ran.

Per the frozen fixture policy the helper did not create a job, bid or
acceptance, and did not complete an in-progress job (that would advance escrow
and payout state). Two ways to unblock, both yours: (a) authorise the hospital
test account to post a new job and accept a bid from the test engineer, then
drive the check-in; or (b) accept a `photo_after` drive by marking RPR-00041
done (money-path side effects). Either way the read path and guards above are
ready.

## Open items handed back to you

- Merge/no-merge of `codex/security-foundation-20260907` and of
  `claudedev-help` into `main` is the owner's call; the helper did not merge.
- r3821 / r3822 migrations remain undeployed candidates (per your commit
  messages). The helper did not deploy them.
- Local tooling note for this machine: Node.js and Python are **not installed**,
  so `supabase/tests` (PGlite) and `scripts/test_cron_response_summary.py` can
  only be exercised in GitHub Actions here. Gradle (JDK 17) works locally.
