# Compose UI audit — frozen snapshot `9a0ecf89` (C:/Users/lokes/equipseva-audit-snap)

Scope read in full: `designsystem/` (61 files), `features/home/` (5), `features/notifications/` (4), `features/founder/` (21), `features/about/` (1), plus `res/values{,-hi,-te}/strings.xml`. RoleSelectScreen.kt skipped (other owner). Read-only; nothing under the snapshot was modified. No CRITICAL/HIGH crash-class defects found; every `!!` on UI state is guarded by the enclosing `when` branch. 27 findings below, ordered by severity.

### C01 [MEDIUM] EsTopBar hard-codes a 52dp height around a title + optional subtitle
- File: app/src/main/kotlin/com/equipseva/app/designsystem/components/ESTopBar.kt:86-92, 125-141
- What: The shared top bar (70 feature files) is a `Row.height(52.dp)` containing a 16sp title with no `maxLines` and an optional 12/18sp caption subtitle. At font scale 1.5x (title+subtitle ≈ 56dp) or with a two-line Hindi/Telugu title the text is clipped at the bar edge; Android 14 allows 200% font scale.
- Evidence: `.fillMaxWidth()\n            .height(52.dp)\n            .background(PaperDefault)` … `if (subtitle != null) Text(text = subtitle, style = EsType.Caption, color = SevaInk500)`
- Fix: `.heightIn(min = 52.dp)` (or `.defaultMinSize(minHeight = 52.dp)`) and give the title `maxLines = 1, overflow = TextOverflow.Ellipsis`; keep subtitle single-line.
- Test: Robolectric Compose test with `LocalDensity` fontScale = 2f rendering `EsTopBar(title, subtitle)`; assert the Column node's height ≥ title height + subtitle height and that `onNodeWithText(subtitle)` is fully within the root bounds.
- Owner: ME

### C02 [MEDIUM] EsBottomNav fixed 72dp row with unbounded label wrap and an 18dp count badge
- File: app/src/main/kotlin/com/equipseva/app/designsystem/components/EsBottomNav.kt:66-75, 125-149
- What: Primary navigation is `Row.height(72.dp)`; the label `Text(fontSize = 11.sp)` has no `maxLines`, so a long or translated label wraps to two lines and is clipped (icon box 30dp + 2-line label ≈ 34dp + 20dp padding > 72dp even at 1.0x; single line clips from ~1.5x). The unread badge is a `size(18.dp)` circle rendering `tab.badge.toString()` verbatim, so 3-digit counts overflow the circle.
- Evidence: `.height(72.dp)` … `Text(text = tab.label, fontSize = 11.sp, … modifier = Modifier.padding(top = 2.dp))` … `Box(modifier = Modifier.align(Alignment.TopEnd).size(18.dp)…) { Text(text = tab.badge.toString(), … fontSize = 11.sp` 
- Fix: `heightIn(min = 72.dp)`; label `maxLines = 1, overflow = Ellipsis`; badge `text = if (badge > 99) "99+" else badge.toString()` with `widthIn(min = 18.dp)` + horizontal padding instead of a fixed square.
- Test: Compose test with a 3-tab list at fontScale 1.5f and a 14-char label; assert label node is not clipped (bounds within root) and `badge = 120` renders "99+".
- Owner: ME

### C03 [MEDIUM] Swipe-dismissing a ModalBottomSheet while its action is in flight leaves an invisible modal window that swallows all taps
- File: app/src/main/kotlin/com/equipseva/app/designsystem/components/DeleteAccountSheet.kt:46-49 (same pattern: ReportContentSheet.kt:63-66; features/founder/FounderBuyerKycQueueScreen.kt:112-115,237; FounderKycQueueScreen.kt:126-129,235; FounderKycReviewScreen.kt:132-135,263; FounderCategoriesScreen.kt:187-190,285; FounderUsersScreen.kt:161-164,287)
- What: `onDismissRequest` is ignored while `deleting`/`submitting`/`acting`/`saving` is true, but the drag gesture is not blocked, so the sheet animates to `Hidden` and M3 (BOM 2024.12.01 → material3 1.3.1) fires `onDismissRequest` exactly once. The composable stays in composition at `Hidden`: the Dialog window remains full-screen, the scrim is invisible and its tap handler is disabled (`visible = targetValue != Hidden`), so the screen looks idle and every tap is swallowed until the user presses Back. For DeleteAccountSheet the `passwordError` shown on a wrong password is never seen because the sheet is already hidden.
- Evidence: `ModalBottomSheet(\n        onDismissRequest = { if (!deleting) onDismiss() },\n        sheetState = sheetState,`
- Fix: Block the gesture instead of ignoring the callback: `val busy by rememberUpdatedState(deleting); val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true, confirmValueChange = { it != SheetValue.Hidden || !busy })`, and always call `onDismiss()` from `onDismissRequest`.
- Test: Compose test: render DeleteAccountSheet(deleting = true), `swipeDown()` on the sheet, assert `onDismiss` not called AND `onNodeWithText("Deleting…")` still displayed (sheet did not hide).
- Owner: ME

### C04 [MEDIUM] Notification-permission banner is computed during composition and never re-evaluated when the user returns from system Settings
- File: app/src/main/kotlin/com/equipseva/app/features/notifications/NotificationSettingsScreen.kt:82-93
- What: `areNotificationsEnabled()` is read as a plain local during composition. Returning from the system Settings deep link triggers ON_RESUME but no state change; `categories`/`quietHours` re-emit identical values through `StateFlow` so nothing recomposes, and the "Notifications are turned off" banner stays after the user has granted permission (the comment claims the opposite).
- Evidence: `val systemNotificationsEnabled = androidx.core.app.NotificationManagerCompat\n        .from(context).areNotificationsEnabled()`
- Fix: `var enabled by remember { mutableStateOf(NotificationManagerCompat.from(context).areNotificationsEnabled()) }; LifecycleResumeEffect(Unit) { enabled = …areNotificationsEnabled(); onPauseOrDispose {} }`.
- Test: Robolectric: `ShadowNotificationManager.setNotificationsEnabled(false)`, compose screen, assert banner; flip to true, move `TestLifecycleOwner` STARTED→RESUMED, assert banner gone.
- Owner: ME

### C05 [MEDIUM] EsToggle (the only mute / quiet-hours control) has a 44x26dp touch target
- File: app/src/main/kotlin/com/equipseva/app/features/notifications/NotificationSettingsScreen.kt:212-221
- What: The custom switch is `Box.size(width = 44.dp, height = 26.dp).toggleable(...)` with no minimum-interactive-size padding; 26dp is far below the 48dp Material/WCAG floor, and it is the sole affordance for every category mute and the quiet-hours enable.
- Evidence: `.size(width = 44.dp, height = 26.dp)\n            .clip(RoundedCornerShape(999.dp))\n            .background(if (on) SevaGreen700 else BorderStrong)\n            .toggleable(`
- Fix: Wrap in `Box(Modifier.minimumInteractiveComponentSize().toggleable(...), contentAlignment = Center)` with the 44x26 visual inside; or move `toggleable` to the whole `CategoryRow`.
- Test: Compose test `onNode(isToggleable())` → `assertTouchHeightIsAtLeast(48.dp)` / `assertTouchWidthIsAtLeast(48.dp)`.
- Owner: ME

### C06 [MEDIUM] EsChip clickable pills are 32dp tall (12 feature screens of filters)
- File: app/src/main/kotlin/com/equipseva/app/designsystem/components/EsChip.kt:49-73
- What: `labelMedium` (14/20sp) + `padding(vertical = 6.dp)` yields a 32dp clickable row with no touch-target inflation; every filter/spec/urgency pill in the app is under the 48dp minimum.
- Evidence: `.let { if (onClick != null) it.clickable(onClick = onClick, role = Role.Button) else it }\n            …\n            .padding(horizontal = 12.dp, vertical = 6.dp),`
- Fix: Apply `Modifier.minimumInteractiveComponentSize()` before the clip/background when `onClick != null` (visual pill unchanged, hit area grows), or `padding(vertical = 8.dp)` + `heightIn(min = 48.dp)`.
- Test: Compose test rendering `EsChip("Filter", onClick = {})` → `onNodeWithText("Filter").assertTouchHeightIsAtLeast(48.dp)`.
- Owner: ME

### C07 [MEDIUM] EsSection trailing action ("See all") is a bare 13sp clickable Text (~17dp tall)
- File: app/src/main/kotlin/com/equipseva/app/designsystem/components/EsSection.kt:49-62 (callers incl. features/home/HomeHubScreen.kt:345-348, 1180-1187)
- What: The section action link has only `padding(start = 8.dp)`; its hit area is the glyph box (≈17x50dp). Used for the Home "Recent activity → See all" and "Recommended engineers → See all".
- Evidence: `modifier = Modifier\n                        .clickable(onClick = onAction, role = Role.Button)\n                        .padding(start = 8.dp),`
- Fix: `.minimumInteractiveComponentSize()` (or `padding(horizontal = 8.dp, vertical = 12.dp)` + `heightIn(min = 48.dp)`) on the action Text.
- Test: Compose test `EsSection(title, action = "See all", onAction = {})` → `onNodeWithText("See all").assertTouchHeightIsAtLeast(48.dp)`.
- Owner: ME

### C08 [MEDIUM] VerifiedBadgeWithInfo info icon is a 12–14dp clickable with no role and an English-only label
- File: app/src/main/kotlin/com/equipseva/app/designsystem/components/VerifiedBadgeWithInfo.kt:66-73
- What: The "how we verify" sheet is opened by tapping a `size(12/14.dp).clickable {}` Icon: unhittable for most users, no `Role.Button`, hard-coded `contentDescription = "How we verify engineers"`. Used on the engineer directory card and public profile hero (2 files).
- Evidence: `modifier = Modifier\n                .size(if (small) 12.dp else 14.dp)\n                .clickable { showInfoSheet = true },`
- Fix: `IconButton(onClick = { showInfoSheet = true }, modifier = Modifier.size(48.dp)) { Icon(…, contentDescription = stringResource(R.string.verified_badge_info_title), Modifier.size(14.dp)) }` (or `.minimumInteractiveComponentSize()` + `role = Role.Button`).
- Test: Compose test → `onNodeWithContentDescription(...).assertTouchWidthIsAtLeast(48.dp)` and `assert(hasClickAction() and hasRole(Role.Button))`.
- Owner: ME

### C09 [MEDIUM] Spot-audit star buttons: 40dp targets, no selected state for TalkBack, English-only label
- File: app/src/main/kotlin/com/equipseva/app/features/home/HomeHubScreen.kt:482-511
- What: The five rating circles are `Box.size(40.dp).clickable(onClickLabel = "Rate $star out of 5", role = Button)`; the current rating is conveyed only by fill colour (no `selected`/`stateDescription`), so a screen-reader user cannot tell which star is chosen, and the 40dp hit area is below the 48dp floor. This gates a hospital-facing quality survey.
- Evidence: `.size(40.dp)\n                        .clip(…CircleShape)\n                        …\n                        .clickable(\n                            onClickLabel = "Rate $star out of 5",\n                            role = androidx.compose.ui.semantics.Role.Button,\n                        ) { rating = star }`
- Fix: Use `Modifier.selectable(selected = isOn, role = Role.RadioButton, onClick = …)` inside a `Row(Modifier.selectableGroup())`, wrap each in `minimumInteractiveComponentSize()`, and move the label to `R.string`.
- Test: Compose test: set rating 3, assert nodes 1..3 `isSelected()` and node 4 `isNotSelected()`; `assertTouchHeightIsAtLeast(48.dp)` on a star.
- Owner: ME

### C10 [MEDIUM] ReportContentSheet reason rows: label is not tappable and the radio has no accessible name
- File: app/src/main/kotlin/com/equipseva/app/designsystem/components/ReportContentSheet.kt:84-101
- What: Each reason is `RadioButton(onClick)` + a separate non-clickable `Text`. Tapping the reason text does nothing (only the 48dp radio toggles), and TalkBack announces an unlabeled "radio button, not checked" because the label is a sibling node, not merged.
- Evidence: `RadioButton(\n                        selected = selected == reason,\n                        onClick = { selected = reason },\n                        enabled = !submitting,\n                    )\n                    Text(\n                        text = reason.displayName,`
- Fix: `Row(Modifier.fillMaxWidth().selectable(selected = selected == reason, role = Role.RadioButton, enabled = !submitting) { selected = reason })` with `RadioButton(selected, onClick = null)` inside; wrap the list in `Modifier.selectableGroup()`.
- Test: Compose test: `onNodeWithText(ContentReportReason.Fraud.displayName).performClick()`; assert that node `isSelected()`; assert every selectable node `hasText(...)` (label merged).
- Owner: ME

### C11 [MEDIUM] Contrast: SevaInk400 captions (3.95:1 on white, 3.7:1 on PaperDefault) and 65%-white labels on SevaGreen700 (3.6:1)
- File: app/src/main/kotlin/com/equipseva/app/designsystem/theme/Color.kt:45 (`SevaInk400 = 0xFF788379`); uses: features/home/HomeHubScreen.kt:811, 1156; features/notifications/NotificationsScreen.kt:244-251; features/founder/FounderDashboardScreen.kt:567-572; designsystem/components/InlineStars.kt:61-65
- What: 10–12sp body captions rendered in `SevaInk400` fail WCAG AA 4.5:1 (computed 3.95:1 on #FFFFFF, 3.70:1 on #F6F8F5). On the Home hero the 12sp stat labels use `Color.White.copy(alpha = 0.65f)` over `SevaGreen700` (#0B6E4F) → ≈3.6:1; the 13sp greeting at 75% ≈4.3:1. Small text at these ratios is the "poor contrast on brand green" class the design lint is meant to catch.
- Evidence: `Text(label, fontSize = 12.sp, color = Color.White.copy(alpha = 0.65f))` (HomeHubScreen.kt:811); `Text(relativeTime, fontSize = 11.sp, color = SevaInk400)` (HomeHubScreen.kt:1156)
- Fix: Use `SevaInk500` (#525C53, 7.0:1) for ≤12sp captions and raise hero label alpha to ≥0.85 (or use `SevaGreen50`) on the green gradient.
- Test: Unit test over the token pairs: `contrastRatio(SevaInk400, Color.White) >= 4.5` fails today → pin the replacement pairs; add a Roborazzi screenshot of GreetingCard for the hero.
- Owner: ME

### C12 [MEDIUM] values-hi and values-te are 93% untranslated copies of the English file
- File: app/src/main/res/values-hi/strings.xml, app/src/main/res/values-te/strings.xml (whole files; e.g. values-hi/strings.xml:455, values-te/strings.xml:452 are English)
- What: All 765 translatable keys are present in both locales with matching placeholders, but 709/765 values are byte-identical to `values/strings.xml`; only 56 differ and only 26 contain Devanagari/Telugu script. The theme switches to Noto Devanagari/Telugu by language (Theme.kt:63-67), so a Hindi/Telugu user gets an English UI in a different font. The one non-translatable key (`razorpay_api_key`) is correctly excluded.
- Evidence: `values-hi: identical-to-English=709 translated(differs)=56 strings-containing-native-script=26` (same numbers for values-te); e.g. `<string name="earnings_projection_top_tier_sub">Gold rates are the lowest we offer (5%).</string>` in all three files.
- Fix: Either finish the translations or, until then, delete the untranslated entries from values-hi/-te (fall back to default) and enable lint `MissingTranslation` so the gap is visible in CI rather than masked by English copies.
- Test: Resource unit test: parse the three files; assert `identical / total < 0.10` per locale (ratchet), and `MissingTranslation` lint enabled.
- Owner: ME

### C13 [MEDIUM] User-facing copy hard-coded in Kotlin on screens that otherwise use R.string
- File: app/src/main/kotlin/com/equipseva/app/features/home/HomeHubScreen.kt:296-331, 346-347, 522, 562-572, 790-800, 1185-1186, 1321-1323, 1346-1348, 1390-1393, 1419-1421, 1437, 1526-1530, 1535-1544; designsystem/components/HelpSupportSheet.kt:87, 102-131, 141-153, 194, 287, 302; features/notifications/NotificationsScreen.kt:97, 155-156, 334-337; NotificationSettingsScreen.kt:88, 107, 134; NotificationSettingsViewModel.kt:89-111; features/about/AboutScreen.kt:60, 113, 134, 155, 184; designsystem/components/DeleteAccountSheet.kt:123; ReportContentSheet.kt:123; StatusPill.kt:23-30; UrgencyPill.kt:19-22; EsKycChip.kt:19-24; InlineStars.kt:38
- What: The Home hub (tiles, greeting, stats, section titles, survey answers, empty copy, KYC banner), Help & Support sheet, inbox headers/empty state, notification categories, About rows, the delete/report confirm buttons and every job-status/urgency/KYC pill are literal English while adjacent strings in the same composables use `stringResource` (e.g. `home_spot_audit_title`, `helpsupport_reach_our_team`, `notification_settings_*`, `about_version_label`). The `home_*` namespace has 13 keys; none cover the tiles or greeting. Combined with C12 the app is English-only in practice.
- Evidence: `title = "Find work",` (HomeHubScreen.kt:296); `EsBottomSheet(onClose = onClose, title = "Help & support")` (HelpSupportSheet.kt:87); `RepairJobStatus.Requested  -> "Requested"  to PillKind.Info` (StatusPill.kt:23)
- Fix: Move each literal to `R.string` (pure helpers such as `homeRecentEmptyCopy`/`statusPillTextAndKind` should return `@StringRes Int` or take a `Resources`), and enable the `HardcodedText`/custom design-lint check on `Text(text = "...")` in features/.
- Test: Lint baseline with `HardcodedText` = error for `features/home`, `features/notifications`, `features/about`, `designsystem`; unit test that `statusPillTextAndKind` returns resource ids for all enum values.
- Owner: ME

### C14 [LOW] Accessibility labels in shared components are English literals ("Back", "Close", "Dismiss error", "Verified", …)
- File: app/src/main/kotlin/com/equipseva/app/designsystem/components/ESTopBar.kt:63, 113; EsBottomSheet.kt:55; ErrorBanner.kt:62; BidCard.kt:106; VerifiedBadgeWithInfo.kt:56, 68; EsBottomNav.kt:96-98; features/notifications/NotificationsScreen.kt:111, 126; features/founder/FounderUsersScreen.kt:372, 383; features/home/HomeHubScreen.kt:498, 618, 691, 713, 831, 866
- What: TalkBack announcements for the back arrow (70 screens), sheet close, error dismiss, unread suffix (`"${tab.label}, ${tab.badge} unread"`), and the Home icon buttons are not localizable, so a Hindi/Telugu screen-reader user hears English control names even where the visible label is translated.
- Evidence: `contentDescription = "Back",` (ESTopBar.kt:113); `contentDescription = if ((tab.badge ?: 0) > 0)\n                            "${tab.label}, ${tab.badge} unread"\n                        else tab.label` (EsBottomNav.kt:96-98)
- Fix: Add `common_back`, `common_close`, `common_dismiss_error`, `bottom_nav_unread_cd` (`%1$s, %2$d unread`) etc. and read them via `stringResource`.
- Test: Grep-based unit test (or lint) asserting no `contentDescription = "` / `onClickLabel = "` literals under designsystem/ and features/home/.
- Owner: ME

### C15 [LOW] EsBottomNav announces each tab label three times
- File: app/src/main/kotlin/com/equipseva/app/designsystem/components/EsBottomNav.kt:90-100, 112-117, 143-149
- What: The clickable Column sets its own `contentDescription = tab.label`, the Icon inside repeats `contentDescription = tab.label`, and the label `Text` is also merged by `clickable`. `ContentDescription` merges by concatenation, so TalkBack reads "Home, Home, Home, tab, selected".
- Evidence: `.semantics {\n                        selected = active\n                        …contentDescription = … tab.label\n                    }\n                    .clickable(role = Role.Tab) { onSelect(tab.route) }` … `Icon(imageVector = tab.icon, contentDescription = tab.label,`
- Fix: `Icon(contentDescription = null)` and drop the Column's `contentDescription` when there is no badge (let the merged label Text supply the name); keep `stateDescription` for the unread count.
- Test: Compose semantics test: `onNodeWithText("Home")` → `fetchSemanticsNode().config[ContentDescription]` has size ≤ 1.
- Owner: ME

### C16 [LOW] Row-level `clickable` without `Role.Button` and several sub-48dp text/icon targets
- File: app/src/main/kotlin/com/equipseva/app/features/home/HomeHubScreen.kt:595, 1030, 1089, 1139, 1215, 1303-1308; features/notifications/NotificationsScreen.kt:102-106, 117-121, 219; NotificationSettingsScreen.kt:361-367; features/founder/FounderPaymentsScreen.kt:227-236; FounderDashboardScreen.kt:787, 881, 993; FounderEngineerPayoutsScreen.kt:531-532, 658-659
- What: The Home tiles, activity rows, survey answer buttons, recommended-engineer card and the founder queue rows use `clickable(onClick = …)` with no role, so TalkBack does not announce them as buttons. In addition: the recommended card's "View" pill is a ~24dp-tall clickable Text nested inside an already-clickable card that goes to the same destination; the inbox "Mark all read"/"Notification settings" icons are 36dp `Box.clickable`; "Open system settings" and the payments "⚠ N integrity" pill are bare clickable Text/Pill (≈17–26dp).
- Evidence: `.clickable(onClick = onClick)\n            .padding(16.dp),` (HomeHubScreen.kt:1089-1090); `.size(36.dp)\n                                    .clip(CircleShape)\n                                    .clickable(onClick = viewModel::markAllRead),` (NotificationsScreen.kt:104-106)
- Fix: Pass `role = Role.Button` (or use `IconButton`, which supplies the 48dp minimum) and remove the redundant inner "View" click or give it `minimumInteractiveComponentSize()`.
- Test: Compose tests: `onNodeWithText("Find work").assert(hasRole(Role.Button))`; `onNodeWithContentDescription("Mark all read").assertTouchHeightIsAtLeast(48.dp)`.
- Owner: ME

### C17 [LOW] `Modifier.maxContentWidth()` applies `fillMaxWidth()` before `widthIn(max)`, so the tablet cap is a no-op
- File: app/src/main/kotlin/com/equipseva/app/designsystem/AdaptiveWidth.kt:50-59
- What: `fillMaxWidth()` fixes the incoming constraints to the parent width; `widthIn(max = 840.dp)` (enforceIncoming) is then coerced back to that fixed width, so on Medium/Expanded windows content still spans the full width — the documented purpose ("so list rows / forms don't sprawl on tablets") is defeated. One consumer today (RepairJobsScreen).
- Evidence: `this\n            .fillMaxWidth()\n            .widthIn(max = ContentMaxWidth)`
- Fix: Reverse the order: `this.widthIn(max = ContentMaxWidth).fillMaxWidth()` (and centre with `wrapContentWidth(Alignment.CenterHorizontally)` at the call site).
- Test: Compose layout test with a 1000dp-wide root: `Box(Modifier.maxContentWidth())` → `assertWidthIsEqualTo(840.dp)` (fails today with 1000dp).
- Owner: ME

### C18 [LOW] StatusChip fixes its height at 22dp around 11sp text
- File: app/src/main/kotlin/com/equipseva/app/designsystem/components/StatusChip.kt:53-58, 70-77
- What: `.defaultMinSize(minHeight = 22.dp).height(22.dp)` on a Row whose only content is text with `lineHeight = 14.sp`; at font scale ≥1.6 (14sp → 22.4dp) the glyphs clip. Consumer: ProfileScreen (plus BidCard/RoleSelectCard which are dead, see C27).
- Evidence: `.defaultMinSize(minHeight = 22.dp)\n                .height(22.dp)\n                .clip(RoundedCornerShape(50))`
- Fix: Drop `.height(22.dp)`; keep `defaultMinSize(minHeight = 22.dp)` and `padding(vertical = 2.dp)`.
- Test: Compose test at fontScale 2f: `onNodeWithText(label)` bounds within the chip bounds.
- Owner: ME

### C19 [LOW] Home AMC chip says "expires today" for contracts that already expired and shows raw ISO dates
- File: app/src/main/kotlin/com/equipseva/app/features/home/HomeHospitalAmcChip.kt:93-98, 125-131
- What: `daysUntil` returns negative values for past `end_date`, and the `daysLeft <= 0` branch renders "expires today" for any expired contract; for >30 days the chip prints `top.endDate` verbatim (`2027-03-05`) instead of a formatted date. Both strings are also English literals.
- Evidence: `daysLeft <= 0 -> "expires today"\n        daysLeft <= 30 -> "expires in $daysLeft days"\n        else -> top.endDate`
- Fix: Add `daysLeft < 0 -> stringResource(R.string.amc_chip_expired, prettyDate(top.endDate))`, `== 0 -> expires today`, and use `prettyDate(top.endDate)` for the far branch.
- Test: Unit test on an extracted `amcChipExpiryLine(daysLeft, endDate)` with -3 → "expired", 0 → "today", 45 → formatted date.
- Owner: ME

### C20 [LOW] Home "Recent activity" relative times are frozen for the life of the list
- File: app/src/main/kotlin/com/equipseva/app/features/home/HomeHubScreen.kt:376-381, 1382-1394
- What: `relativeTime(n.sentAt)` is computed inside `remember(state.recent)`, so "just now"/"5m ago" never advances while the hub stays on screen (the hub is the cold-start landing screen and refreshes only on ON_RESUME); after an hour idle the rows still read "just now".
- Evidence: `val labeledRows = remember(state.recent) {\n                            …Triple(n, relativeTime(n.sentAt), i == last)`
- Fix: Add a minute tick key: `val now by produceState(Instant.now()) { while (true) { delay(60_000); value = Instant.now() } }` and `remember(state.recent, now)`; or compute the label in `ActivityRow` per recomposition (it is 3 rows).
- Test: Compose test with a fake clock: advance `mainClock` 10 minutes, assert the row text changes from "just now" to "10m ago".
- Owner: ME

### C21 [LOW] Four founder lists disappear behind an error empty-state when a pull-to-refresh fails
- File: app/src/main/kotlin/com/equipseva/app/features/founder/FounderAmcExpiringScreen.kt:85, 117; FounderPausedAmcScreen.kt:86, 118; FounderInactiveEngineersScreen.kt:83, 115; FounderIntegrityScreen.kt:100, 136
- What: These VMs set `error` on every failure (unlike KycQueue/Payments/Reports which only set it when `rows.isEmpty()`), and the screens branch `state.error != null -> EmptyStateView` before checking rows, so a transient refresh failure replaces already-loaded rows with "Couldn't load".
- Evidence: `.onFailure { e -> _state.update { it.copy(loading = false, refreshing = false, error = e.toUserMessage()) } }` … `state.error != null -> EmptyStateView(`
- Fix: Match the sibling screens: `state.error != null && state.rows.isEmpty() -> EmptyStateView(...)` and surface refresh errors with `ErrorBanner` above the list.
- Test: VM unit test: seed rows, fail the second `fetch`, assert `rows` non-empty; Compose test asserting the list nodes still exist with `error != null`.
- Owner: ME

### C22 [LOW] Payouts screen renders "No payouts … try a different filter" under the load-error banner
- File: app/src/main/kotlin/com/equipseva/app/features/founder/FounderEngineerPayoutsScreen.kt:407-446
- What: On a failed load `rows` is empty and `errorMessage` is set, so both the warning banner and the filter-oriented empty state show; the empty state's advice is wrong for a network failure.
- Evidence: `s.rows.isEmpty() -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {\n                    …EmptyStateView(\n                        icon = Icons.Outlined.Inbox,\n                        title = "No payouts $filterPhrase",`
- Fix: Add `s.errorMessage != null && s.rows.isEmpty() -> Spacer/nothing` before the empty branch (the banner already carries Retry).
- Test: Compose test with `errorMessage = "x", rows = []` → `onNodeWithText("No payouts", substring = true).assertDoesNotExist()`.
- Owner: ME

### C23 [LOW] Category sort order silently saved as 100 when the typed number overflows Int
- File: app/src/main/kotlin/com/equipseva/app/features/founder/FounderCategoriesScreen.kt:206, 399-412
- What: The field accepts unlimited digits; `draft.sortOrder.toIntOrNull() ?: 100` turns any value > 2,147,483,647 (or an accidental long paste) into 100 with no validation error, so the founder's intent is overwritten without feedback.
- Evidence: `val sort = draft.sortOrder.toIntOrNull() ?: 100`
- Fix: Cap input in `onValueChange` (`.take(6)`) and reject in `save()` with `error = "Sort order must be 0–999999"` instead of substituting.
- Test: VM unit test: `sortOrder = "99999999999"` → `save()` sets `error`, does not call `upsertCategory`.
- Owner: ME

### C24 [LOW] UTC timestamps truncated and shown as wall-clock time
- File: app/src/main/kotlin/com/equipseva/app/features/founder/FounderCashFlagHistoryScreen.kt:259-260; FounderAmcEscalationDetailScreen.kt:244
- What: `rawIso.take(16).replace('T', ' ')` drops the zone suffix of a UTC ISO string, so a response at 09:30 IST displays as "04:00" with no zone marker; the same screens format neighbouring fields with `prettyDateTime` (zone-aware), so times on one card disagree by 5.5h.
- Evidence: `internal fun cashFlagRespondedAtLabel(rawIso: String): String =\n    rawIso.take(16).replace('T', ' ')` ; `detail.nextVisitAt?.let { LabelRow("Next visit", it.take(16).replace('T', ' ')) }`
- Fix: Use `prettyDateTime(it)` in both places (already imported).
- Test: Unit test: `cashFlagRespondedAtLabel("2026-09-01T04:00:00Z")` should equal `prettyDateTime(...)` output in Asia/Kolkata ("09:30").
- Owner: ME

### C25 [LOW] Three strings contain a literal `%` without `formatted="false"` (all three locales)
- File: app/src/main/res/values/strings.xml:461, 617, 625; values-hi/strings.xml:455, 608, 616; values-te/strings.xml:452, 609, 617
- What: `earnings_projection_top_tier_sub` ("(5%)."), `job_profitability_platform_fee` ("(7%)") and `job_profitability_explainer` ("7% platform fee") carry a bare `%` but lack the `formatted="false"` that the sibling `commission_tier_explainer` (:608) has. Today all three are read arg-less via `stringResource(id)` (EngineerEarningsProjectionScreen.kt:168, JobProfitabilityScreen.kt:160, 203), so there is no runtime crash; the first caller that passes an argument gets `UnknownFormatConversionException: %)`, and lint's StringFormat checks cannot protect them.
- Evidence: `<string name="job_profitability_platform_fee">Platform fee (7%)</string>`
- Fix: Add `formatted="false"` to the three keys in all three locale files.
- Test: Resource unit test: every string whose value matches `%(?![0-9]*\$?[sdf%])` must declare `formatted="false"`.
- Owner: ME

### C26 [LOW] Latent dark-theme contrast failure: fixed Ink900 text on theme-coloured surfaces
- File: app/src/main/kotlin/com/equipseva/app/MainActivity.kt:68-75 (theme selection); designsystem/components/ESTopBar.kt:55, 64; DeleteAccountSheet.kt:60, 70; ReportContentSheet.kt:77, 98; features/home/HomeHubScreen.kt:471, 548
- What: `EquipSevaTheme(darkTheme = isDark)` honours `ThemeMode.Dark/System` from prefs and `DarkEsColors` exists, but several components pair fixed near-black ink (`Ink900`/`SevaInk900`) with `MaterialTheme.colorScheme.surface` or the default `ModalBottomSheet` container, which becomes `#1B2018` in dark. No UI writes `setThemeMode` today (locked decision: no dark mode), so this is dormant — one settings toggle away from invisible titles/back arrows and unreadable delete/report/survey sheets.
- Evidence: `colors = TopAppBarDefaults.centerAlignedTopAppBarColors(\n            containerColor = MaterialTheme.colorScheme.surface,\n        )` with `color = Ink900` on the title (ESTopBar.kt:55, 69-71)
- Fix: Pin the decision in code: `EquipSevaTheme(darkTheme = false)` in MainActivity, or switch these text colours to `MaterialTheme.colorScheme.onSurface` / pass `containerColor = PaperDefault` to the sheets.
- Test: Compose test rendering `ESBackTopBar` inside `EquipSevaTheme(darkTheme = true)`; assert title colour contrast against the bar background ≥ 4.5:1.
- Owner: ME

### C27 [LOW] Dead UI code shipped in the design system and Home
- File: app/src/main/kotlin/com/equipseva/app/designsystem/components/EarningsHeroCard.kt, ActivityFeedRow.kt, DeliverySlotTile.kt, EquipmentBanner.kt, MapPlaceholder.kt, PaymentMethodTile.kt, TypingIndicator.kt, RoleSelectCard.kt, OfflineBanner.kt, PremiumGradientSurface.kt, Logo.kt (EquipSevaLogo/EquipSevaLogoSquare), EquipmentArt.kt (515 lines; `EquipmentIllustration` only reachable via the unused `GradientTile(art=)` overload); features/home/HomeHubScreen.kt:924-967 (`PhoneMissingBanner`), 1072 (`HomeTile.badge`, never passed)
- What: Zero call sites outside their own files (verified by symbol grep across `app/src/main/kotlin`). They carry their own hard-coded copy (OfflineBanner default message, EarningsHeroCard withdraw pill with a 40dp target) that any future consumer would inherit, and they inflate the surface that C13/C14 must localize.
- Evidence: `EarningsHeroCard: 0 files … PremiumGradientSurfaceDark: 0 files … EquipmentIllustration: 0 files` (usage grep); `private fun PhoneMissingBanner(onClick: () -> Unit)` with no caller.
- Fix: Delete the unused components and `PhoneMissingBanner` (and the two `home_phone_missing_banner_*` strings), or move them under a `preview/` source set.
- Test: Detekt `UnusedPrivateMember`/`UnusedPublicMember` (or a Konsist rule) asserting every `@Composable` in `designsystem/components` has ≥1 caller outside its file.
- Owner: ME

Verified-clean areas:
- Theme tokens and typography (Color.kt, LimeColors.kt, Theme.kt, Type.kt, Typography.kt, Shape/Spacing/Motion/Elevation/EsTokens): light-mode pairs (lime `#C6FF00` on `#11150B`, `SevaGreen700` on white, EsBtn Danger/Secondary/disabled pairs) all clear 4.5:1; per-language font families keyed on distinct resource ids; `LocalConfiguration.current.locales[0]?.language` null-safe.
- RefreshOnReturn, TapScale (`composed`), SecureScreen (ref-counted FLAG_SECURE), EsBtn/PrimaryButton/TonalButton (≥48/52dp minimums, focus borders, paired disabled colours), EsField/OtpDigitField/EsDropdown/EsInputColors (merged accessible names, `error()` semantics, IME actions, lifetime fences against stale callbacks, `remember` keyed on a copied `options` list), EsListRow/Pill/VerifiedBadge/GradientTile/EmptyStateView/LoadingShimmer.
- Locale-sensitive formatting: BidCard, InlineStars, EarningsHeroCard, HomeHubScreen distance line, FounderDashboard `formatPaiseAsRupees`, NotificationSettings `formatMinutes`, founder CSV export and UPI deeplink all pin `Locale.ENGLISH/US`; `String.uppercase()`/`Char.uppercase()` are invariant.
- Compose state: no `remember` without keys for per-item state, no `derivedStateOf`, all `LaunchedEffect` keys correct (`viewModel`, `state.done`, `selected`), all `collectAsStateWithLifecycle` on VM `StateFlow`s (no cold flows rebuilt per recomposition), every `LazyColumn.items` in home/notifications/founder has a stable key, no same-axis nested scrollables, `rememberSaveable` used for sheet/form drafts, KYC review double-pop guarded by a saveable `navigated` flag.
- Crash risks: every `!!` on UI state (FounderAmcEscalationDetailScreen:181, FounderKycReviewScreen:218, FounderBuyerKycQueueScreen:265, FounderEngineerMapScreen:130, FounderUsersScreen:310) is inside the null-checked `when`/`if` branch of the same snapshot read; `pinned.maxBy` guarded by the empty-return; `LocalDate.parse` failures caught; numeric input filtered to digits everywhere it is parsed.
- ViewModels: HomeHubViewModel (session `distinctUntilChangedBy`, best-effort loads, error surfacing), NotificationsInboxViewModel (optimistic mark-read with outbox fallback, capped-backoff retry), NotificationSettingsViewModel (`stateIn(WhileSubscribed)`), all founder VMs (in-flight guards via `acting`, JsonNull for optional RPC params, nullable wire fields defaulted).
- String resources: no keys missing in values-hi/values-te, no extra keys, no duplicate keys, zero placeholder count/type mismatches across the three locales, no `formatted="false"` string that still carries a real spec, no multiple non-positional specs; the only `translatable="false"` key (`razorpay_api_key`) is correctly absent from hi/te.
- AboutScreen (external links via the shared helper incl. `mailto:`), HospitalHomeActions (min-height buttons, script-safe font padding, heading semantics), HomeEngineerTierChip (null-safe branches).
