# Signup footer navigation fallback — WIP handoff, 26 September 2026

## Scope and exact source

- Isolated worktree: `C:/Users/lokes/Documents/Codex/2026-09-07/im/work/equipseva-signup-nav-20260926`.
- Branch: `codex/signup-nav-fallback-20260926`; fetched `origin/main` base `3c5f8b6c71275c06fc3ec1da55895cc9cae745c8`.
- Test-first WIP commit: `2b2c769f19a2506c827f394205ccbda442039025`. Initial code commit: `8f35faf3`. Final code commit: `88f136d1848f63adf40e4c72870226bc2be221f1`. The later documentation commit is metadata only.
- Code files: `app/src/main/kotlin/com/equipseva/app/navigation/AuthNavGraph.kt` and new `app/src/test/kotlin/com/equipseva/app/navigation/SignUpToSignInNavigationTest.kt`. The first commit also records this scope in `docs/CURRENT_STATE.md`.
- Welcome source/tests, P1d sender, shared auth/session code, and all other checkouts were untouched. This branch is unmerged; the coordinator handles PR/CI integration.

## Behavior

`AuthNavGraph` has two paths into SignUp. SignIn → SignUp previously returned to the existing SignIn entry. Direct Welcome → SignUp had no SignIn entry, so the footer's `popBackStack(AUTH_SIGN_IN, false)` returned false and did nothing. The callback now acts only while SignUp is current, pops to an existing SignIn when possible, and otherwise navigates to SignIn while removing SignUp. Back from that SignIn returns to Welcome, not to SignUp. Ordinary Back from SignUp still returns to whichever entry screen opened it. A repeated or delayed callback cannot rewrite a later recovery screen.

## Verification

- Target command (all runs): `PRECHECK_LOOSE=1 .\gradlew.bat :app:testDebugUnitTest --tests com.equipseva.app.navigation.SignUpToSignInNavigationTest --no-daemon --console=plain` from this worktree.
- The initial attempt stopped at `processDebugGoogleServices`: a new isolated worktree lacks ignored `app/google-services.json`. An existing local ignored config was copied into this worktree for tests only; `git check-ignore` confirms it is ignored and it is absent from commits.
- The next attempt ran 3/3 tests but all failed during the Robolectric app/Hilt/Supabase fixture before assertions. The fixture was corrected to use plain `android.app.Application`; those failures are not behavioral RED evidence.
- Behavioral RED on `2b2c769f` production code plus the plain-Application fixture: **3 tests, 1 failure, 0 errors, 0 skips**, Gradle exit 1. Direct Welcome → SignUp expected `auth/sign_in` but remained `auth/sign_up`; the nested route and ordinary Back passed. The fixture correction was committed together with the implementation, so that exact RED working tree was not a separate commit.
- Code `8f35faf3`: the same targeted command passed **3/3**; full unit/lint passed **342 suites / 2,910 tests / 0 failures/errors/skips**, lint **0 errors / 87 warnings / 2 hints**.
- Critic found a second case: after SignUp → SignIn → Forgot Password, a late footer callback could pop recovery away. Test-first behavioral RED on `8f35faf3` plus two new tests: **5 tests / 1 failure**, specifically recovery expected `auth/forgot_password` but became `auth/sign_in`; repeated callback and the prior paths passed.
- Final code `88f136d1` checks that SignUp remains current. Targeted command passed **5/5**, Gradle exit 0.
- Final command: `PRECHECK_LOOSE=1 .\gradlew.bat :app:testDebugUnitTest :app:lintDebug --continue --no-daemon --console=plain`. **342 suites, 2,912 tests, 0 failures, 0 errors, 0 skips**; `lintDebug` **0 errors, 87 warnings, 2 hints**; combined Gradle exit 0. The test and lint reports are in this worktree's ignored `app/build/reports` directory. The shared Gradle slot is FREE.
- Debug/release assembly and device/TalkBack navigation were not run on this branch. A passing unsigned assembly elsewhere is not release approval.

## Review and integration gates

This fixes only the sign-up footer stack. It does not add the planned third registration persona, alter authentication policy, or establish an app-wide score. Critic feedback on the earlier code led to the stale-callback guard. Independent final-code critic **9.7/10** and QA **9.6/10** reviewed `88f136d1` plus the five focused tests; neither ran Gradle independently, and both exclude device navigation. Applicable hosted PR Android/secret-scan checks and coordinator review remain before main integration. Physical direct/nested/recovery/Back smoke remains a later device gate; no live account or production request was used.
