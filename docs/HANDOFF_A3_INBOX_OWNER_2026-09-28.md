# A3 prerequisite: notifications inbox observed-owner fence (28 September 2026)

## Resume point

- Later integration: [PR1909](https://github.com/ganeshnaik166/equipseva-android/pull/1909) merged to main `eba0d8e3ae4ef14844c141de983b86577f5b2868`. Exact-head hosted Android debug/release R8 (both push and PR), verify goldens and two Gitleaks checks passed. Exact-merge main-push Android unit/lint/design ratchet/debug/release R8 and mapping upload, goldens, Gitleaks, Pages build/deploy and status all succeeded; record-goldens was skipped.
- Branch: `codex/a3-inbox-owner-20260928`; isolated owned checkout: `work/equipseva-status-20260927`.
- Fetched `origin/main` base: `2bdbfe15dad4a23efb79deb0fac9f59e1d28264e`. Reviewed source/test commit: `1ff859cee8b8e3b48b3e8f60c0ae9373ed7f9d27`.
- This is a bounded prerequisite for A3-02, **not** a fix for the cross-account deep-link router or an app release. Do not merge the RED A3-02 PR1897 by association.
- Only `NotificationsInboxViewModel.kt`, the notification-row/mark-all callback in `NotificationsScreen.kt`, and new `NotificationsInboxOwnerTest.kt` changed in the implementation commit. No auth SDK/repository, router/host, SQL, notification repository/outbox worker or other checkout was edited.

## Behavior and threat boundary

The old ViewModel took the first `SignedIn` session forever. A retained inbox could show A's rows after sign-out or direct A→B, and late A refresh/read results could affect B's UI or serialize B's live ID into an A notification read payload.

The ViewModel now processes every **observed** session event without waiting for network I/O. On a changed or invalid owner (`SignedOut`, `Unknown`, blank ID), it cancels old owner work, increments a generation and clears rows before starting a fresh subscription. Same-ID/email-only duplicates retain the stream; A→B→A and sign-out→same-A create new generations. Stream, refresh, mark-read and mark-all completions are fenced by the exact owner object. Offline read payloads capture the initiating owner ID. A stale rendered row or mark-all callback cannot act on a later generation, even when the notification ID is reused. Pull-to-refresh now publishes its query only if no newer row update won, keeps the spinner through stream reconnects, fences request order and ends at three seconds even when the query ignores cancellation.

This fence covers **observed presentation and action callbacks**. The installed auth SDK may conflate an unobserved A→B→A transition, and an already-submitted mutation may outlive the UI cancellation. Server RLS, repository mutation-time identity and outbox replay gates must be assessed separately. The final deep-link navigation owner/role check and buffered router policy are still A3-02 work. The Compose callback has source review plus ViewModel guard tests, but no direct Compose interaction test or device/TalkBack run. Existing 36dp mark-all/settings targets remain accessibility debt outside this security slice.

## Verification and review

- First synthetic owner-boundary suite against unchanged production: **13 tests, 12 expected failures**. After initial repair: **13/13**, then expanded **15/15**.
- Reviewer-discovered refresh/reconnect and noncooperative-timeout regressions: **19 tests, 2 expected failures** before repair; **19/19** after. Final A→B→A callback case brought the focused class to **20/20**, zero failures. Tests are offline and use fake sessions, MockK and deliberately noncooperative replies.
- Frozen source `1ff859ce`: full `:app:testDebugUnitTest :app:lintDebug :app:assembleDebug --offline --console=plain` exited **0**; **2,985 tests / 350 suites / 0 failures or errors**, lint **0 errors / 87 warnings / 2 hints**, debug assembled. Bundled Python `-X utf8 scripts/verify/design_lint.py` passed. Local Gradle logs are in `outputs/a3-inbox-owner-*20260928.log` outside Git.
- An initial combined release attempt failed *before verification* on the missing-keystore build guard. A second attempt with `PRECHECK_LOOSE=1` reached `preReleaseCheck`, which failed because `bash` is unavailable on this Windows shell. The local, deliberately unsigned/non-shippable R8 assembly below passed with that precheck and Crashlytics mapping upload excluded; it cannot count as signed release acceptance.
- Independent critic and QA each initially rated **9.3/10, blocked**. After the refresh race and coverage fixes, both re-reviewed the frozen source/test diff at **9.6/10**, no mandatory source blocker for the observed-owner inbox scope. They did not run Gradle. Hosted exact-head CI, main integration and main-push checks later passed as recorded above; device and signed-release gates remain separate.

## Next actions

1. Verify final Git cleanliness and fetched `origin/main` base. Recheck the shared Gradle slot before any repeat build. This task released its reservation and stopped its daemon at 07:26:25 UTC.
2. Publish this completed main/CI receipt to main through a docs-only PR. Preserve the exact source, review and unsigned-release limits above.
3. Resume the separate A3-02 RED candidate only after this prerequisite is integrated. A read-only follow-up found that a safe manual recovery must **discard** an ambiguous external tap/target and let the user open Notifications anew from Home/Profile. Queuing an external `Routes.NOTIFICATIONS` event retains the replay risk. The three retained RED same-ticket tests cannot be closed with router-only state if auth-kt emits no mutation-time epoch. Preserve those failures while designing an explicit fail-closed contract or an SDK-authored epoch; do not silently rewrite tests to claim acceptance.

## Local release result

PowerShell command `$env:PRECHECK_LOOSE='1'; .\gradlew.bat :app:assembleRelease -x :app:preReleaseCheck -x :app:uploadCrashlyticsMappingFileRelease --offline --console=plain` exited **0**; release Kotlin, lint-vital, R8, resource optimization and `assembleRelease` completed. `PRECHECK_LOOSE` intentionally allows a local unsigned/non-shippable artifact. The actual `preReleaseCheck` was not passed, signing credentials were absent, and Crashlytics mapping was not uploaded locally. Log: `outputs/a3-inbox-owner-unsigned-release-20260928.log` outside Git. Hosted main-push CI later uploaded an R8 mapping artifact; a properly signed release remains an independent gate.
