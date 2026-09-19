package com.equipseva.app.designsystem.components

import android.app.Application
import android.app.Dialog
import android.graphics.Bitmap
import android.graphics.Canvas
import android.os.SystemClock
import android.view.KeyEvent
import android.view.View
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.findViewTreeOnBackPressedDispatcherOwner
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Home
import androidx.compose.runtime.Composable
import androidx.compose.runtime.MutableState
import androidx.compose.runtime.mutableStateOf
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.ViewRootForTest
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.unit.dp
import androidx.test.core.app.ApplicationProvider
import com.equipseva.app.R
import com.equipseva.app.core.data.spotaudit.SpotAuditRepository
import com.equipseva.app.designsystem.theme.EquipSevaTheme
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.features.home.HomeHubScreen
import com.equipseva.app.features.home.HomeHubViewModel
import com.equipseva.app.testing.IsolatedUiPackageParser
import com.equipseva.app.testing.IsolatedUiTestRunner
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.emptyFlow
import kotlin.math.abs
import kotlin.math.ceil
import kotlin.math.floor
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RuntimeEnvironment
import org.robolectric.android.controller.ActivityController
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import org.robolectric.shadows.ShadowDialog

/**
 * Regression targets first inspected at b453f19a, with recorded RED execution.
 * Synthetic production components and native dialog windows, no accounts or provider calls.
 * No golden recording; only live semantics, native text layout and painted glyph measurements.
 */
@RunWith(IsolatedUiTestRunner::class)
@Config(application = Application::class, sdk = [34],
    shadows = [IsolatedUiPackageParser::class], qualifiers = "en-rUS-w320dp-h800dp-mdpi")
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@OptIn(ExperimentalTestApi::class)
class SharedUiReviewRegressionTest {
    @get:Rule val compose = createEmptyComposeRule()
    private lateinit var host: ActivityController<ComponentActivity>
    private var initialScale = 1f
    private val app: Application get() = ApplicationProvider.getApplicationContext()

    @Before fun isolate() {
        IsolatedUiPackageParser.assertIsolated(app)
        initialScale = RuntimeEnvironment.getFontScale()
    }

    @After fun close() {
        try { if (::host.isInitialized) host.pause().stop().destroy() }
        finally { RuntimeEnvironment.setFontScale(initialScale) }
    }

    @Test fun `spot audit exposes exactly the selected rating and submits that same value`() {
        val submitted = mutableListOf<Pair<Int, String?>>()
        val vm = mockk<HomeHubViewModel>(relaxed = true)
        // Null role deliberately avoids nested Hilt tier/AMC widgets. The real screen
        // still renders its real private survey body from the synthetic invitation.
        val state = MutableStateFlow(HomeHubViewModel.UiState(
            role = null,
            pendingSpotAudit = SpotAuditRepository.PendingInvitation(
                invitationId = "synthetic-invitation", repairJobId = "synthetic-job",
                jobNumber = "TEST-42", engineerName = "Test engineer",
            ),
        ))
        every { vm.state } returns state
        every { vm.messages } returns emptyFlow()
        every { vm.submitSpotAudit(any(), any()) } answers {
            submitted += firstArg<Int>() to secondArg<String?>()
        }
        render {
            HomeHubScreen(onOpenBookRepair = {}, onRequestService = {},
                onOpenEngineerJobs = {}, viewModel = vm)
        }
        val radio = SemanticsMatcher.expectValue(SemanticsProperties.Role, Role.RadioButton)
        val selected = SemanticsMatcher.expectValue(SemanticsProperties.Selected, true)
        compose.onAllNodes(radio).assertCountEquals(5)
        compose.onAllNodes(radio and selected).assertCountEquals(0)
        listOf(4, 1, 5, 2, 3).forEach { rating ->
            val name = app.getString(R.string.home_spot_audit_rate_star_cd, rating)
            compose.onNode(radio and hasContentDescription(name)).assertIsDisplayed().performClick()
            compose.onAllNodes(radio and selected).assertCountEquals(1)
            compose.onNode(radio and selected).assert(hasContentDescription(name))
            (1..5).forEach { option ->
                compose.onNode(radio and hasContentDescription(
                    app.getString(R.string.home_spot_audit_rate_star_cd, option)))
                    .assert(SemanticsMatcher.expectValue(SemanticsProperties.Selected, option == rating))
            }
            compose.onNode(hasText("Submit") and hasClickAction()).performClick()
            compose.runOnIdle { assertEquals(rating to null, submitted.last()) }
        }
        compose.runOnIdle { assertEquals(listOf(4, 1, 5, 2, 3), submitted.map { it.first }) }
    }

    @Test fun `unread badge renders every digit without clipping at platform default scale`() = badge(1f)
    @Test fun `unread badge renders every digit without clipping at platform double scale`() = badge(2f)

    private fun badge(scale: Float) {
        val unread = mutableStateOf(1)
        val tabCount = mutableStateOf(3)
        render(scale) {
            Column(Modifier.fillMaxSize().background(Color.White).padding(16.dp)) {
                EsBottomNav(
                    tabs = buildList {
                        add(EsBottomNavItem("home", "Home", Icons.Outlined.Home, badge = unread.value))
                        add(EsBottomNavItem("jobs", "Jobs", Icons.Outlined.Home))
                        if (tabCount.value == 4) {
                            add(EsBottomNavItem("earnings", "Earnings", Icons.Outlined.Home))
                        }
                        add(EsBottomNavItem("profile", "Profile", Icons.Outlined.Home))
                    },
                    currentRoute = "home", onSelect = {}, modifier = Modifier.testTag("review-nav"),
                )
            }
        }
        listOf(3, 4).forEach { count ->
            compose.runOnIdle { tabCount.value = count }
            assertBadgeCounts(unread, scale)
        }
    }

    private fun assertBadgeCounts(unread: MutableState<Int>, scale: Float) {
        listOf(1, 99, 100).forEach { count ->
            compose.runOnIdle { unread.value = count }
            val expected = if (count == 100) "99+" else count.toString()
            val label = compose.onNodeWithText(expected, useUnmergedTree = true).assertIsDisplayed()
            val results = mutableListOf<TextLayoutResult>()
            label.performSemanticsAction(SemanticsActions.GetTextLayoutResult) { it(results) }
            val layout = results.single { it.layoutInput.text.text == expected }
            assertEquals("Actual native text owner uses requested platform scale", scale,
                layout.layoutInput.density.fontScale, 0.001f)
            // String Text's semantics slow path rebuilds MultiParagraph using
            // the parent's maximum width, then pairs it with the smaller real
            // layoutSize (Foundation 1.9 ParagraphLayoutCache). Consequently
            // didOverflowWidth can be true for fitting text: observed 5 px of
            // glyphs in a 5 px layout with a 69 px semantics paragraph. Check
            // actual line/character advances against allocated bounds instead.
            assertTrue("Badge $expected has a nonempty allocated text layout at $scale",
                layout.size.width > 0 && layout.size.height > 0)
            assertFalse("Badge $expected is vertically clipped at $scale", layout.didOverflowHeight)
            assertEquals("Badge stays one line", 1, layout.lineCount)
            assertFalse("Badge never replaces digits with ellipsis", layout.isLineEllipsized(0))
            assertEquals("Every character remains visible", expected.length,
                layout.getLineEnd(0, visibleEnd = true))
            assertTrue("Glyph advances fit allocated text width", layout.getLineRight(0) <= layout.size.width + 1f)
            assertTrue("Glyph advances fit allocated text left edge", layout.getLineLeft(0) >= -1f)
            assertTrue("Line height fits allocated text height", layout.getLineTop(0) >= -1f &&
                layout.getLineBottom(0) <= layout.size.height + 1f)
            expected.indices.forEach { index ->
                val glyph = layout.getBoundingBox(index)
                assertTrue("Character $index fits badge width: $glyph", glyph.left >= -1f &&
                    glyph.right <= layout.size.width + 1f)
                assertTrue("Character $index fits badge height: $glyph", glyph.top >= -1f &&
                    glyph.bottom <= layout.size.height + 1f)
            }
            val labelBounds = bounds(label)
            assertContains("Badge is contained in full nav", bounds(compose.onNodeWithTag("review-nav")), labelBounds)
            val view = nativeView(label)
            assertContains("Badge remains inside native viewport",
                Rect(0f, 0f, view.width.toFloat(), view.height.toFloat()), labelBounds)
            val owningTab = compose.onNode(hasContentDescription(app.getString(R.string.bottom_nav_unread_cd, "Home", count)) and
                SemanticsMatcher.expectValue(SemanticsProperties.Role, Role.Tab)).assertExists()
            assertContains("Badge is contained in its own tab", bounds(owningTab), labelBounds)
        }
    }

    @Test fun `small verification info keeps its glyph separate from the full touch target`() = infoGlyph(true, 12f)
    @Test fun `regular verification info keeps its glyph separate from the full touch target`() = infoGlyph(false, 14f)

    private fun infoGlyph(small: Boolean, glyphDp: Float) {
        render {
            Box(Modifier.fillMaxSize().background(Color.White).padding(16.dp)) {
                VerifiedBadgeWithInfo(verifiedAt = null, small = small)
            }
        }
        val name = app.getString(R.string.verified_badge_info_title)
        val target = compose.onNode(hasContentDescription(name) and hasClickAction())
            .assertIsDisplayed().assertHeightIsAtLeast(48.dp).assertWidthIsAtLeast(48.dp)
        val area = bounds(target)
        val view = nativeView(target)
        val bitmap = compose.runOnIdle {
            Bitmap.createBitmap(view.width, view.height, Bitmap.Config.ARGB_8888).also { view.draw(Canvas(it)) }
        }
        try {
            val color = SevaInk500.toArgb()
            var left = Int.MAX_VALUE
            var top = Int.MAX_VALUE
            var right = Int.MIN_VALUE
            var bottom = Int.MIN_VALUE
            var pixels = 0
            val colors = mutableMapOf<Int, Int>()
            for (y in floor(area.top).toInt().coerceAtLeast(0) until ceil(area.bottom).toInt().coerceAtMost(bitmap.height)) {
                for (x in floor(area.left).toInt().coerceAtLeast(0) until ceil(area.right).toInt().coerceAtMost(bitmap.width)) {
                    val pixel = bitmap.getPixel(x, y)
                    colors[pixel] = (colors[pixel] ?: 0) + 1
                    if (hasTintInk(pixel, color)) {
                        left = minOf(left, x); right = maxOf(right, x)
                        top = minOf(top, y); bottom = maxOf(bottom, y); pixels++
                    }
                }
            }
            assertTrue("Actual info-vector ink exists: pixels=$pixels, target=$area, " +
                "expected=${color.toUInt().toString(16)}, colors=" +
                colors.entries.sortedByDescending { it.value }.take(12)
                    .joinToString { "${it.key.toUInt().toString(16)}:${it.value}" }, pixels >= 8)
            val glyph = Rect(left.toFloat(), top.toFloat(), right + 1f, bottom + 1f)
            val maximum = glyphDp * app.resources.displayMetrics.density + 1f
            assertTrue("Info glyph width stays <= ${glyphDp}dp, independent of 48dp target: $glyph",
                glyph.width <= maximum)
            assertTrue("Info glyph height stays <= ${glyphDp}dp, independent of 48dp target: $glyph",
                glyph.height <= maximum)
            assertContains("Painted glyph remains in target", area, glyph)
        } finally { bitmap.recycle() }
        // Positive control: the reserved area, outside the centered 12/14dp glyph, is clickable.
        target.performTouchInput { click(Offset(2f, center.y)) }
        compose.onNodeWithText(name).assertIsDisplayed()
    }

    @Test @Config(sdk = [32])
    fun `native Back keeps deleting sheet visible then permits dismissal after a failed request`() {
        val deleting = mutableStateOf(false)
        val shown = mutableStateOf(true)
        val passwordError = mutableStateOf<String?>(null)
        var dismissed = 0
        render {
            if (shown.value) DeleteAccountSheet(
                reason = "Synthetic account cleanup", password = "synthetic-password",
                passwordError = passwordError.value, deleting = deleting.value,
                onReasonChange = {}, onPasswordChange = {}, onConfirm = {},
                // Match the real VM: it rejects dismissal while the request is pending.
                // This catches a hidden-but-mounted modal, not only callback removal.
                onDismiss = { if (!deleting.value) { dismissed++; shown.value = false } },
            )
        }
        val titleText = app.getString(R.string.account_delete_title)
        // The destructive button may use the same words as the title.
        val title = compose.onNode(hasText(titleText) and !hasClickAction()).assertIsDisplayed()
        val dialog = requireNotNull(ShadowDialog.getLatestDialog())
        assertTrue(dialog.isShowing)
        assertNotSame(host.get().window.decorView, dialog.window!!.decorView)
        assertSame("Back owner is the modal, not the activity", dialog,
            nativeView(title).findViewTreeOnBackPressedDispatcherOwner())
        compose.runOnIdle { deleting.value = true }
        // The busy label has different wrapping at this width; compare the
        // same settled busy layout on either side of native Back.
        compose.waitForIdle()
        val busyBounds = bounds(title.assertIsDisplayed())
        nativeBack(dialog)
        title.assertIsDisplayed()
        assertEquals("Native Back must not start a hidden transition", busyBounds.top,
            bounds(title).top, 1f)
        compose.runOnIdle { assertEquals(0, dismissed); assertTrue(dialog.isShowing) }
        compose.runOnIdle { deleting.value = false; passwordError.value = "Incorrect password. Try again." }
        compose.onNodeWithText("Incorrect password. Try again.").assertIsDisplayed()
        assertSame("Failure recovers within the same visible modal", dialog, ShadowDialog.getLatestDialog())
        nativeBack(dialog)
        compose.runOnIdle { assertEquals(1, dismissed); assertFalse(dialog.isShowing) }
        title.assertDoesNotExist()
    }

    private fun nativeBack(dialog: Dialog) {
        compose.runOnIdle {
            val now = SystemClock.uptimeMillis()
            listOf(KeyEvent.ACTION_DOWN, KeyEvent.ACTION_UP).forEach { action ->
                dialog.dispatchKeyEvent(KeyEvent(now, now, action, KeyEvent.KEYCODE_BACK, 0))
            }
        }
        compose.mainClock.advanceTimeBy(800)
        compose.waitForIdle()
    }

    private fun render(scale: Float = 1f, content: @Composable () -> Unit) {
        RuntimeEnvironment.setFontScale(scale)
        host = Robolectric.buildActivity(ComponentActivity::class.java).setup().visible()
        host.get().setContent { EquipSevaTheme(darkTheme = false, content = content) }
        compose.waitForIdle()
    }

    private fun nativeView(node: SemanticsNodeInteraction): View =
        (node.fetchSemanticsNode().root as ViewRootForTest).view

    private fun bounds(node: SemanticsNodeInteraction): Rect {
        val b = node.getUnclippedBoundsInRoot()
        val density = app.resources.displayMetrics.density
        return Rect(b.left.value * density, b.top.value * density,
            b.right.value * density, b.bottom.value * density)
    }

    private fun assertContains(message: String, outer: Rect, inner: Rect) {
        assertTrue("$message: outer=$outer inner=$inner", inner.left >= outer.left - 1f &&
            inner.top >= outer.top - 1f && inner.right <= outer.right + 1f && inner.bottom <= outer.bottom + 1f)
    }

    /**
     * The fixture paints on white. Fractional vector strokes legitimately
     * blend their tint with that background: the 14 dp icon had 81 nonwhite
     * pixels but only three nearly opaque ones. Identify foreground-over-white
     * ink, retaining the same minimum ink and maximum painted-size assertions.
     */
    private fun hasTintInk(actual: Int, expected: Int): Boolean {
        val channels = listOf(0, 8, 16)
        val tintDelta = channels.map { 255f - ((expected ushr it) and 255) }
        val pixelDelta = channels.map { 255f - ((actual ushr it) and 255) }
        val magnitude = tintDelta.sumOf { (it * it).toDouble() }.toFloat()
        if (magnitude == 0f) return false
        val coverage = tintDelta.indices.sumOf {
            (tintDelta[it] * pixelDelta[it]).toDouble()
        }.toFloat() / magnitude
        if (coverage < 0.1f || coverage > 1.01f) return false
        return tintDelta.indices.all { abs(pixelDelta[it] - coverage * tintDelta[it]) <= 3f }
    }
}
