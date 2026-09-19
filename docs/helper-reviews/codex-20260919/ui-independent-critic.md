# Independent UI critic — commit 3d9ee8d0

Reviewed `3d9ee8d0` (`fix(ui): preserve busy sheets and accessible shared controls`), its corrected `SharedUiReviewRegressionTest`, and the archived corrected-baseline XML. The reviewed UI component/test files have no diff against the coordinator's frozen full-check source `5aaa78f073e00d82e6e211bd3ac2d548e14a3f39`. Working tree was clean when checked. This reviewer ran no Gradle or production actions and changed no source or tests.

**Scoped implementation/test-design score: 9.5/10. No additional blocker found in the four demonstrated shared-control defects and the reviewed application of the sheet guard. Candidate GREEN is still pending the full-run XML.** This is a critic judgment about this patch and its tests, not app-wide accessibility, security, visual design, milestone integration or release acceptance. It does not raise the separate S3 routing score or close its recovery issue.

## Why the corrected tests are credible

The original false-positive oracles were investigated rather than suppressed. Official Compose source and target-3 metrics established the semantics paragraph-width mismatch. Native bitmap diagnostics established anti-aliased foreground ink. The busy Back comparison was moved after the busy layout settled, preserving the actual no-hide requirement.

The same corrected tests were then run against the four original production files from `69034d84`, with the aligned Compose BOM. Independently read `ui-corrected-baseline-red.log` and `ui-corrected-baseline-red-xml/TEST-com.equipseva.app.designsystem.components.SharedUiReviewRegressionTest.xml`: **six tests, six failures**, now against real behavioral/measurement assertions:

| Target | Corrected old-source failure |
| --- | --- |
| Native busy Back | The delete-sheet title is no longer displayed after native Back. |
| Single selected rating | Four radio nodes report selected after choosing rating four. |
| Badge at 1x | `99+` is vertically clipped. |
| Badge at 2x | Even `1` is vertically clipped. |
| Small info glyph | Actual painted width is 40px versus the 12dp limit. |
| Regular info glyph | Actual painted width is 40px versus the 14dp limit. |

This is valid regression sensitivity. The prior six-failure report with the invalid width oracle is not needed as acceptance evidence.

## Implementation and test assessment

- **Bottom navigation:** the badge now participates in parent measurement; the fixed 22dp icon remains separate. Corrected tests exercise 3 and 4 tabs at 320dp with platform font scales 1 and 2 and counts 1, 99 and 100 (displayed as 99+). They retain complete text, one line, no ellipsis, actual line/character width and height bounds, owning-tab/nav/viewport containment and exact accessible unread count. This directly tests both the original clipping and the claimed four-tab behavior.
- **Verification info:** a named clickable 48dp container owns a separate 12/14dp icon. The raster classifier checks whether pixels match the specified tint blended over the fixture's explicit white background, with bounded rounding and at least 10% coverage. It still requires eight ink pixels, maximum painted dimensions and containment. An actual touch outside the small glyph must open the sheet. Both oversized original glyph variants fail these same corrected tests.
- **Busy sheets:** stable remembered transition callbacks read current busy state; native Back uses the dialog's guarded handler; ready Cancel invokes the current callback directly. The corrected DeleteAccountSheet test exercises the native dialog Back owner, stable busy visibility/position, no unwanted dismissal, failure text in the same dialog and eventual ready dismissal exactly once. The five founder hosts and ReportContentSheet use the same inspected guard pattern.
- **Survey:** selected semantics use equality with the chosen rating while visual star fill stays cumulative. Multiple non-monotonic choices and captured submission arguments are checked, so a test cannot pass merely by making every star unselected.
- **Ancillary changes:** inspected token substitutions preserve the intended values. RoleSelect keeps its explicit foreground on a fixed light surface and its sign-out action; Hospital actions retain their callbacks while using shared minimum-height buttons. No security/admission gate was removed by these changes.

## Limits that remain open

- Candidate full unit, lint, debug and unsigned release checks are running under the coordinator. This review cannot call them green before the actual results arrive. An unsigned assembly is not a shipped release.
- Linux Roborazzi screenshot verification/intentional golden updates remain required for shared visual changes. These physical semantic/raster tests are not substitute goldens.
- Native Back is executed for DeleteAccountSheet on SDK32. SDK33+ predictive Back, each founder/report host, scrim/drag paths, and a ready-to-busy transition during an already-started dismissal still need the appropriate integration/device coverage. No assertion is made that this patch proves every dismissal interleaving.
- Locale rendering, RTL, actual TalkBack traversal, non-mdpi raster behavior, long text, and the existing untranslated accessibility strings remain outside this bounded patch acceptance. The 3/4-tab 1x/2x fixture does not claim all device/font combinations.

Reviewed corrected test SHA-256: `F5B0CEC6600AEDF897BC21F5E962D6FA9E92598C6AFBA671FAA77FD199221501`.
