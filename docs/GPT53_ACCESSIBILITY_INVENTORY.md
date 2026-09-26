# Bounded accessibility inventory — 11 September 2026

Static source review only. Screens are unchanged from base
`1e770076358e74f6f40a99a4907f831da59e791c`. No screen was rendered, no device or
TalkBack session ran, and this is not an accessibility acceptance score. Inspect
the cited source before applying a proposal; these are minimal follow-up slices.
Current A2 RoleSelect/recovery screens are excluded.

Paths in the table are relative to `app/src/main/kotlin/com/equipseva/app/`.
Line spans refer to that base. Shared components were traced only where these
four screens use them. Layout sizes do not establish actual pointer hit bounds:
Compose may expand small touch targets, which needs runtime measurement.

| ID | Evidence | Finding / confidence | Minimal proposed fix and test |
| --- | --- | --- | --- |
| AX-01 | `features/auth/WelcomeScreen.kt:59–72,101–130`; `designsystem/components/EsBtn.kt:71–74,94,117` | Welcome has a non-scrolling, weighted layout and a custom fixed 52dp account CTA; its Sign in CTA inherits a fixed 52dp height. SignIn (`:139–158`) and SignUp (`:183–190`) also use the fixed-height Lg button. Long translations/large text may clip or squeeze the footer. Static layout risk, not reproduced clipping. | Use minimum height plus vertical padding and make Welcome content scroll when needed. Test 320dp width, landscape/short height, font scale 2.0, EN/HI/TE; assert both CTAs and legal actions are reachable and text has no visual overflow. Keep branding and action order. |
| AX-02 | `features/auth/WelcomeScreen.kt:113–129,138–170` | Custom Create account uses generic clickable without button role. Terms and privacy share an 11sp ClickableText with offset-based string annotations; no separate link semantics are declared. Labels exist visually; keyboard/TalkBack activation is unverified. | Add button semantics to the account CTA. Expose separately focusable legal links using supported Compose link semantics or distinct actions. Semantics test: each named action has the correct role and independently invokes its existing callback/URL. Verify hit bounds and focus order on device. |
| AX-03 | `features/auth/SignInScreen.kt:129–135,169–176`; `features/auth/SignUpScreen.kt:202–209`; `features/profile/ProfileScreen.kt:1038–1050` | Forgot password, auth-switch links and Profile Edit use compact clickable text/boxes with no explicit minimum target. Edit has only 6dp vertical padding around 12sp text. Each lacks explicit button role. Text supplies names; actual hit expansion/overlap is unmeasured. | Use TextButton or an explicitly sized minimum-48dp action with role. Preserve layout intent and route callbacks. Measure semantic and touch bounds, adjacent hit regions and keyboard focus; verify each action once at large text. |
| AX-04 | `features/auth/SignInScreen.kt:108–127`; `features/auth/SignUpScreen.kt:119–150`; `designsystem/components/EsField.kt:74–87,91,128–137` | EsField draws the label and detailed error as sibling Text nodes; OutlinedTextField gets neither label nor the detailed error semantics. Filled fields lose placeholder hints. The visual label exists but its programmatic association is not established by this implementation. | Associate the persistent label and specific error with the editable node using Material label/supporting text or suitable semantics while preserving password masking. Test populated Email/Password/Full name fields for labels, errors and editable actions; verify TalkBack without duplicating every label announcement. |
| AX-05 | `features/auth/SignInScreen.kt:139–158`; `features/auth/SignUpScreen.kt:183–190`; `designsystem/components/EsBtn.kt:78–117` | Submitting disables CTAs but leaves static Sign in/Google/Continue text, with no pending indicator/state description. EsBtn has no loading parameter. The UI does not distinguish waiting from ordinary disabled form validation. | Add a localized pending label/progress state at the affected call sites or in a small separately reviewed component slice. Test a suspended synthetic submit, disabled double tap, accessible progress, and retry after failure; never display success before completion. |
| AX-06 | `features/auth/SignUpScreen.kt:232–243` | Inline signup RoleTile omits selectable entirely when disabled. Its selected/disabled radio semantics disappear during submission even though the tile remains visible. This is the signup-local tile, not A2 RoleSelect. | Keep selectable with enabled=false and the selected value; group the two choices. Test that a selected disabled tile remains a named selected radio button and cannot activate during a pending submit. |
| AX-07 | `features/profile/ProfileScreen.kt:955–980` | Avatar picker has no action label or role; with a URL, AsyncImage also has null contentDescription, so that clickable node has no name. Initials fallback is not an action label either. Source-confirmed missing label. | Give the clickable parent a localized Change profile photo label and button role; keep the image decorative. Test URL/initials/uploading states for exactly one named action, disabled upload state and progress semantics. |
| AX-08 | `features/profile/ProfileScreen.kt:1339–1349,1365–1401,1404–1430` | Edit sheet's inner form is non-scrolling; long errors, larger text and IME may make Save/Cancel unreachable. The error Text has no live-region annotation. Material sheet IME/inset behavior still needs runtime checking. | Add bounded scrolling as needed without double-applying sheet insets. Announce new errors politely. Test small viewport, IME, long localized error and font scale 2.0; Save/Cancel must be reachable and validation must preserve the name. |
| AX-09 | `features/auth/SignInScreen.kt:77,193`; `designsystem/theme/Color.kt:36,45` | The 12sp “or” text uses #788379 on #F6F8F5: computed sRGB contrast 3.695:1. The colors are paired but this is below the proposed 4.5:1 normal-text gate. No screenshot/contrast scan was run. | Use a darker existing semantic text token with a paired background. Add a contrast assertion for the selected colors and verify light/dark rendering before acceptance. |
| AX-10 | `features/auth/SignInScreen.kt:77`; `features/auth/SignUpScreen.kt:83`; `designsystem/components/EsField.kt:87,120–125`; `features/profile/ProfileScreen.kt:204,949,1062` | Auth/Profile mix fixed light surfaces with theme-driven Material controls. EsField pins normal text colors but leaves cursor, container and other states to theme defaults. This is an incomplete state-pair specification, not proof every dark-theme combination fails. | Specify matching foreground/background/state pairs for the small affected component slice. Render focused/unfocused/error/disabled controls in both themes and all locales; measure cursor, border and text contrast. Coordinate with the later design-system slice; do not fold in A2 files. |
| AX-11 | `features/auth/SignInScreen.kt:106`; `features/auth/SignUpScreen.kt:117`; `designsystem/components/ErrorBanner.kt:48–56` | ErrorBanner caps messages at four lines with ellipsis. At large text a long error can hide its recovery instruction. It already has a polite live region and paired error colors. Static truncation risk, no lost instruction reproduced. | Prefer complete localized action-oriented messages or an accessible expansion for long content. Test a synthetic error with its retry instruction at the end at font scale 2.0; preserve the existing live region. |

## Error/retry copy disposition

- SignIn/SignUp display mapped auth failures through ErrorBanner; no new
  misleading-error defect was reproduced. AX-05 covers pending-state ambiguity.
- Profile's null-profile fallback says “Finishing setup…” / “We're loading your
  profile. Tap retry if this doesn't clear.” (`ProfileScreen.kt:223–255`,
  `app/src/main/res/values/strings.xml:426–427`). This is potentially misleading
  **if** shown with no active load, but normal `ProfileViewModel.kt:610–655`
  completion assigns an explicit error to a null result. Reachability of the
  no-error idle state was not established; do not report it as a reproduced bug.
  Minimal future test: render loading, missing-row and failed-load states; each
  must show truthful copy and a working owned retry. Broader retry ownership
  belongs to the coordinator's A4/A12 work.
- Profile edit phone copy explicitly says the flow does not perform SMS
  verification (`ProfileScreen.kt:1356–1362`); do not replace it with a false
  verification promise.

## Existing protections observed

SignIn and SignUp already scroll and apply IME padding. Profile's notification
action has a 48dp box, an “Open notifications” click label and button role
(`ProfileScreen.kt:182–198`); its null icon description is intentional. Decorative
chevrons/icons beside text were not classified as missing labels. Profile Save
already shows a spinner and “Saving” (`:1413–1425`). Signup radio ring size is not
the whole-row hit target. Fixed light surfaces alone are not a contrast failure.

Before implementing any row, add its focused synthetic Compose regression,
then verify the affected screen on device. This inventory changes no UI,
authentication, role policy, dependencies or shared component source.
