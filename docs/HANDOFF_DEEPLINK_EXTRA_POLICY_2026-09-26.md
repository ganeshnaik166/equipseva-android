# A3-01 external deep-link route boundary — WIP, 26 September 2026

## Scope and base

- Isolated worktree `work/equipseva-deeplink-policy-20260926`, branch `codex/deeplink-extra-policy-20260926`, fetched `origin/main` base `afe2bd33cdc37ca842b921c9817d75cdc645fc74`.
- Own only `DeepLinkRouter.kt`, new `DeepLinkPolicy.kt`, new `DeepLinkRouterExternalIntentTest.kt`, and this slice's continuity records. No activity, FCM service, host, root-auth or notification-parser mutation.
- An exported `MainActivity` receives `EXTRA_ROUTE` from its own FCM PendingIntent and can receive the identical extra from another app. The pre-fix router forwarded the extra verbatim to `MainNavGraph` navigation, including founder and account-change routes. Server RLS still protects data, but the UI injection/social-engineering path is real.

## Test-first evidence

- First targeted run compiled, then failed **4/4 before assertions** in the Robolectric application bootstrap (`SettingsUtil.kt:11`, default Supabase settings). This is an invalid fixture result, not behavioral RED. Log: `C:/Users/lokes/Documents/Codex/2026-09-07/im/outputs/deeplink-external-red-20260926.log`.
- Test-only fixture correction: `@Config(application = android.app.Application::class, sdk = [35])`, consistent with other synthetic Compose/Robolectric tests. No production file was changed before the rerun.
- Corrected targeted RED command: `PRECHECK_LOOSE=1 ./gradlew.bat :app:testDebugUnitTest --tests com.equipseva.app.navigation.DeepLinkRouterExternalIntentTest --no-daemon --console=plain`. **4 tests, 3 behavioral failures**, Gradle exit 1 on the original router: privileged extra, malformed route, and invalid-extra/valid-App-Link fallback. The legitimate-route control passed. Log: `C:/Users/lokes/Documents/Codex/2026-09-07/im/outputs/deeplink-external-red-retry-20260926.log`.

## Candidate and remaining gates

### 27 September targeted update

Claude released the slot at 15:59:12 UTC on 26 September; Codex rechecked it and reserved it for A3. Test commit `2948ff16` bounds absent-event waits. On the initial allow-list the 7-test focused class failed exactly the founder and role-specific safe-inbox targets (**7/2**, log `outputs/deeplink-fallback-red-20260927.log`). After removing direct `KYC` and engineer AMC visit admission and adding an exact five-route inbox fallback after valid App Link precedence, the unchanged class passed **7/0**, log `outputs/deeplink-fallback-green-20260927.log`. Both runs used `PRECHECK_LOOSE=1 .\\gradlew.bat :app:testDebugUnitTest --tests com.equipseva.app.navigation.DeepLinkRouterExternalIntentTest --no-daemon --console=plain`; design ratchet passed. This is targeted local evidence only. Full checks, final critic/QA, latest-main reconciliation and hosted CI remain open; no A3 acceptance or main merge.

At the 26 September checkpoint, Claude's `claudedev-build-20260923` audit held the shared build slot, and the newer fallback-target tests were unrun. The 27 September update above supersedes that hold and records their RED/GREEN results.

`DeepLinkPolicy` admits only selected fixed notification/App-Link landings and job/chat/engineer/AMC detail IDs with strict shapes. The router checks every `EXTRA_ROUTE` against it; a rejected extra may fall back to an independently validated HTTPS App Link. The five known founder/KYC/AMC-visits notification destinations instead land in the authenticated inbox. Do not describe this as founder or server authorization.

Independent initial WIP critique found that simply dropping three real founder queue push routes stranded their notification taps on the default screen. It also identified `KYC` and `ENGINEER_AMC_VISITS` as role-specific destinations without a per-route UI role gate. Test-only commits `a831cd85` and `b2985f7d` specified an inbox landing for those five actual notification destinations and valid-App-Link precedence. The 27 September targeted update above records their RED/GREEN.

**Implementation is not yet fully verified or accepted.** Focused RED/GREEN and design ratchet are done. Run appropriate full unit/lint/debug/unsigned-R8 checks after latest-main reconciliation; obtain independent critic and QA ≥9.5 on the frozen diff; then hosted CI before main. No device, release signing or real account was used.

Separate HIGH A3-02 remains: `DeepLinkRouter` and `DeepLinkHost` buffer routes across login boundaries, so an A push/link can replay into B. Also open: A3-03 activity recreation redelivery, recipient binding, founder-only in-app gates, and server object authorization. Do not claim the entire deep-link/security program closed from this policy slice.

An independent read-only [A3-02 owner-replay plan](helper-reviews/codex-20260926/a3-02-owner-replay-plan.md) records source seams, synthetic test cases and merge ownership. It does not change the A3-01 implementation or satisfy its missing GREEN/review gates.
