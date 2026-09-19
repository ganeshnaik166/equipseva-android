# UI foundation and shared-action evidence

Scope: UI-01 theme/fonts plus the primary-action part of UI-02. This directory
records local verification of the selected lime/ink design. It does not accept
all shared components, all 98 page declarations, device workflows or a release.

**Accepted locally at `c7da5ee333d3913bf98052c9c20f81b3b56f6d38`:** 3,155 tests /
359 suites, zero failures/errors/skips; lint zero errors, 82 warnings and two
hints; debug and unsigned release assembly successful. Critic **9.595/10**;
QA **9.58/10**. Every applicable critical dimension is at least 9.5.

Exact commands, source hashes, suite/XML hashes, APK packaging and retained
signing limits are in [verification.json](verification.json). Independent
[critic](critic-review.md) and [QA](qa-review.md) receipts bind the same source.

## What the cases establish

| Area | Evidence and practical limit |
| --- | --- |
| Theme roles | Canonical color pairs, all fifteen typography roles, shape tokens, default brand and explicit dynamic-color compatibility. Existing palette constants remain unchanged. |
| Material consumers | Light/dark labels, links, selected/unselected control marks, errors, progress and fixed-light compatibility fields. Pixel checks sample actual foreground and adjacent fill. |
| Bundled fonts | Ten static resources at actual 400/500/600 weights, pinned source licences and reproducible hashes. Native advances distinguish bundled resources from platform default on API26/34. |
| Indic and large text | EN/HI/TE and mixed-script samples, rupee sign/digits, 320dp at twice text size and short landscape. Native simulated rendering is separate from a native-speaker or physical-device review. |
| Preferences and locale | The actual production DataStore through wrapper recreation; stored choices and unrelated keys retained. Same-composition locale/theme changes retain remembered state. Neither case proves process/Activity restoration. |
| Shared buttons | Physical 48/52dp floors, growing labels, line and viewport bounds, icon containment, loading descriptions, disabled click rejection and no delayed tap replay. |
| Keyboard focus | A real keyboard input-mode request, accepted focus request and changed rendered stroke. No fake focus interaction is injected to satisfy the test. |
| Compact action groups | Source-like mark-paid, cancel and copy/pay/call actions wrap; every label and callback remains reachable. This does not exercise provider payment behavior or the entire founder page. |

Selected PNGs are original **Robolectric native-render captures**. They are
component/specimen evidence, not photographs, generated concept art or a claim
that every page has this appearance. No real account is used in these fixtures.
Selected captures and their hashes are in [render-manifest.json](render-manifest.json).
All full-resolution captures are generated under `app/build/outputs/ui-foundation`;
complete raw XML/logs remain in the sibling local
`work/verification/ui-foundation-20260912` evidence directory.

| Preview | Scope |
| --- | --- |
| [Light buttons](renders/shared-actions-light.png) / [dark buttons](renders/shared-actions-dark.png) | Normal, loading and disabled shared controls |
| [Light action kinds](renders/action-kinds-light.png) / [dark action kinds](renders/action-kinds-dark.png) | Secondary, Ghost and destructive roles, including fixed-white compatibility |
| [Keyboard focus](renders/keyboard-focus.png) | Actual focused primary control |
| [English 2x](renders/english-320dp-2x.png), [Hindi API26 2x](renders/hindi-api26-320dp-2x.png), [Telugu dark 2x](renders/telugu-dark-320dp-2x.png) | Bundled type and mixed-script specimens at 320dp |
| [Material light](renders/material-controls-light.png) / [dark](renders/material-controls-dark.png) | Representative default consumers and focused fields |

## Failure history retained

The original foundation failed six expected assertions. The old button baseline
failed six expected assertions. Later runs exposed actual centered-label
overflow and a squeezed final payout action; both were corrected before final
acceptance. Invalid Typeface-handle equality, an API26 test-host field access,
test imports/geometry API and initial touch-mode focus were corrected as test
oracle/harness problems, with diagnostics retained. No test was deleted, ignored
or relabeled to turn a failing target green.

The first full build passed all 3,155 tests but added one ComposableNaming warning
in the gallery helper. Renaming that helper preserves all assertions. The final
full check passed in 6m 24s with the 82-warning baseline; the only removed issue
between those lint reports is ComposableNaming. [Failure ledger](failure-history.json).

Unsigned assembly checks compilation, shrinking and font packaging. Missing
certificate/keystore configuration still blocks a strict release, and an unsigned
APK must fail signature verification. A3/A4/A12, dependency triage, device/TalkBack,
IME, providers, full-page migration and main integration remain separate gates.
