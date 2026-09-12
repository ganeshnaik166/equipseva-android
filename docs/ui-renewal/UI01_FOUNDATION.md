# UI-01 foundation implementation

Base: `667f134a72d747c78a11a10544c2cdf929b649bb`, branch
`codex/auth-integration-20260911`. Implements the approved
[page plan](../UI_THEME_PAGE_PLAN_2026-09-12.md). Verification is in progress;
this file does not yet claim milestone or app acceptance.

## Decisions

- Canonical action is lime `#C6FF00` with ink `#11150B`. Light Material `primary`
  is readable ink, because Material uses it for text buttons, cursor, radio,
  progress and icons as well as filled buttons. `primaryContainer` is lime.
  Dark Material primary is lime on dark surfaces. Default filled light Material
  buttons are ink until their individual primary-action migration.
- `EsTheme.colors` exposes complete action, disabled, error, pending, success,
  information and inverse pairs. Inverse muted/outline/focus roles are local to
  the inverse background. Light foregrounds must not be inherited inside it.
- All fifteen Material text roles are explicit. Page title is 28/34sp600,
  section 20/26sp600, card 18/24sp600, body 16/24sp400, primary label 16/24sp600,
  compact label 14/20sp600, support 14/20sp400 and caption 12/18sp400 or500.
  Tracking is zero; font padding is retained for Indic marks. Financial legacy
  `Mono` uses the body's tabular-number feature, not a falsely claimed monospace.
- `EsType` property names remain, but are now composable getters into Material
  typography. This preserves call syntax, not the old noncomposable API.
  `EquipSevaTypography` remains an immutable English instance for non-UI callers.
  `EsFontFamily` means the legacy body family; explicitly sized old headings
  using it remain Inter/Noto until their page migration.
- English uses bundled Space Grotesk600 and Inter400/500/600. Hindi uses bundled
  Noto Sans Devanagari; Telugu uses bundled Noto Sans Telugu, each at400/500/600.
  `LocalConfiguration` selects distinct resource IDs on locale changes, including
  a return to English. Unsupported app languages use the English styles.
  Mixed scripts outside the active family use **Android system fallback**;
  this is not a bundled cross-script font chain. Separate native renders are
  required on API26/34. Asset checks alone do not prove shaping or device parity.
- Badge/input/card/sheet radius roles are8/16/24/28dp. Legacy radius names map
  to these roles. Explicit per-screen shapes still need the planned migration.
- Original palette constants and logo files are unchanged. Theme preference
  persistence, authentication, data ownership, navigation and network code are
  outside this visual slice.
- The existing `dynamicColor=true` API remains explicit opt-in for Material
  colors on API31+. Branded `EsTheme.colors` stays paired and fixed. Production
  app calls leave this opt-in off; wallpaper does not override the approved
  default brand. This compatibility API is not a promise of a dynamic redesign.

## Compatibility work and limits

Source review found fixed-light containers using dynamic dark error foregrounds
in ProfileForms, hospital/engineer onboarding, AddressForm, AddressBook and the
founder engineer map. The new pale dark error would be unreadable there.
Only those verified foreground/background pairs may use the canonical light
error during migration. Do not force entire legacy pages into Light mode.

Existing mixed-theme debt includes location-picker actions on EngineerLocation's
fixed light background, legacy EsBottomSheet controls, ESBackTopBar and other
hardcoded palette consumers. These are page/component migration work, not a
claim that dark mode is already complete. No new regressions can be deferred as
old debt without baseline source/render evidence.

New type metrics must also pass real PrimaryButton/EsBtn large-text checks;
their old fixed48/44dp constraints cannot establish acceptance of the new
growable52dp action contract. Shared-action migration is the next bounded slice.

## Evidence ledger

- Baseline: `:app:testDebugUnitTest --tests '*LimeThemeFoundationTest'
  --max-workers=2 --no-configuration-cache --no-daemon`.
  **6 tests, 6 expected assertion failures**, no compile failure. Red proves old
  canvas/type/radius values and missing offline font assets fail the approved
  contract. Captured before production theme/font changes.
- Local evidence directory:
  `work/verification/ui-foundation-20260912` (sibling of this checkout).
  Preserve red XML/logs separately from later green runs.
- [Font build/provenance](font-assets.md):10 static resources, four original
  licences, pinned inputs/tooling/hashes, two byte-identical builds plus the
  documented reproduction procedure. Android runtime evidence is separate.
- Foundation, native gallery, actual UserPrefs compatibility and affected
  Welcome/Role/Home tests: **62 tests /6 suites,0 failures/errors/skips**.
  Exact command selectors and complete output are in foundation-targeted.log.
  This is a scoped candidate checkpoint; shared-action acceptance is still open.
- Unit/lint/debug/unsigned release, exact source hashes, APK font packaging:
  pending final result. An unsigned assembly is not a shipped release.
- Independent critic and QA: no acceptance score yet.

Physical-device/TalkBack/IME and all98 page designs remain separate gates.
Main integration remains blocked by the existing security/release conditions
in the project handoffs; this work does not close A3/A4/A12 or dependency alerts.

The first runtime attempt had12 failures (9 invalid Typeface native-handle identity
assertions and3 API26 harness accesses to the API28-only appComponentFactory
field). Both test-oracle corrections retain runtime/font/isolation assertions;
no failure was ignored. The second attempt stopped at a DpRect test compile error,
which was corrected to measured edge subtraction. Logs are retained. The subsequent
shared-button baseline recorded6/6 expected assertion failures (physical height,
loading semantics); these remain the red input to UI-02 rather than acceptance.
