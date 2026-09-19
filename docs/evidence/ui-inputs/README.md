# Shared-input evidence and previews

Scope: UI-02 `EsField`, `EsDropdown` and minimal caller compatibility. Final build
source: `694bf690929f869277513d27f72bf24697a3d2a5`. **Accepted locally: critic
9.595/10; QA 9.58/10**, with every applicable critical dimension at least 9.5.
Independent [critic](critic-review.md) / [QA](qa-review.md) receipts bind this source.

**3,198 tests / 362 suites / zero failures, errors or skips**. Lint zero errors,
82 warnings and two hints. Debug and unsigned release assembly passed in 5m 39s.
Both APKs retain all ten fonts and five notices/provenance assets. All 798 source
hashes match. The strict signing guard and unsigned APK verification still refuse
release. No device, provider, main or whole-app acceptance is implied.

There are 43 new synthetic tests: 19 interaction/state contracts, 18 activity gallery
cases and 6 native-popup gallery cases. [Verification](verification.json) binds the
full command, all 798 source/configuration hashes, suite hashes, lint and both APKs.
[Failure history](failure-history.json) preserves expected baseline failures,
real defects and invalid test-oracle corrections.

| Evidence | What it establishes |
| --- | --- |
| Paired input states | Actual light, dark and explicit-light-in-dark text, outlines, icons, placeholder, disabled, error, focus, selection and cursor pixels; no pure token-only verdict. |
| Names and errors | Editable/actionable node owns a persistent name and exact error. Password values are not copied into descriptions. Time-picker displays expose one named enabled action. |
| State and keyboard | Old, duplicate, disposed and disabled menu callbacks remain inert; fresh gestures work. Native Enter/arrows/Escape and focus return, Next traversal and guarded optional submit behavior are retained. |
| Small and large layouts | EN/HI/TE activity fields/labels/support, long controlled dropdown values and compact payout editors at 320dp/2x. Short 640×320 landscape remains scrollable with genuine 2x popup selection. |
| Real popup rendering | Captures come from the separate popup Android window. Actual TextLayoutResult font scale is asserted, including Hindi light and Telugu dark/fixed-light at 2.0; text, focus boundary and blinking caret are measured. |
| Caller preservation | Existing fixed-light surfaces receive complete compatibility palettes. The nine themed dialog/sheet fields keep theme inheritance. KYC/numeric/ETA/payout callbacks are retained. |

All PNGs are original Robolectric native-render specimens with synthetic data.
They are component evidence, not photographs or whole-page/device acceptance.
The activity gallery explicitly overrides composition density; popup tests set
Android resource density before window creation and verify the actual layout.
API 34 font scaling is nonlinear and font metrics differ by script; 2x preference
does not mean every measured pixel dimension must exactly double.

| Preview | Scope |
| --- | --- |
| [Light](renders/palette-Light-normal-visible.png) / [dark](renders/palette-Dark-normal-visible.png) | Persistent label, body and supporting copy |
| [Error](renders/palette-Dark-error-visible.png) / [disabled](renders/palette-Dark-disabled-visible.png) | Explicit dark state pairs |
| [English 2x](renders/large-en-Light-320dp-2x-large-field-visible.png), [Hindi 2x](renders/large-hi-Light-320dp-2x-large-field-visible.png), [Telugu 2x](renders/large-te-Dark-320dp-2x-large-field-visible.png) | Multiline values and complete labels/errors |
| [Dropdown](renders/large-te-Dark-320dp-2x-large-picker-visible.png) | Long value wraps with contained arrow |
| [Compact payout](renders/floor-te-320dp-2x-floor-row-visible.png) | Localized label and Save remain reachable |
| [Hindi popup](renders/popup-Light-hi-2.0x-search-value.png) / [Telugu popup](renders/popup-Dark-te-2.0x-search-value.png) | Actual Android-window 2x search and choices |
| [No matches](renders/popup-Dark-te-2.0x-disabled-no-matches.png) / [landscape](renders/landscape-640dp-2x-popup.png) | Non-actionable empty search and reachable selected option |

[Render manifest](render-manifest.json) includes hashes and measurement files.
Complete local output is under `app/build/reports/ui-inputs-gallery`; historical
and final raw archives are in sibling `work/verification/ui-inputs-20260913`.

The 094000 popup captures incorrectly labeled 2x are preserved only as historical
failed evidence. A stronger assertion reproduced 7 tests/4 failures, then the
platform-scale harness fix passed 25 focused cases. No production workaround or
weakened pixel/containment assertion was used to pass that correction.

Unsigned release assembly checks compilation, shrinking and packaging. It cannot
establish valid signing or delivery. OTP/remaining shared components, all-page
migration, native-speaker/device/TalkBack/OEM IME, restart/provider and A3/A4/A12,
dependency/main/signed-release gates remain open.
