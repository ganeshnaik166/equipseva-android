# SignUp footer integration — independent QA, 27 September 2026

**Disposition: 9.6/10, local scoped QA pass.** Reviewed clean branch
`codex/signup-footer-integration-20260926` at
`1e62b7cd3a1208f43432a3edb091ded88433ee1d` against main parent
`133720a69b164c51d18d0bcf104a9bd3e3b51c36`. This score covers the
SignUp footer target and its compatibility with the already merged Welcome,
SignIn recovery and signup navigation changes. It is not an auth-system,
whole-app, device-accessibility or release score.

## Evidence and checks

- The app diff changes only `SignUpScreen.kt` and adds
  `SignUpFooterTargetTest.kt`. The prompt and Sign in action are stacked so
  text does not crowd the action at 320×420dp with 200% text. The action
  declares `Role.Button`, uses the design typography token, and applies
  `Spacing.MinTouchTarget` (48dp) to both width and height before `clickable`.
  Source keeps the existing `onSignIn` callback, with no auth, role, backend
  or route-policy change.
- Five existing `SignUpToSignInNavigationTest` cases exercise direct Welcome
  and via-SignIn stacks, Back behavior, a duplicate callback, and a delayed
  callback after password recovery. `AuthNavGraph.returnToSignInFromSignUp`
  checks the current destination before changing the stack. Three SignIn
  recovery and five Welcome cases cover their callbacks, action targets and
  narrow-screen/200% text reachability. Three new SignUp footer cases cover
  semantics/height, callback isolation and narrow-screen/200% text reachability.
- I read the fresh four JUnit XMLs: **16 tests, 4 suites, 0 failures, 0 errors,
  0 skipped**. I independently summed the full local JUnit XML directory:
  **2,923 tests, 345 suites, 0 failures, 0 errors, 0 skipped**. The coordinator
  reported the exact-head combined Gradle command exited 0, `BUILD SUCCESSFUL`
  in 7m57s. The lint XML has **0 errors, 87 warnings, 2 hints**; debug APK and
  unsigned release APK are present. `git diff --check` passed.

## Limits and follow-up

- The SignUp footer test asserts the 48dp **height**; it does not assert
  width. The source explicitly sets `minWidth = Spacing.MinTouchTarget`, so
  this is a test coverage gap, not a reproduced size defect.
- Synthetic Robolectric reachability and semantics do not establish actual
  TalkBack order, physical touch behavior or dark-theme pixel quality. Those
  device and rendered checks remain open. The navigation tests call the route
  helper directly rather than driving a full provider/account journey.
- `SignUpScreen.kt` still allows the footer during `form.submitting`, while
  the form fields and Continue action disable. `SignUpViewModel` can finish
  account creation and role writes after a navigation request. This is a
  pre-existing cross-screen auth/session race, tracked in the separate
  session-identity work; this footer-only diff neither creates a new auth
  state rule nor resolves it. Do not treat this QA pass as auth-security
  acceptance.
- Hosted CI, main integration, live signup/email verification and signed
  release are pending. The release artifact inspected here is unsigned.

No mandatory source defect was found within the stated footer integration
scope. Keep that scope and the pending gates explicit in the handoff/PR.
