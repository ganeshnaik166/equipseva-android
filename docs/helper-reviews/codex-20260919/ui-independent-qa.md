# Shared UI independent QA — 2026-09-19

**Scoped score: 9.5/10 for the implementation and executed synthetic UI regression evidence. No new actionable blocker found in this patch. This is not whole-app, device, security, screenshot, or release acceptance.**

Reviewer: `quality_security_audit`, independent of the shared UI implementation. Read-only review; no source edits, Gradle execution, staging, or commits.

## Exact scope

- Implementation: `3d9ee8d0e8d882a5b4fa6631e41252d8be33f3ad`.
- Full-check source: `5aaa78f073e00d82e6e211bd3ac2d548e14a3f39`.
- `git diff` between those commits over all 16 paths changed by the UI patch is empty, including `SharedUiReviewRegressionTest.kt`.
- Inspected all production deltas: Delete/Report busy sheets; five founder busy sheets; badge measurement; verification glyph/target separation; survey radio selection; RoleSelect/HospitalHomeActions shared-button adoption; Welcome/EmailVerify token substitutions. Read the shared button implementations used by the migrated callers and the complete new regression test.
- Also read the prior independent critic reports and oracle-correction note, then checked source and actual XML rather than accepting their conclusions alone.

## Red/green evidence independently checked

| Evidence | Tests | Failures | Errors | Skipped |
| --- | ---: | ---: | ---: | ---: |
| `ui-corrected-baseline-red-xml/TEST-com.equipseva.app.designsystem.components.SharedUiReviewRegressionTest.xml` | 6 | 6 | 0 | 0 |
| `full-check-xml/TEST-com.equipseva.app.designsystem.components.SharedUiReviewRegressionTest.xml` | 6 | 0 | 0 | 0 |
| All 421 classes in `full-check-xml` | 3,675 | 3 | 0 | 0 |
| `lint-annotation-check-xml/TEST-com.equipseva.app.designsystem.components.OtpRenewalDismissalTest.xml` | 3 | 0 | 0 | 0 |

The six shared UI test names match between corrected baseline and full-check XML. Old production fails for concrete effects: native Back hides the busy Delete sheet; choosing four stars marks four radios selected; `99+` at 1x and `1` at 2x clip vertically; both info glyphs paint 40 px wide instead of the intended 12/14 dp glyph. All six pass after the patch.

The initial invalid badge paragraph-width assertion is not used as product-red evidence. The corrected test retains actual line/character containment, vertical containment, no ellipsis, requested platform font scale, exact accessible count, and containment in its own tab/native viewport. It exercises three/four tabs and 1/99/100 counts at 1x/2x. The icon test measures actual antialiased tint-over-white ink and a physical tap outside the glyph, retaining a 48 dp minimum target. The Back test dispatches the real dialog's native Back, compares the settled busy layout, verifies visible error recovery, and requires the same ready dialog to dismiss exactly once. These corrections repair invalid test assumptions without removing the intended behavioral checks.

## Source judgment

- Busy state is read through `rememberUpdatedState`, while the SheetState transition predicate stays stable. Native Back is handled inside the dialog with the same guard. Delete/Report retain current dismissal callbacks. The same guard is ported consistently to the five founder sheets; their screen mutation callbacks are unchanged.
- Badge content participates in measurement; the count cap and exact accessible count remain intact. Compact info artwork is separate from its physical action target and has a single accessible label.
- Survey selection now expresses one selected value while preserving cumulative star fill and the submitted value.
- RoleSelect preserves the explicit dark foreground on its fixed light surface. Shared buttons preserve callbacks and minimum, rather than fixed, text heights. Token substitutions retain the prior numerical values.
- No dependencies, auth policy, mutation authorization, navigation routes, or server behavior change in this UI patch.

## Broader evidence and remaining gates

The full-check XML independently totals 3,675 tests, three failures, zero errors/skips. All failures are the retained S1 `SignOutCleanup` ownership regressions; the full suite is **not green**. The same archive shows all five M6 photo-contract cases and all three native OTP-dismissal cases passing. The full-check log contains debug and unsigned R8 release assembly completion, but its combined command failed on the S1 tests and one `UseSdkSuppress` lint error.

The follow-up annotation-only commit `2fd157afe3f0bc30785e56c27e6b383132cb74a9` is recorded in `lint-annotation-check-source-sha.txt`. Its log ends `BUILD SUCCESSFUL`, including `lintDebug`; the three native OTP tests passed with zero skips. This corrects the lint gate without converting the three S1 failures to success. An unsigned assembly is not a shipped release.

Keep these acceptance limits explicit:

- S1 cross-login cleanup remains reproducibly failing. S3's explicit-clear recovery contract remains open when cancelled/failed logout returns the same cached account to Ready without an auth boundary. This UI review does not close either gate.
- The new busy-Delete native Back case runs at SDK 32. Existing native OTP tests exercise SDK 34 predictive Back, scrim, and drag, but do not replace per-host device coverage of all seven changed sheets. Busy changes during an already-started hide gesture are not proven here.
- No Linux reference-pixel screenshot verification, physical-device rendering/TalkBack, complete locale/RTL, dark-mode visual, or wider density/font-scale matrix was performed by this reviewer. Native bitmap assertions here are focused glyph evidence, not the repository's screenshot acceptance gate.
- Score deductions reflect those narrow execution limits and repeated host wiring. Do not reuse this 9.5 score for the broad quality branch or application.

**Disposition:** shared UI fixes are supported by focused red/green evidence and source review; preserve the broader candidate as WIP until independent S1/S3 and release/device gates are resolved.
