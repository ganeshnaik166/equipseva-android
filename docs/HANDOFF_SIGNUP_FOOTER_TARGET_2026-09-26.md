# SignUp footer target — bounded WIP

- Date: 26 September 2026.
- Branch: `codex/signup-footer-target-20260926` in `work/equipseva-signup-footer-20260926`.
- Fetched `origin/main` base: `edae85ed50aa9f819a0a4fddaeea50ebae93ff64` (PR1889 navigation merge).
- Ownership: `SignUpScreen.kt` footer "Sign in" action, new focused `SignUpFooterTargetTest.kt`, and this branch's continuity documents only. No role, registration, session, navigation, backend or font migration.
- Existing defect: 13sp link at `SignUpScreen.kt:194-210` has a bare `Modifier.clickable`, while `Spacing.MinTouchTarget` is 48dp. Its layout hit target and role need an executed Compose test.
- Test-first RED: `PRECHECK_LOOSE=1 .\gradlew.bat :app:testDebugUnitTest --tests com.equipseva.app.features.auth.SignUpFooterTargetTest --no-daemon --console=plain` exited 1; **3 tests, 2 failures, 0 errors/skips**. The normal-screen target failed the 48dp assertion. The 320x420dp/200% font fixture could not display the link after scrolling, exposing footer layout crowding. Its callback-isolation test passed. This is behavior evidence for this initial source, not an accepted milestone. The shared Gradle slot was released after this RED.
- Minimal fix, targeted/full checks and independent critic/QA remain.
- Integration risk: `docs/CURRENT_STATE.md`, `docs/MILESTONE_LOG.md` and the delivery ledger may overlap other parallel slices. Reconcile by retaining both dated records; do not overwrite another slice. PR1888 Welcome and the SignIn helper own separate source files.
