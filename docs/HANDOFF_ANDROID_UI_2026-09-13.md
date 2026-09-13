# Android continuation: shared text fields and dropdowns

Continue on `codex/auth-integration-20260911` in
`C:/Users/lokes/Documents/Codex/2026-09-07/im/work/equipseva-auth-integration-20260911`.
Base: `75e55c14730d6f3499d34bbcc7155e994f0f8816`.

| Commit | Scope |
| --- | --- |
| `9620da6df6dea33e723cfa6e58c1b8696583afd2` | UI-02 shared fields/dropdowns, minimal caller compatibility and 39 tests. Contains final production code. |
| `094000ad6fb5026cb2d144c23212bbdced87ab13` | Four added layout cases; their popup size setup was later found ineffective. Retained historical checkpoint. |
| `694bf690929f869277513d27f72bf24697a3d2a5` | Actual Android-window font-scale setup, discriminating layout assertions and all 43 final tests. Final build source. |

**Shared inputs accepted locally: critic 9.595/10, QA 9.58/10**, with every
applicable critical dimension at least 9.5. These ratings cover this slice only.
The following receipt commit changes documentation and verification evidence only;
obtain its SHA from Git instead of creating a self-reference.

## Changes

Shared fields use the approved Inter body/label sizes, 16dp corners and complete
paired light/dark colors for text, surface, disabled, placeholder, error, focus,
icons, cursor and selection. Labels persist above the outline and grow rather
than overflowing a native floating-label slot. Inputs have a 56dp minimum body.
The editable node owns its durable accessible name and exact validation error.

Dropdown menus retire on observed value, options, enabled or searchable changes.
Each opening fences stale, duplicate and disposed callbacks. Re-enabling or
restoring options needs a fresh gesture; hidden searches reset. Controlled values
are not cleared, normalized or auto-selected. Native menu focus, keyboard
traversal, Escape dismissal and return focus remain covered.

The caller inventory found 57 field instances and three dropdowns across 22 files.
48 fields and all three dropdowns have fixed-light parents and now pass an
explicit complete compatibility palette; nine themed dialog/sheet fields inherit
the theme. KYC state/district labels belong to the trigger. The compact payout
editor uses a localized Amount (₹) label. Two quiet-hour displays share one named,
enabled outer button while retaining the actual time-picker callbacks.

Password masking, existing keyboard/filter/focus behavior and submission policy
are retained. Disabled stale IME callbacks cannot submit later. No authentication,
navigation, repository, permission, dependency or security-gate change belongs to
this slice. Component-local observed state retirement does not solve repository
identity boundaries that the component never observes.

## Verification and preserved failures

Read [the evidence index](evidence/ui-inputs/README.md),
[verification ledger](evidence/ui-inputs/verification.json),
[critic](evidence/ui-inputs/critic-review.md) and
[QA](evidence/ui-inputs/qa-review.md).
The contract and correction history are in [UI02_SHARED_INPUTS.md](ui-renewal/UI02_SHARED_INPUTS.md).

The corrected baseline failed seven of ten tests on unchanged production. Stronger
tests also exposed real floating-label clipping and unnamed quiet-hour actions.
Those defects were fixed. Test-oracle corrections for disabled-node lookup,
Compose IME flags, popup keyboard mode/window focus and actual popup font scale
are recorded separately; no failing case was removed or ignored.

The initial "2x" popup probe at `094000ad` actually rendered at 1x because the new
Android window replaced the parent's composition density. Review held acceptance.
An actual-layout assertion reproduced seven tests/four failures. Setting resource
font scale before window creation and restoring it at teardown passed 25 focused
cases, including real 2x Hindi/Telugu search, options, no-match and landscape.
API 34 nonlinear font scaling yields 42px body/caret in EN/TE and 53px in HI.
Original incorrect captures/XML remain archived, not relabeled as valid2x.

Final command:

```text
PRECHECK_LOOSE=1
.\gradlew.bat :app:testDebugUnitTest :app:lintDebug :app:assembleDebug :app:assembleRelease --max-workers=2 --no-configuration-cache --no-daemon
```

JDK: `C:/Program Files/Microsoft/jdk-17.0.19.10-hotspot`; SDK:
`C:/Users/lokes/Android/Sdk`. Add `C:/Program Files/Git/bin` to process PATH.
The compile-mode override does not authorize a release. Missing certificate and
keystore configuration remain blockers; unsigned assembly is not a shipped app.
Raw logs/XML/native captures are in sibling `work/verification/ui-inputs-20260913`.

Final bar passed in **5m 39s: 3,198 tests / 362 suites / zero failures, errors or
skips**. Lint: zero errors, 82 warnings and two hints. All 798 captured source and
configuration hashes match before and after. Both APKs contain the ten exact font
resources and five licence/provenance assets. Debug is 47,836,787 bytes; unsigned
release is 19,099,280 bytes, below the existing 28 MiB budget. The strict release
dry-run refused missing keystore configuration; apksigner rejected the unsigned
APK as expected. Security guards were preserved.

## Resume

Newer interrupted work: read [the OTP WIP stop checkpoint](HANDOFF_ANDROID_UI_2026-09-13_OTP_WIP.md)
before continuing. The accepted input milestone below remains historical evidence;
it does not cover the newer OTP changes or their pending failures.

Read [the approved page plan](UI_THEME_PAGE_PLAN_2026-09-12.md) first. UI-02 remains
in progress: shared actions, fields and dropdowns are the current bounded slices.
Next inventory and migrate OTP, cards/status/navigation/dialogs/sheets and common
feedback, then UI-03 auth pages. Preserve A1/Room v5/A2/A10 behavior and the separate
visual/security commit boundaries. All 98 pages are planned, not implemented.

Physical-device, TalkBack/OEM IME, native-language, process/Activity restoration,
provider, A3/A4/A12, dependency and signed-release acceptance remain open.
Fetch before committing or pushing. Push only the development branch while these
gates remain. Never reset, switch, clean or overwrite another checkout. Recheck
`outputs/equipseva-build-slot.md` before Gradle and preserve any other reservation.
The coordinator returned its build slot to FREE after all Gradle work completed.

Owner steering on 13 September: stop updating the equipseva.com dashboard and
focus on the Android app. The locally prepared dashboard data change was reverted
before committing; existing website files remain at the prior saved snapshot.
No APP-03 website package was created or published. Future app milestones do not
update the website unless the owner asks again. Whole-app completion and active
hours remain unmeasured; component ratings do not establish main or release
acceptance.
