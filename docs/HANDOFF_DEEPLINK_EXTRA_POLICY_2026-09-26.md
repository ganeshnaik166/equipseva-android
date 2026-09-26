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

The owner handed the shared build slot to Claude's `claudedev-build-20260923` audit at 15:26 UTC. Existing original-source RED is valid, but the two newer fallback-target test commits are unrun. Preserve their failing assertions and the current WIP policy. Do not launch Codex Gradle until Claude writes its explicit FREE release. This branch's current head and remote status must be rechecked after the WIP checkpoint commit/push.

`DeepLinkPolicy` admits only fixed notification/App-Link landings and job/chat/engineer/AMC detail IDs with strict shapes. The router checks every `EXTRA_ROUTE` against it; a rejected extra may fall back to an independently validated HTTPS App Link. This deliberately also rejects founder queue destinations from an external notification tap; the authenticated inbox remains their in-app path. Do not describe this as founder or server authorization.

Independent WIP critique found that simply dropping three real founder queue push routes strands their notification taps on the default screen. It also identified `KYC` and `ENGINEER_AMC_VISITS` as role-specific destinations without a per-route UI role gate. New test-only commits `a831cd85` and `b2985f7d` specify an inbox landing for those five actual notification destinations and valid-App-Link precedence. These tests have not run yet and the production fallback is not implemented at this checkpoint. They must fail against the current candidate before the fix, then pass unchanged afterward.

**Implementation is not yet verified or accepted.** Run the unchanged focused test for the new fallback RED, implement the safe inbox landing, rerun focused GREEN, design ratchet and appropriate full unit/lint/debug/unsigned-R8 checks after acquiring the shared Gradle slot; obtain independent critic and QA ≥9.5 on the frozen diff; then hosted CI before main. No device, release signing or real account was used.

Separate HIGH A3-02 remains: `DeepLinkRouter` and `DeepLinkHost` buffer routes across login boundaries, so an A push/link can replay into B. Also open: A3-03 activity recreation redelivery, recipient binding, founder-only in-app gates, and server object authorization. Do not claim the entire deep-link/security program closed from this policy slice.
