# Android continuation: lime/ink foundation and shared actions

> Newest continuation: [13 September shared inputs](HANDOFF_ANDROID_UI_2026-09-13.md).
> Fields/dropdowns are locally accepted at `694bf690`; the foundation/action
> record below remains historical evidence. Continue from the newer handoff.

## Latest saved UI milestone

Continue from `codex/auth-integration-20260911` in
`C:/Users/lokes/Documents/Codex/2026-09-07/im/work/equipseva-auth-integration-20260911`.
Base for this UI delivery: `667f134a72d747c78a11a10544c2cdf929b649bb`.

| Commit | Scope |
| --- | --- |
| `be8f42a1322fc8ca906fe951af45d57feb13f773` | UI-01 candidate: semantic light/dark theme, bundled fonts/locale mapping, type/shape roles, fixed-light compatibility and focused tests. |
| `c7da5ee333d3913bf98052c9c20f81b3b56f6d38` | UI-02 shared actions: growing 48/52dp controls, paired states, localized loading, real focus and wrapping/scrolling compact payout actions; font-notice byte preservation. This commit contains the final tested app source. |

**UI-01 foundation + UI-02 shared actions accepted locally:** critic **9.595/10**,
QA **9.58/10**, with every applicable critical dimension at least 9.5. See the
[evidence index and previews](evidence/ui-foundation/README.md),
[source/build/packaging ledger](evidence/ui-foundation/verification.json),
[critic](evidence/ui-foundation/critic-review.md) and
[QA](evidence/ui-foundation/qa-review.md). The evidence/dashboard receipt commit
follows this source commit; obtain its SHA from Git to avoid a self-reference.

Final command: `:app:testDebugUnitTest :app:lintDebug :app:assembleDebug
:app:assembleRelease --max-workers=2 --no-configuration-cache --no-daemon`, with
the existing documented `PRECHECK_LOOSE=1` compile mode and Git Bash on PATH.
**3,155 tests / 359 suites, zero failures/errors/skips**. Lint zero errors,
82 warnings and two hints. Debug and unsigned release assembly passed in 6m 24s.
All 791 captured source/configuration hashes match before, after and after commit.
The first full build's additional test-helper naming warning was fixed; its log
and all prior expected/diagnostic failures remain recorded.

Both APKs contain all ten font hashes, four original notices and provenance.
The R8 release is 19,098,004 bytes, under the existing 28 MiB limit. **It is
unsigned:** apksigner rejects it. A strict release dry-run still refuses the
missing keystore; missing expected-certificate configuration remains open.
Build scripts, permissions, legacy palette constants and original logos are
unchanged. No main merge, provider-account journey, migration or signed release
belongs to this delivery.

Raw evidence: sibling `work/verification/ui-foundation-20260912/`. The build slot
was returned to FREE after all Gradle work ended; recheck before the next build.
Preserve other worktrees and fetch before committing. No model-setting question
is needed.

The milestone dashboard records APP-02, sequence 4, against this source SHA with
a timestamped quota/agent snapshot. Animations do not count work. Whole-app
completion and active hours remain unmeasured; UI slice ratings do not fill the
Android release gates or verify public hosting.

The updated dashboard data passed all 26 existing dashboard/delivery tests.
Public staging package: `outputs/progress-app02-release-20260912` under the
workspace root. Earlier APP-01/HQ packages are historical; no DNS, Worker or
GoDaddy publication was performed by this UI milestone.

Next: finish UI-02's remaining fields/cards/status/navigation/dialogs/sheets and
common states, then UI-03 auth-entry pages, following the approved page plan.
This is not acceptance of all 98 pages, every legacy dark surface, physical-device,
TalkBack/IME, process/Activity restoration or native-language review. A3/A4/A12,
dependency triage and provider/signing/main gates remain open. Preserve successful
A1/Room v5/A2/A10 behavior and the separate visual/security commit boundaries.

## Earlier milestone record (historical)

> Planning decision, 12 September 2026: the owner selected supplied lime/
> ink/soft-white references with Space Grotesk headings and Inter body text, and
> requested page-by-page planning before implementation. Read
> [UI_THEME_PAGE_PLAN_2026-09-12.md](UI_THEME_PAGE_PLAN_2026-09-12.md) and its
> `ui-renewal/` appendices first. The plan inventories 98 screen declarations plus
> modal/role/system variants. First implementation is UI-01 fonts/theme, then
> UI-02 shared components. No application implementation of this selected theme
> occurred in the planning pass; prior component ratings below are historical.
> The A3/A4/A12, dependency and release gates still apply.

Continue from `codex/auth-integration-20260911` in
`C:/Users/lokes/Documents/Codex/2026-09-07/im/work/equipseva-auth-integration-20260911`.
Original coordinator and helper checkouts remain intact. Fetch before any new
commit; do not reset, clean or switch somebody else's checkout. Read the shared
build-slot file before Gradle and preserve another session's reservation.

## Saved implementation

| Commit | Scope |
| --- | --- |
| `e58c48c2774a77aa0e725f1945da4e48a0fd5873` | Preserves three pre-existing A3 dispatch/policy/test edits as WIP; 17 passing route tests do not accept A3. |
| `e22c7c5b60b0a9e82f53efb733f427758f82d4b0` | A2 explicit button/radio color pairs and A10 current-auth admission/publication plus fetched-row ownership. |
| `7f3c5eaa8c8ae218433f3217b86ea34e9a08691b` | Welcome redesign, 11 focused tests, three locales and simulated render evidence. This commit contains the complete tested application source. |

The evidence/dashboard receipt commit follows these implementation commits;
its SHA is obtained from the branch, avoiding a self-referential commit record.
No main merge, production migration, provider change or application deployment
belongs to this delivery. Independent critic and QA accepted the two local slices:

| Scope | Critic | QA |
| --- | ---: | ---: |
| A2/A10 | 9.62 | 9.50 |
| Welcome component | 9.59 | 9.50 |

Every applicable critical dimension reaches 9.5. The reports and final source
binding are in [verification.json](evidence/auth-integration/verification.json),
[critic-review.md](evidence/auth-integration/critic-review.md) and
[qa-review.md](evidence/auth-integration/qa-review.md). Ratings do not accept the
whole app, full authentication, device/provider workflows or a release.

## What changed

A10 rejects stale account requests/results even when the full auth observer
lags. Returned engineer rows must belong to the captured user. Immediate auth
probes fail closed and cancel if suspended; network I/O does not block the auth
collector. Unknown retires the owner and clears status. Thirty-five synthetic
cases retain valid fresh recovery, observed relogins, duplicate/email events,
noncooperative work and cleared-host protections. Wholly unobserved same-ID
boundaries remain a repository limitation. No production post-KYC manual-refresh
caller was added or certified.

A2 controls now pair all enabled/disabled foreground/background colors. Actual
button contrast is at least 5.5605:1 and radio ink at least 5.5811:1 in both
themes. Thirteen role UI cases pass; existing root/session/role behavior remains.

Welcome now explains the two audiences, prioritizes Sign in, keeps Create
account secondary and separates Terms/Privacy. It scrolls at large text, retains
the logo and uses explicit Seva colors. EN/HI/TE and short landscape are tested.
All eleven text items have actual contrast at least 8.3127:1. Public callbacks,
legal destinations and auth policy are preserved. [Preview and limitations](evidence/welcome-ui/README.md).

## Verification and environment

JDK: `C:/Program Files/Microsoft/jdk-17.0.19.10-hotspot`.
SDK: `C:/Users/lokes/Android/Sdk`. Add `C:/Program Files/Git/bin` to the current
process PATH so the existing Bash release precheck can execute. Do not edit or
exclude that guard. The local SDK property requires the escaped drive colon.

```text
PRECHECK_LOOSE=1
.\gradlew.bat :app:testDebugUnitTest :app:lintDebug :app:assembleDebug :app:assembleRelease --max-workers=2 --no-configuration-cache --no-daemon
```

**3,110 tests / 355 suites / zero failures, errors or skips.** Lint: zero errors,
82 warnings, two hints. Debug and unsigned R8 release assembly passed. The first
final command freshly ran all tests and lint, then failed starting Bash. Recovery
used the same source and reused successful unit/lint outputs; the final command
passed in 4m 1s. All 768 source/configuration hashes match before, after and after
commit. Earlier test, oracle, lint and process-start failures remain recorded.

Strict release still refuses missing keystore configuration. The loose precheck
warns about missing certificate/signing configuration; its public assetlinks
probe passed. `apksigner verify` confirms `app-release-unsigned.apk` **does not
verify**. This is an unsigned artifact, despite the old precheck's debug-fallback
wording. It is not a production or signing-verified release.

Complete raw logs/XML/images are in the sibling
`work/verification/auth-integration-20260912/`; selected evidence is committed.
The slot was returned to FREE after Gradle completed. Recheck it on resume.

## Dashboard major milestone

APP-01, sequence 3, records this verified implementation SHA. It refreshes only
the major milestone data, observed agent statuses and the timestamped Codex quota
snapshot. Decorative animations do not count work or progress. Twenty-six
dashboard tests pass after the data update. Whole-app completion remains not
measured and active hours not tracked. Android release-gate fields remain empty
and locked; these component ratings cannot approve main.

The refreshed staging package is `outputs/progress-app01-release-20260912`
under the workspace root. Earlier HQ-02 packages are historical. Public hosting
is still unverified; this app milestone changes no Worker, DNS or GoDaddy setting.
See the dashboard handoff for the existing Chrome file-upload permission blocker.

## Next work

The milestone push still reports **one HIGH default-branch dependency alert**:
[Dependabot 17](https://github.com/ganeshnaik166/equipseva-android/security/dependabot/17).
This is an observed GitHub notice, not an audited vulnerability assessment. Triage
it before main/release integration; the component scores do not close that alert.

1. Freeze A3's account-owned notification admission/delivery contract against
   current source. Reconcile signed-out drop versus authenticated cold start,
   queue capacity/order and exact accepted payloads. The existing policy and
   dispatch checkpoint are hypotheses plus WIP, not end-to-end security closure.
2. Implement A4/A12 captured-account mutation/cleanup/token ownership with late
   A-to-B and relogin barriers before accepting dependent account workflows.
3. Continue bounded SignIn/SignUp/Profile accessibility from the saved inventory,
   preserving provider, role, recovery and business rules. Then validate complete
   hospital and engineer journeys with real devices and representative users.

Keep A7 signup carryover, wholly unobserved identity boundaries, server/API denial,
Auth/Storage/FCM providers, TalkBack/keyboard/IME/insets, native-language review,
whole-code audit, production cron/migrations and signed release explicitly open.
Do not request model-setting confirmation. Continue authorized work with concise
updates and independent scoped critic/QA gates.
