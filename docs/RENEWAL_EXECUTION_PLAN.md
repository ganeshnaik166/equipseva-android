# EquipSeva renewal execution plan

Started 7 September 2026 from `fe4637568059e49f27fb46f8627fe56bccc45e27`.
This continues the existing app and Claude's `UX_UPLIFT_PLAN.md`. It adds the
owner's requested workflow, security and independent quality program. A plan
or green build alone is not evidence that the app is ready for release.

## Verified starting point

- GitHub `main`, `ops/r1388-calendar-burndown`, and the original local checkout
  matched the revision above when this program started. The checkout was clean.
- The latest saved handoff is `HANDOFF_2026-09-07_0645UTC.md`. Earlier instructions
  describing main as frozen are obsolete. Fetch and check again before committing.
- The original application change is round3820; the handoff records production
  migrations through round3819. Production has not been re-audited by this program.
- The original checkout's unit/lint/debug build command passed on 7 September;
  Gradle reused current outputs. Its XML reports contain 2,791 tests across 332
  suites, zero failures, errors or skips. This is a baseline, not a fresh run of
  every test or an end-to-end assessment of the two user journeys.
- A fresh emulator run passed the two existing boot/package tests on the eqs
  Android 15 emulator. These tests do not establish both-role journey coverage.
- The recorded foreground session-idle test passed. Other session interruption
  scenarios, the actual photo evidence journey, daily cron confirmation, provider
  activation and the web-console baseline remain separate verification work.

## Product decisions

Keep Kotlin, Compose, the existing Supabase contracts, Seva green branding and
English/Hindi/Telugu support. Improve the existing product in reviewable slices.
Preserve data, payment truth and recoverable work throughout the redesign.

The hospital journey is: request service, compare suitable bids, confirm terms,
track the visit, review service evidence, and resolve completion or disputes.
The engineer journey is: find suitable work, quote, prepare for the visit,
check in, submit service evidence, and understand payment status. Each state
needs a clear primary action, an honest pending state, and a recovery route.

Use Google and email sign-in, retain existing accounts and recovery, and restore
the correct workspace after login. Role selection must complete successfully;
an unknown role must not silently acquire another role's interface or access.
Account recovery and sensitive account changes must support each login provider.

Navigation, visible actions and server permissions are reviewed together.
Progressive onboarding is a proposed workflow improvement, not permission to
bypass the current KYC, bank, UPI, payment or organization membership rules.
Any policy change needs a documented decision and server-side denial tests.

## Delivery sequence

| Milestone | Result | Acceptance evidence |
| --- | --- | --- |
| M0 | Reproducible baseline, route/state inventory, test environments and rollback | Exact source revision, build reports, both-role device smoke and reconciled handoff items |
| M1 | Security and data-retention foundations | Populated allow/deny fixtures, account/session race tests, durable upload recovery, sensitive-action checks |
| M2a | Reviewed login and both-role workflow prototypes | Route/action/eligibility matrix, error and offline states, accessibility review |
| M2b | Representative user validation | Observed hospital and engineer tasks; record participant counts, failures and limitations |
| M3 | Unified design system and visual regression coverage | Token/component rules, screenshots, large text, languages and accessibility evidence |
| M4 | Login, recovery, role and onboarding implementation | Provider and session matrix, interrupted-flow recovery, direct API denial tests |
| M5 | Hospital journey redesign | Request through completion/dispute, real pending/payment/evidence states |
| M6 | Engineer journey redesign | Discover through service evidence and payout status, interruption recovery |
| M7 | AMC, administration, web and remaining code audit | Scope-specific regressions and complete first-party file review ledger |
| M8 | Release candidate | Signed/minified device validation, provider sandbox/pilot checks, independent final gates |

The first M1 implementation slice is **evidence access and request-draft account
isolation**. It does not close all of M1. Attestation binding, durable photo
stages, provider-aware fresh authentication and privileged administration remain
explicit subsequent slices. Review and fix these foundations before accepting
dependent redesigned journeys. M0 and M1 may progress independently where safe;
neither is marked accepted while its mandatory evidence is missing.

M2a design preparation can proceed while engineering checks run. Human usability
validation is distinct from agent inspection. Reversible component work can
proceed after M2a, but accepting the full redesigned journeys requires M2b.

## Quality gate for every implementation milestone

The implementer supplies changes and evidence. A separate critic and QA reviewer
assess them independently. Their scores must each be at least **9.5/10** before
milestone acceptance. A score below the threshold causes another fix/retest cycle.

Freeze applicable scope, item points, justified non-applicable items and the
rubric before implementation. The governing category weights are:

| Dimension | Weight |
| --- | ---: |
| Task correctness and completion | 25 |
| Security and privacy | 25 |
| Resilience, retained work and money correctness | 20 |
| Usability, accessibility and localization | 15 |
| Visual consistency | 10 |
| Performance and operations | 5 |

Critical dimensions are task/state correctness, security/privacy, recovery/data/
payment integrity, and accessibility/localization for affected user journeys.
All applicable critical dimensions must also reach 9.5. Hard blockers override
the score: unresolved critical/high security or privacy defects; unauthorized
access; wrong/duplicate money movement or lost/corrupted evidence; blocked core
journeys; supported-configuration crashes/ANRs; missing mandatory tests; leaked
secrets; unsafe migration/rollback; and unsupported signed-release behavior.
Missing mandatory evidence means **not scored / not accepted**. Do not round up,
remove failed cases, relax screenshot tolerances, or average away a serious
defect. A scoped slice score does not become a full-app score. Automated tests
cannot substitute for real provider/device/human checks they do not exercise.

Every touched behavior has regression evidence proportional to its risk.
Security tests include populated foreign-user fixtures and direct API calls.
Account tests include late callbacks after logout, another account, and the
same account logging in again. Preserve existing successful paths as well as
denying invalid ones. Visual tests cover loading, empty, error, offline, pending
and success states, large text and all supported languages.

## Audit and working rules

- Work in an isolated branch/checkout while another session may use the original.
  Fetch before committing; never overwrite another session's changes.
- Review first-party source line by line with file hashes and evidence. A file
  inventory or keyword search is not a completed review. Track generated code,
  dependencies and historical migrations separately so counts remain meaningful.
- Whole-program completion requires 100% of owned first-party source, resource,
  configuration and script text line spans reviewed at their final hashes, all
  required non-source audit dispositions closed, every reproduced in-scope finding
  fixed and independently verified, and all mandatory runtime/release checks run.
  Freeze the exact denominator in M0; new files and changed hashes add or reopen
  review coverage. A partial pilot must never be called whole-program completion.
- Use forward database migrations. Test exact SQL locally before deployment;
  distinguish focused fixtures from a full migration-chain or staging test.
- Keep credentials, local account data and private audit notes out of Git.
  Ordinary development does not require copying signing keys or printing tokens.
- Before pushing application changes, run the repository's required unit tests,
  lint and release-assembly checks. An unsigned R8 build is not a signed release
  or a passing production-configuration gate.
- Record completed checks, remaining risks, next actions and the exact revision
  at each handoff. A background scheduler or a production deployment requires
  its own observed result; elapsed time is not proof of success.
- Routine reversible decisions continue while the owner is away. Authentication,
  unavailable provider credentials and unresolved commercial policy remain named
  dependencies; continue independent work rather than inventing successful results.

The detailed local planning pack contains the review ledger, issue register,
agent prompts and execution evidence. Keep this repository document concise and
update milestone status only when the required evidence actually exists.
