# Shared UI review — 2026-09-19

Read-only review of **b453f19a1b58ca89f10a2313d34806b0ed00a471**, compared with **9a0ecf89c8636d926fb4744fca79b1978789c77f**. Every repository reference below is pinned to b453f19a, not the integration worktree's changing HEAD. No Gradle, device, accounts, or production access used; no app/test files edited. These are source-confirmed findings and proposed reproductions, not executed UI results or acceptance ratings.

## Findings

### UI-01 — P1: busy sheets still become hidden through native Back

`app/src/main/kotlin/com/equipseva/app/designsystem/components/DeleteAccountSheet.kt:46–56` and `ReportContentSheet.kt:57–77` add a `confirmValueChange` gate but retain the default native Back behavior; they also remove their component-level busy guard from `onDismissRequest`. The same new gate is used in `features/founder/FounderBuyerKycQueueScreen.kt:241–248`, `FounderCategoriesScreen.kt:291–300`, `FounderKycQueueScreen.kt:237–247`, `FounderKycReviewScreen.kt:265–275`, and `FounderUsersScreen.kt:289–299`.

**Exact dependency evidence:** Material3 **1.3.1** `ModalBottomSheet.kt:154–165` invokes `sheetState.hide()` directly for native Back. Its `SheetDefaults.kt:195–201` hide method animates to Hidden without consulting the confirmation predicate. This differs from its scrim and drag-settle paths. Verified using the [official 1.3.1 source archive](https://dl.google.com/dl/android/maven2/androidx/compose/material3/material3-android/1.3.1/material3-android-1.3.1-sources.jar).

The live callers do have VM close guards (`ProfileViewModel.kt:491–492`, `ChatViewModel.kt:346–347`, `RepairJobDetailViewModel.kt:264–265`, and the five founder close methods). Consequently a pending operation + native Back hides the sheet while its guarded VM keeps it mounted; an ensuing error remains hidden. This native-Back failure predates the branch, but the newly claimed seven-sheet fix does **not** close it. Removing the component guard additionally weakens the reusable component contract.

**Required fix/test:** protect Back before Material starts its hide animation, retaining guarded callbacks as defense; reuse the coordinator's proven OTP approach. Exercise the actual dialog's key Back and API 33+/predictive path while pending, then the identical gesture after ready; pair with scrim/drag tests and failed-operation recovery. Do not merely test `sheetDismissAllowed`: its five new tests prove only the Boolean predicate. Dynamic `ModalBottomSheetProperties` alone needs care: 1.3.1's Android `equals` ignores the Back Boolean (`122–127`), and the API 33+ dialog layout captures it at construction (`328–331`, `493–499`).

### UI-02 — P2: rating survey announces multiple selected radio options

`features/home/HomeHubScreen.kt:510–519` uses `rating >= star` for both cumulative paint and the newly added `Role.RadioButton` selected state inside a selectable group. Choose rating 4: options 1, 2, 3, and 4 all expose Selected=true. This is introduced by the change and misrepresents the stored single rating to accessibility users.

**Minimal fix/test:** keep cumulative paint but use `rating == star` for selection semantics. Render the real survey, select each value, and assert exactly one selected radio (none for initial zero), five named options, and submitted rating matching the chosen option.

### UI-03 — P2: enlarged unread badge is still constrained to the 22dp icon

`designsystem/components/EsBottomNav.kt:126,153–165` nests the badge in a 22dp icon box and uses only `requiredWidthIn(min=18.dp)` / `requiredHeightIn(min=18.dp)`. These do **not** remove the incoming maximum: Foundation **1.7.6** `Size.kt:815–828` preserves the parent's max when the respective max parameter is unspecified. Thus the badge remains at most 22dp in both axes, with at most 16dp available for text after its horizontal padding. Multi-glyph `99+`, especially at larger font scales, is still clipped despite the new comment claiming it can grow freely. Verified with the [official Foundation 1.7.6 source archive](https://dl.google.com/dl/android/maven2/androidx/compose/foundation/foundation-layout-android/1.7.6/foundation-layout-android-1.7.6-sources.jar).

This is an incomplete fix of pre-existing clipping. `SharedChromeFontScaleTest.kt:111–123` checks only that a node named `99+` is displayed at 1x; it does not inspect glyph overflow, text layout or painted containment. `BottomNavBadgeLabelTest` tests string length, not fit.

**Minimal fix/test:** give the badge a genuinely unconstrained content measurement outside the fixed icon's constraints, while keeping placement inside the full tab. Test 1/99/100 at platform font scales 1x and 2x using TextLayoutResult overflow and actual glyph/background bounds. Retain the exact accessible unread count.

### UI-04 — P3: verified-info glyph grows to 48dp rather than retaining its size

`designsystem/components/VerifiedBadgeWithInfo.kt:71–81` puts `sizeIn(min=48.dp)` then `size(12.dp/14.dp)` on the **same Icon**. The outer minimum constrains the inner requested size back to 48dp; this grows the drawn info glyph as well as its hit target, contrary to the comment. Introduced visual regression in engineer directory/public profile badge clusters.

**Minimal fix/test:** a 48dp clickable Box with a centered separate 12/14dp Icon, as already used elsewhere in this patch. Assert both clickable bounds and child glyph bounds, plus tap success outside the glyph. No rendering executed in this review.

### UI-05 — P2 acceptance gap: new Hindi/Telugu control resources are English copies

Both `app/src/main/res/values-hi/strings.xml:968–984` and `values-te/strings.xml:968–984` contain the same English values as the base resources for Back, Close, Dismiss error, unread count, verification info, notifications, help, rating and founder controls. The accompanying localization comment is false. English behavior existed before, so this is unfinished localization rather than a newly introduced language regression.

**Minimal fix/test:** translate the 17 new control strings for each locale, retain format placeholders, and assert representative rendered accessible labels under hi/te resource configurations. Native-language/TalkBack acceptance remains separate.

## Existing gaps to retain in follow-up inventory

- `HomeHubScreen.kt:716–753`: help/notification icon-only controls have an action label but no Text/contentDescription name; an action label is not the control's accessible name. This predates the patch, which only moves the label into resources. Add explicit names and semantics assertions.
- `NotificationSettingsScreen.kt:188–213,239–251`: category text and switches are unmerged siblings; each switch exposes state/role without a name. Quiet-hours uses the same toggle. This predates the touch-target change. Label the actual switch or put toggle semantics on the whole named row, with a single accessibility stop.
- `EsSection` touch-target tests use a short English title and unconstrained action. They do not prove narrow/translated title + action coexistence. `SharedChromeFontScaleTest` uses parent LocalDensity, not system nonlinear text scaling; it is useful component coverage, not device/font-scale acceptance.

## Coverage and disposition

Inspected every changed hunk in **34 production files** across designsystem (15), home (2), notifications (2), and founder (15), plus the changed strings in en/hi/te and **11 changed/new tests** in those scopes. Read full new/shared components and test files; traced busy-sheet callers and close guards. For large founder/home screens this was changed-hunk plus surrounding-call-site review, not an entire-screen line-by-line audit. Numeric/date/list-error helpers and AdaptiveWidth's real layout test show reasonable focused improvements; no additional introduced defect confirmed there.

Not reviewed: full auth/sync/money/backend correctness, entire unchanged feature implementations, release signing, production migrations, full branch CI, all user journeys, native-language fluency, device/TalkBack/OEM keyboard behavior, or independent screenshots. Other reviewers own those areas.

**Disposition: not accepted for the claimed shared-UI quality fix yet.** UI-01/02/03 require correction and meaningful UI regression tests; UI-04 is a small visual repair; UI-05 must stay explicitly open until translated. No numerical rating or green run claimed. The helper's “no screenshot gate” statement describes its stale branch only; the coordinator reports newer main has an actual Roborazzi gate/ratchet, which must survive integration.
