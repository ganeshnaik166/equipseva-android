# Android continuation: role/status fixes and Welcome UI

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
