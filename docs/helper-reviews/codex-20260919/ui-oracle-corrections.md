# UI regression oracle corrections — 2026-09-19

This note supersedes any earlier statement that all six initial UI failures independently proved production defects. In particular, the badge's original `didOverflowWidth` failure was an invalid oracle and cannot establish product RED. The coordinator must execute the corrected test against the original production layout before accepting its repair.

Only `app/src/test/kotlin/com/equipseva/app/designsystem/components/SharedUiReviewRegressionTest.kt` was edited during this diagnostic iteration. No additional production edits or Gradle run were performed by this agent. Tests are now frozen for coordinator execution.

## 1. Busy Back: compare the same layout

Before: the test recorded the title position while idle, then changed `deleting` to true and dispatched Back. The actual half-width EsBtn changes `Delete account` to `Deleting…`, changing wrapping and sheet height at 320 dp. The failing 342→362 px comparison included that unrelated content reflow.

After: settle the busy transition and take its title bounds immediately before native Back. The test still dispatches actual dialog key events, verifies the dialog owns Back, asserts title visibility and unchanged busy position, verifies no dismiss callback, renders the failed-request error in the same dialog, and requires ready Back to dismiss exactly once. This corrected check passed in `ui-photo-target-3-xml`.

## 2. Badge: semantics paragraph width is not painted overflow

Observed diagnostic3 values for the fitting count `1`:

| Font scale | Actual text size | Semantics paragraph width | Rightmost line advance |
| --- | --- | --- | --- |
| 1x | 5 × 17 px | 69 px | 5 px |
| 2x | 9 × 33 px | 69 px | 9 px |

The [official Foundation 1.9.0 sources](https://dl.google.com/dl/android/maven2/androidx/compose/foundation/foundation-android/1.9.0/foundation-android-1.9.0-sources.jar), `commonMain/androidx/compose/foundation/text/modifiers/ParagraphLayoutCache.kt:366-402`, implement `slowCreateTextLayoutResultOrNull` by constructing MultiParagraph using the parent's maximum constraints, then attaching the actual smaller `layoutSize`. The [official UI Text 1.9.0 sources](https://dl.google.com/dl/android/maven2/androidx/compose/ui/ui-text-android/1.9.0/ui-text-android-1.9.0-sources.jar), `commonMain/androidx/compose/ui/text/TextLayoutResult.kt:315-317`, define width overflow as actual size narrower than that paragraph. This semantics reconstruction produces a false positive for an intrinsic-width String Text.

The corrected oracle removes only that invalid paragraph-width comparison. It retains requested platform font scale, one-line/no-ellipsis/every-character visibility, actual line and per-character horizontal advances within allocated width, native viewport and parent navigation containment, and exact accessible unread count. It also requires positive allocated dimensions and adds line/per-character vertical containment. Counts 1, 99 and 100 (display 99+) run at 1x and 2x for both three and four tabs in the 320 dp fixture. The label must fit within its own named Role.Tab as well as the overall navigation and native viewport; a badge spilling into a neighboring tab therefore fails.

The fixed-22 dp original layout must fail one of these valid containment/visibility assertions before the badge fix is called verified.

## 3. Info glyph: measure antialiased foreground ink

Diagnostic3's regular 14 dp info target contained 2,304 pixels: 2,223 white background and 81 nonwhite. Only three pixels were within eight RGB units of the raw tint. Scaling a 24-unit outlined vector to 14 physical pixels places thin strokes between pixel centers; the remaining real ink blends with the white background. The small 12 dp variant already passed.

The test now identifies pixels consistent with tint composited over the fixture's explicit white background. It projects RGB channel deltas onto the foreground/background line, requires at least 10% foreground coverage, and permits three channel units of raster rounding. The minimum eight ink pixels, maximum painted dimensions of 12/14 dp plus one physical pixel, glyph containment within its button, actual 48 dp target, and physical tap outside the glyph remain unchanged. No production size or click behavior changed during this iteration.

## Corrected RED / GREEN recipe

The coordinator should save the exact current copies outside the repository, temporarily restore these four production files from `69034d84`, and run this corrected test class with the aligned Compose BOM:

- `designsystem/components/EsBottomNav.kt`
- `designsystem/components/VerifiedBadgeWithInfo.kt`
- `designsystem/components/DeleteAccountSheet.kt`
- `features/home/HomeHubScreen.kt`

Paths are relative to `app/src/main/kotlin/com/equipseva/app/`. Keep all corrected tests and other source unchanged. Archive the corrected old-state XML, restore the exact saved current production files, then run the frozen final targets and broader checks. No old failure should be relabeled as valid product evidence when its oracle was not valid.

Scoped `git diff --check` on the edited test exited 0. Corrected old-state execution and final execution remain pending at this note's creation.
