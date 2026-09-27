# A3-01 external deep-link route boundary — local scoped acceptance, 27 September 2026

## Scope and base

- Isolated worktree `work/equipseva-deeplink-policy-20260926`, branch `codex/deeplink-extra-policy-20260926`, fetched `origin/main` base `afe2bd33cdc37ca842b921c9817d75cdc645fc74`.
- Own only `DeepLinkRouter.kt`, new `DeepLinkPolicy.kt`, new `DeepLinkRouterExternalIntentTest.kt`, and this slice's continuity records. No activity, FCM service, host, root-auth or notification-parser mutation.
- An exported `MainActivity` receives `EXTRA_ROUTE` from its own FCM PendingIntent and can receive the identical extra from another app. The pre-fix router forwarded the extra verbatim to `MainNavGraph` navigation, including founder and account-change routes. Server RLS still protects data, but the UI injection/social-engineering path is real.

## Test-first evidence

- First targeted run compiled, then failed **4/4 before assertions** in the Robolectric application bootstrap (`SettingsUtil.kt:11`, default Supabase settings). This is an invalid fixture result, not behavioral RED. Log: `C:/Users/lokes/Documents/Codex/2026-09-07/im/outputs/deeplink-external-red-20260926.log`.
- Test-only fixture correction: `@Config(application = android.app.Application::class, sdk = [35])`, consistent with other synthetic Compose/Robolectric tests. No production file was changed before the rerun.
- Corrected targeted RED command: `PRECHECK_LOOSE=1 ./gradlew.bat :app:testDebugUnitTest --tests com.equipseva.app.navigation.DeepLinkRouterExternalIntentTest --no-daemon --console=plain`. **4 tests, 3 behavioral failures**, Gradle exit 1 on the original router: privileged extra, malformed route, and invalid-extra/valid-App-Link fallback. The legitimate-route control passed. Log: `C:/Users/lokes/Documents/Codex/2026-09-07/im/outputs/deeplink-external-red-retry-20260926.log`.

## Candidate and remaining gates

### 27 September merged-head verification

Claude released the slot at 15:59:12 UTC on 26 September; Codex rechecked it and reserved it for A3. Test commit `2948ff16` bounds absent-event waits. On the initial allow-list the 7-test focused class failed exactly the founder and role-specific safe-inbox targets (**7/2**, log `outputs/deeplink-fallback-red-20260927.log`). After removing direct `KYC` and engineer AMC visit admission and adding an exact five-route inbox fallback after valid App Link precedence, the unchanged class passed **7/0**, log `outputs/deeplink-fallback-green-20260927.log`. Both runs used `PRECHECK_LOOSE=1 .\\gradlew.bat :app:testDebugUnitTest --tests com.equipseva.app.navigation.DeepLinkRouterExternalIntentTest --no-daemon --console=plain`; design ratchet passed.

Current main `133720a69b164c51d18d0bcf104a9bd3e3b51c36` was merged into the A3 branch without A3 source overlap. Frozen tested code head `cd13a272b91781983f02185c060d646c2e38997c`. Six merged-head deep-link/notification suites passed **72/0** (`outputs/deeplink-combined-targeted-20260927.log`). The full `:app:testDebugUnitTest :app:lintDebug :app:assembleDebug :app:assembleRelease --continue` run at that same source completed **2,927 unit tests / 345 suites / 0 failures, errors or skips**, lint **0 errors / 87 warnings / 2 hints**, and debug assembly; its overall exit 1 came solely from `:app:preReleaseCheck` failing to launch `bash` because Git Bash was absent from PowerShell PATH (`outputs/deeplink-combined-full-20260927.log`). No app code or release guard was changed to address this environment failure. A separate same-source retry with Git Bash on PATH and `PRECHECK_LOOSE=1` passed `:app:preReleaseCheck :app:assembleRelease`, including R8, **Gradle exit 0** (`outputs/deeplink-release-precheck-retry-20260927.log`). `PRECHECK_LOOSE=1` permits missing signing configuration; the resulting assembly is unsigned/debug-signed test output, not a shippable release.

Independent final [critic](helper-reviews/codex-20260927/a3-01-critic.md) **9.6/10** and [QA](helper-reviews/codex-20260927/a3-01-qa.md) **9.6/10** found no blocker for the exported-extra syntax/fallback slice. Neither score accepts the wider deep-link or security program. Branch CI, main integration, device behavior and signed release remain unverified.

At the 26 September checkpoint, Claude's `claudedev-build-20260923` audit held the shared build slot, and the newer fallback-target tests were unrun. The 27 September update above supersedes that hold and records their RED/GREEN results.

`DeepLinkPolicy` admits only selected fixed notification/App-Link landings and job/chat/engineer/AMC detail IDs with strict shapes. The router checks every `EXTRA_ROUTE` against it; a rejected extra may fall back to an independently validated HTTPS App Link. The five known founder/KYC/AMC-visits notification destinations instead land in the authenticated inbox. Do not describe this as founder or server authorization.

Independent initial WIP critique found that simply dropping three real founder queue push routes stranded their notification taps on the default screen. It also identified `KYC` and `ENGINEER_AMC_VISITS` as role-specific destinations without a per-route UI role gate. Test-only commits `a831cd85` and `b2985f7d` specified an inbox landing for those five actual notification destinations and valid-App-Link precedence. The 27 September targeted update above records their RED/GREEN.

**Local A3-01 slice accepted; hosted integration remains pending.** Test-first RED/GREEN, current-main reconciliation, merged-head unit/lint/debug/unsigned-R8 checks and separate independent critic/QA ≥9.5 are complete. Run hosted CI on the pushed candidate before main. No device, signed release or real account was used.

Separate HIGH A3-02 remains: `DeepLinkRouter` and `DeepLinkHost` buffer routes across login boundaries, so an A push/link can replay into B. Also open: A3-03 activity recreation redelivery, recipient binding, founder-only in-app gates, and server object authorization. Do not claim the entire deep-link/security program closed from this policy slice.

An independent read-only [A3-02 owner-replay plan](helper-reviews/codex-20260926/a3-02-owner-replay-plan.md) records source seams, synthetic test cases and merge ownership. It does not change the A3-01 implementation or close the separate replay gate.
