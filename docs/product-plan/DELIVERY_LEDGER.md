# Delivery ledger — four-persona EquipSeva

Updated 26 September 2026. Governing decisions: [PRODUCT_PLAN.md](../../PRODUCT_PLAN.md).

This is a requirements/evidence ledger, not a percentage-complete counter. A design review does not accept an implementation. No app-wide numeric score is assigned.

## Source and branch reconciliation

| Item | Verified source | Meaning |
|---|---|---|
| Default branch at planning start | `6df0ec6ab1f92aaae6ac4e51e72f2c801ac51823` | Current main includes CI history-scan repair and existing UI safety net; not the broad quality candidate |
| Application candidate inspected | `ccda4e4addef7e995f6e55a106c703dbee7af253` | Existing foundation/theme/auth/quality work preserved; draft PR1877 remains unaccepted |
| Planning branch | `codex/product-plan-20260919`, isolated checkout | Documentation only; does not pull unaccepted app code into main |
| Existing app verification | 3,675 unit tests, 3 cleanup failures; lint/debug/unsigned release assembly passed in recorded checks | Tests are prior evidence at recorded source, not rerun by this planning pass; unsigned assembly is not a release |
| Existing visual verification | 116 changed Roborazzi cases; 2 manually sampled in the prior review | 114 not individually inspected there; no golden refresh or screenshot acceptance claimed |
| Earlier work | A1, Room v5, A2/A10 and accepted theme/component slices | Preserve their recorded contract tests; new tenant boundaries expand rather than repeat them |

Source status is available in [the candidate handoff](https://github.com/ganeshnaik166/equipseva-android/blob/ccda4e4addef7e995f6e55a106c703dbee7af253/docs/HANDOFF_QUALITY_INTEGRATION_2026-09-19.md). Evidence from that branch is not implied to exist on main. Fetch before each integration; keep other worktrees and helper branches intact.

## Requirement matrix

Statuses: **planned**, **partial** (some reusable implementation), **blocked** (known unmet gate), **verified scoped** (named evidence only). No row is marked accepted from design alone.

| ID | Outcome | Design | Implementation | Main integration | Required release evidence |
|---|---|---|---|---|---|
| P0 | Governing plan and 98-page carry-forward/new-page tree | Critic 9.5 / QA 9.6, planning only | Documentation and seven-page PDF | PR1879 merged at `24e01999`; portable continuity PR1880 merged at `62da836f` | Not an app-release gate |
| P1.1 | Captured login ownership and safe cleanup | Concrete boundary plan | Partial overall: P1a AMC guard `434663c0` plus test polish `8d80ba3c`; P1b real Room outbox guard `5b5fa68b` plus fixture `ed9de0c3`; P1c local token capture/draft fence/cancellation `ed7a5397` plus disk/fixture tests `04aa5729`. Each scoped critic and QA **9.6/10**. Latest full **3,765/0** with lint/debug/unsigned R8 green | Broad candidate/draft PR1877 blocked from main; P1b safe docs reached main via PR1883; [P1a](../HANDOFF_P1A_AMC_CLEANUP_2026-09-19.md), [P1b](../HANDOFF_P1B_OUTBOX_CLEANUP_2026-09-20.md), [P1c](../HANDOFF_P1C_TOKEN_CAPTURE_2026-09-26.md) handoffs | Remaining resource ownership, producers/readers/confidentiality, final SDK logout, SQLCipher/device/ordinary logout; remote token claim/release and sender privacy before app/main acceptance |
| P1.2 | Cancelled logout/account restoration retires stale work | Planned; existing S3 finding | Partial, earlier scope critic 9.2 | Blocked candidate | Root/session/router integration, logout and same-ID relogin |
| P1.3 | Safe owner/workspace queue, photos, caches and push | Architecture mapped; [P1d source gap](../helper-reviews/codex-20260926/p1d-remote-token-gap.md) and [security critique](../helper-reviews/codex-20260926/p1d-contract-critic.md) | Partial local P1a–P1c protections; P1d-0 sender privacy/classification at `85b91ddd` locally accepted by [critic](../helper-reviews/codex-20260926/p1d0-critic.md) and [QA](../helper-reviews/codex-20260926/p1d0-qa.md), **9.6/10 each**. Node and Deno 1.46/2.9 synthetic tests **13/0** each, both Deno versions pass function check and full touched-file lint; [handoff](../HANDOFF_P1D0_SENDER_PRIVACY_2026-09-26.md). Device/provider/Supabase deploy pending. Tracked `device_tokens` DELETE revoke still conflicts with client DELETE-before-upsert; live grants unknown | Sender-only branch not integrated; remote claim/release and app candidate remain blocked | Selectively port sender commits to fresh main, then CI and provider/shared-device pilot; actual DB schema, narrow versioned claim/release/reap, concurrent races, old-client rollout, delayed producers/readers, process death, revocation and reconnect |
| P2.1 | Tenant membership, capabilities and immutable job parties | Planned source-bound migration | Existing hospital organisations/chain hierarchy only | New team model absent | Direct cross-tenant REST/RPC/storage/realtime/export denial tests |
| P2.2 | Versioned State/UT and district contract | Planned | Existing string catalog and selection fields | Names only in current app | Dated LGD asset, server pair validation, legacy alias/rollback tests |
| P2.3 | Region/registration presentation contracts | Bounded preparation reviewed | Unused intent/region draft types at `d202cb38`; 45 targeted tests pass, critic 9.5 / QA 9.6 for four files only | Candidate only; no live role/UI wiring | Canonical region, UI and server authority gates still required |
| P3.1 | Three-choice entry and returning-user workspace selection | Planned | Existing two-persona live root only | New org entry absent | Native auth/provider recovery; no paid/global-role shortcut |
| P3.2 | Hospital/team claim, invitation, removal and owner transfer | Planned | Reuse existing account primitives only | New team flows absent | Forgery, last-owner, stale invite, wrong account and revocation tests |
| P3.3 | Synthetic isolated demo | Planned | New | Absent | Network/mutation spy proves no live effects; demo/live cache separation |
| P4.1 | SaaS billing and entitlement state machine | Planned | Existing AMC payment code is not this feature | Absent | Correct distribution-channel billing; real provider sandbox + webhook races |
| P4.2 | Seats, renewal/cancel/restricted access and receipts | Planned | New | Absent | Atomic concurrent seat admission, paid-through/grace/time-bound writes |
| P5.1 | Hospital request-to-completion journey | Page map complete; changes planned | Substantial legacy flow, selected fixes | Partial older UI | Both-party device workflow, money/evidence/offline/error contracts |
| P5.2 | Engineer discovery-to-payout journey | Page map complete; changes planned | Substantial legacy flow, selected fixes | Partial older UI | Eligibility, assignment, attendance, evidence, payment/provider cases |
| P5.3 | District discovery and map-free attendance | Planned | Old discovery/GPS dependencies remain | Absent | Server/API/old-client migration, collusion/manual-review controls |
| P6.1 | Team home, invitations, dispatch and business reports | New page plan | New | Absent | Team isolation, assignments, conflicts, member removal and expiry |
| P7.1 | Remaining account/chat/AMC/admin redesign | Full page carry-forward map | Partial reusable components/legacy screens | Partial | Reviewed images, accessibility and affected runtime flows (English only) |
| P7.2 | Complete owned-source review and dependency disposition | Review plan + bounded existing audits | Incomplete | Some fixes integrated | Final-hash review ledger; open HIGH/security/payment findings closed |
| P8.1 | Signed/minified device and provider pilot | Planned | Unsigned assembly evidence only | Not released | Physical-device/provider/TalkBack; human hospital, engineer, team-owner/dispatcher and platform-operator tasks |
| P8.2 | Operations, capacity, privacy and incident readiness | Planned | Existing CI/cron/monitoring primitives | Partial | Restore exercise, load profile, alerts, lawful retention and runbooks |

## First implementation contract

**P1 remains the first live-behaviour milestone.** Repair cleanup ownership using the [existing concrete plan](https://github.com/ganeshnaik166/equipseva-android/blob/ccda4e4addef7e995f6e55a106c703dbee7af253/docs/helper-reviews/codex-20260919/signout-ownership-plan.md).

1. Keep all three reproduced failing cleanup assertions and ordinary-cleanup control. Capture user + SDK session identity/generation before the first suspension; do not recapture a future user.
2. Add real DataStore transform-admission and Room transaction-admission barrier tests before changing cleanup. Include A→B, A→signed-out→A, cancellation, same payment ID with a newer revision and fresh successful cleanup.
3. Validate the departing owner inside each actual serialized mutation. Extend to stash/cache/worker/realtime teardown and all logout callers before calling full S1 accepted. A DTO, reordered call, mutex precheck or three newly green mocks alone is insufficient.
4. Prove a suspended SDK logout cannot sign out a replacement user, and interrupted recovery cannot restore old drafts/router envelopes. Fresh valid work after recovery must still succeed.
5. Freeze source; run targeted tests, appropriate full unit/lint/debug/R8 checks; independent critic and QA review exact diff/evidence. Existing screenshot/payment/security blockers remain explicit even if this slice passes.

**Independent preparation is allowed:** implement a separate three-option public registration-intent type and a region-selection draft with parent/child validation. These must not extend the backend `UserRole` enum, issue `add_role`, claim an organisation membership, persist a subscription entitlement, or navigate into a fake admin workspace. Tests precede implementation. Such code is foundation preparation until UI and authoritative server contracts are wired; it is not completion of P1 or a shipped organisation feature.

## Acceptance matrix required for each branch

| Class | Minimum cases |
|---|---|
| Identity/workspace | Signed out, unknown, A→B, A→out→A, same login token refresh, same user other workspace, membership removal, stale response and current success |
| Authorisation | Foreign tenant/object/attachment/invite/payment IDs, guessed admin routes, tampered claims, unverified role, paid but unauthorised member, revoked member with cached token |
| Billing | Pending/success/cancel/refund/revoke, duplicate and reordered webhooks, provider timeout after charge, two concurrent purchases, stale workspace, seat-limit race, expiry during active service |
| Demo | No production repository access, no real push/jobs/messages/payments/exports; clear labelled state; safe exit/restart/reset; fake data cannot be promoted |
| Geography | Missing/unknown/retired codes, wrong state/district pair, renamed district, cross-state coverage, stale catalog refresh, offline selection and historical job snapshot |
| Abuse/integrity | Forged or replayed attestation, modified package/signature, unavailable attestation, fake claim, copied evidence, collusion, takeover, member/owner abuse and human appeal |
| UI/runtime | Light/dark, English copy only (owner decision 23 September 2026), 320/360dp and 2x fonts, keyboard/Back/IME, loading/empty/error/offline/pending/denied; device/photo/provider return and process restart |
| Operations | Tenant-bound load mix, query/index plans, queue recovery, webhook backlog, safe logs, backup restore, signing and symbol upload |

Record **synthetic**, **source-inspected**, **local executed**, **hosted CI**, **staging/provider**, **device**, and **human** evidence separately. Never promote one class to another.

Human acceptance includes representative hospital request/approval/dispute tasks; independent and team engineer discovery/visit/evidence/recovery; team-owner demo/signup/checkout/invite/dispatch/removal/billing recovery; and platform-operator scoped verification/support/dispute tasks. Record participant counts/context, task completion, errors, recovery paths, accessibility/language limitations and resulting changes. A solo founder's walkthrough is useful evidence but cannot be presented as representative external hospital/team validation.

## Critic / QA review contract

Frozen rubric per applicable scope: correctness 25; security/privacy 25; recovery/data/money 20; usability/accessibility 15; visual consistency 10; performance/operations 5. Both independent critic and QA scores must meet 9.5, and applicable critical dimensions must also meet 9.5. Missing mandatory evidence means unaccepted, not an assumed 9.5.

Planning reviews assess completeness, feasibility, source reconciliation, threat coverage and testability only. Reviewers must list exclusions. Implementation, integration and release require their own evidence/reviews. No numeric score certifies that fraud, root detection or hacking is impossible.

## Integration and branch discipline

- Publish the documentation plan separately through a PR to main, then put its link first in README. This does not merge draft PR1877 or deploy any schema/payment changes.
- Reconcile the new plan into the candidate before coding against it. One file owner per parallel task. No simultaneous Gradle jobs: read the laptop's `outputs/equipseva-build-slot.md` before reserving and immediately before running; preserve another owner's reservation.
- Fetch before commit/push; push only the task's own branch. Preserve other worktrees. No force push, destructive cleanup, failing-test deletion, disabled gates or altered screenshot thresholds.
- Use forward schema/API migrations, explicit feature rollout and rollback acceptance. Do not reapply already-deployed round3822. Verify actual schema/RPC versions in an authorised staging environment before selecting production migration order.
- Each save handoff records exact base/head, changed files, actual test counts/failures, source-vs-runtime limitations, source of reviews and next step.

## Review and publication receipt

Independent [critic](reviews/CRITIC.md) **9.5/10** and [QA](reviews/QA.md) **9.6/10** accepted the bounded plan on 19 September 2026. Their reports pin the reviewed requirement content and explain that subsequent publication metadata is not an implementation review. Resolved findings include canonical stage IDs, consistent team navigation, explicit hospital-site scopes, personal-engineer ownership without organisation subscription, one subscription-access state contract, local-only launch demo, realistic offline revocation and human tasks for all four personas.

The PDF overview is a separate rendered summary of this plan; it requires visual inspection and is not included in those agents' documentation scores. Publication is recorded in [PUBLICATION.md](PUBLICATION.md); no app candidate, production schema, paid entitlement or map-removal rollout is accepted by publishing these documents.
