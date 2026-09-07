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
  changed. The helper only executed the next queued item you left.
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
| 0 | this commit | Handoff note for the resuming session; memory of the working agreement | docs only |

Sections below are appended per milestone.

## Frozen slice: M1 integration tests (account switching, draft recovery, photo evidence)

Frozen before implementation, per the plan's quality-gate rule. This is the
queued item from your last status. It does not close M1.

### Scope (in)

| Id | Layer | Test | Proves |
| --- | --- | --- | --- |
| INT-01 | Android JVM (Robolectric) | `RequestServiceAccountSwitchIntegrationTest` | Real on-disk Preferences DataStore + real `RequestServiceDraftStore` + real `RequestServiceViewModel` + real `SavedStateHandle` (Bundle round-trip) + real `SignOutCleanup.wipeLocalUserState()` + `FakeAuthRepository` SignedOut/SignedIn emissions. Scenarios: (a) A drafts, signs out, B signs in: B never sees A's draft, B's autosave lands, A's replayed lease/callbacks change nothing; (b) late callbacks after logout (profile fetch, upload, submit) land nowhere; (c) same account again with a new `session_id`: A's draft is gone by design and the handle is rewritten; same-session re-emission (token refresh) keeps the lease and the disk draft; (d) process death via Bundle round-trip: `req.*` keys survive Parcel for the same session and never render for a foreign owner. |
| INT-02 | Android JVM (Robolectric) | `RequestServiceDraftIdentityIntegrationTest` | The production `@Inject` constructor path: a `SupabaseClient` whose current session carries a synthetic 3-segment JWT (`sub`, `session_id`) yields `Identity(uid, session_id)`; a token without `session_id` yields `Identity(uid, null)` and persistence is disabled; a blank user yields no lease. |
| INT-03 | Android JVM | `EvidenceRegisterOutboxHandlerIntegrationTest` | Real `EvidenceRegisterOutboxHandler` against a real `SupabaseClient` over ktor `MockEngine`: the HTTP request is `POST …/rest/v1/rpc/register_evidence` with the caller's bearer token and exactly the ten `p_*` parameters (uuid strings, numeric size, lowercase sha, `android/<versionName>`, metadata keys `mime_type`/`captured_from`/`client`); outcomes 200 uuid → Success, 403 (42501 body) and 400 (22023 body) → GiveUp + `CrashReporter.report`, 500 → Retry, 200 blank → GiveUp + report, no session → Retry, producer mismatch → GiveUp with no HTTP call. Falls back to a mocked Postgrest plugin capturing the parameter object only if the Auth plugin cannot initialise on the JVM (recorded if so). |
| INT-04 | Android JVM + backend | `RepairPhotoEvidenceContractTest` (Kotlin) and `evidence_client_contract.test.mjs` (Node/PGlite), sharing `supabase/tests/android_evidence_contract.json` | The REAL `RepairJobDetailViewModel` before/after photo enqueue produces `<uid>/<job>/<before|after>-<millis>-<uuid>-<sanitized40>` and `EvidenceRegisterPayload.forUploadedPhoto` produces `repair-photos/<that path>`; the Kotlin side asserts conformance to the rules in the JSON fixture (4 segments, bucket literal, uid, job id, filename charset, sha regex, kinds, producer, source) and the sanitizer table; the Node side executes the same real-shape receipts against the actual round3821 `register_evidence` on PGlite (accepted, `evidence_for_repair_job` returns the bucket-prefixed url) and the fixture's non-conforming variants (uppercase hex, `.` filename, empty/leading/trailing-slash url, uppercase uuid segment) are denied with the expected SQLSTATE and RAISE literal. Also corrects the off-contract fixture in `EvidenceRegisterPayloadTest` (`repair-photos/u1/before-1.jpg` has 3 segments; round3821 requires 4). |
| CI-01 | GitHub Actions | `android.yml`, `evidence-regressions.yml`, `secret-scan.yml` | Push to `claudedev-help` triggers the same checks you gave `codex/**` (additive branch-filter entries only; `secret-scan` also gains `codex/**`, which it lacked). |
| DEV-01 | Device (`eqs` emulator, production backend at round492) | Manual drive of the r3820 photo-evidence path as `play-review-engineer` | The queued handoff item: a before-photo check-in produces a `photo_before` ledger row; `content_size_bytes` compared with the Storage object's `metadata.size` (the only real-Storage evidence obtainable without service-role access). Attempted after INT/CI; recorded as blocked if the emulator state lacks an assignable job. |

### Scope (out, named)

Migration-built full-chain Supabase test project with real Storage upload and
GoTrue JWTs (your README item 2), `owner_id` semantics of real Storage,
`SECURITY DEFINER … FOR SHARE` privileges on `storage.objects`, REL-01
attach/register reconciliation, SessionViewModel zombie paths, Compose screen
tests, deployment of round3821/3822, any merge to `main`.

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
9.5. Hard blockers (any → not accepted): a test that passes without exercising
the real component it names; a secret in Git; a change to plan flow or design.

### Working method

Implementer agents write files without running Gradle concurrently; one
verification run executes the Codex-required chain
(`testDebugUnitTest`, `lintDebug`, `assembleDebug`, `assembleRelease` with
`PRECHECK_LOOSE=1`). Node suites run only in CI here (no Node locally). Each
milestone is one commit on `claudedev-help`.

## Open items handed back to you

- Merge/no-merge of `codex/security-foundation-20260907` and of
  `claudedev-help` into `main` is the owner's call; the helper did not merge.
- r3821 / r3822 migrations remain undeployed candidates (per your commit
  messages). The helper did not deploy them.
- Local tooling note for this machine: Node.js and Python are **not installed**,
  so `supabase/tests` (PGlite) and `scripts/test_cron_response_summary.py` can
  only be exercised in GitHub Actions here. Gradle (JDK 17) works locally.
