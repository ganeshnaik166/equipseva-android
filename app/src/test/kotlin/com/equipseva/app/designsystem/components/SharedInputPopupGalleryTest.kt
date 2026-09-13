package com.equipseva.app.designsystem.components

import android.app.Application
import android.graphics.Bitmap
import android.graphics.Canvas
import android.view.View
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.platform.ViewRootForTest
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.unit.dp
import androidx.core.graphics.ColorUtils
import androidx.test.core.app.ApplicationProvider
import com.equipseva.app.R
import com.equipseva.app.designsystem.theme.DarkEsColors
import com.equipseva.app.designsystem.theme.EquipSevaTheme
import com.equipseva.app.designsystem.theme.EsColors
import com.equipseva.app.designsystem.theme.EsTheme
import com.equipseva.app.designsystem.theme.LightEsColors
import com.equipseva.app.testing.IsolatedUiPackageParser
import com.equipseva.app.testing.IsolatedUiTestRunner
import java.io.File
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
import org.robolectric.android.controller.ActivityController
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/** Native popup-window specimens. No activity bitmap is used as popup evidence. */
@RunWith(IsolatedUiTestRunner::class)
@Config(application = Application::class, sdk = [34], shadows = [IsolatedUiPackageParser::class],
    qualifiers = "en-rUS-w320dp-h800dp-mdpi")
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@OptIn(ExperimentalTestApi::class)
class SharedInputPopupGalleryTest {
    @get:Rule val compose = createEmptyComposeRule()
    private lateinit var host: ActivityController<ComponentActivity>
    private var activityComposeView: View? = null
    private var activePopup: View? = null
    private lateinit var report: String
    private val app: Application get() = ApplicationProvider.getApplicationContext()

    private enum class Mode(val dark: Boolean) {
        Light(false), Dark(true), FixedLightInDark(true);
        val palette: EsColors get() = if (this == Dark) DarkEsColors else LightEsColors
    }

    @Before fun open() {
        IsolatedUiPackageParser.assertIsolated(app)
        host = Robolectric.buildActivity(ComponentActivity::class.java).setup().visible()
    }
    @After fun close() {
        activePopup?.dispatchWindowFocusChanged(false)
        host.get().window.decorView.dispatchWindowFocusChanged(true)
        host.pause().stop().destroy()
    }

    @Test fun `light popup paints options search cursor and disabled empty result`() = popupGallery(Mode.Light)
    @Test fun `dark popup paints options search cursor and disabled empty result`() = popupGallery(Mode.Dark)
    @Test fun `explicit light popup stays paired in a dark app`() = popupGallery(Mode.FixedLightInDark)

    private fun popupGallery(mode: Mode) {
        report = "popup-${mode.name}"
        output("$report-measurements.tsv").writeText("API34 native popup view; synthetic data; no device acceptance\n")
        val palette = mode.palette
        val options = (1..12).map { "District %02d".format(it) }
        val selected = mutableListOf<String>()
        host.get().setContent {
            activityComposeView = LocalView.current
            EquipSevaTheme(darkTheme = mode.dark) {
                Column(Modifier.fillMaxSize().background(EsTheme.colors.surface).padding(16.dp)) {
                    Column(Modifier.fillMaxWidth().background(palette.surface)) {
                        if (mode == Mode.FixedLightInDark) {
                            EsDropdown(null, { selected += it }, options, label = "Service district", palette = LightEsColors)
                        } else {
                            EsDropdown(null, { selected += it }, options, label = "Service district")
                        }
                    }
                }
            }
        }
        compose.onNode(SemanticsMatcher.expectValue(SemanticsProperties.Role, Role.DropdownList)).performClick()
        settle()
        val option = compose.onNodeWithText("District 01", useUnmergedTree = true).assertIsDisplayed()
        // Robolectric attaches popup windows without delivering their real activation event.
        // Cursor rendering observes window focus separately from the editable node's focus.
        val popupWindow = popupView(option).rootView
        activePopup = popupWindow
        compose.runOnIdle {
            host.get().window.decorView.dispatchWindowFocusChanged(false)
            popupWindow.dispatchWindowFocusChanged(true)
        }
        nativeText(option, "District 01", palette.text, palette.surface, "option")

        val searchLabel = app.getString(R.string.es_dropdown_search_placeholder)
        val label = compose.onNodeWithText(searchLabel, useUnmergedTree = true).assertIsDisplayed()
        nativeText(label, searchLabel, palette.muted, palette.surface, "search-label")
        val search = compose.onNode(hasSetTextAction())
        search.performClick().performTextInput("District")
        search.assertIsFocused()
        settle()
        focusedBoundary(search, palette)
        val cursor = cursorPixels(search, label, palette)
        nativeText(search, "District", palette.text, palette.surface, "search-value",
            exclusions = listOf(bounds(label), cursor))

        search.performTextClearance()
        search.performTextInput("missing synthetic district")
        settle()
        val empty = app.getString(R.string.es_dropdown_no_matches)
        compose.onNodeWithText(empty).assertIsDisplayed().assertIsNotEnabled()
        nativeText(compose.onNodeWithText(empty, useUnmergedTree = true), empty,
            palette.muted, palette.surface, "disabled-no-matches")
        compose.onNodeWithText("District 01", substring = false).assertDoesNotExist()
        compose.runOnIdle { assertTrue("Rendering and empty-result interaction never select an option", selected.isEmpty()) }
        // The search field has no error input in the production API. Error colors belong
        // to the host trigger/support and are covered by SharedInputGalleryTest.
    }

    private fun nativeText(node: SemanticsNodeInteraction, text: String, foreground: Color,
        background: Color, name: String, exclusions: List<Rect> = emptyList()) {
        node.assertIsDisplayed()
        val layouts = mutableListOf<TextLayoutResult>()
        node.performSemanticsAction(SemanticsActions.GetTextLayoutResult) { it(layouts) }
        val layout = layouts.single { it.layoutInput.text.text == text }
        val area = bounds(node)
        val bitmap = drawPopup(node)
        try {
            save(bitmap, name)
            assertTrue("Text remains inside its popup bitmap: $name", area.left >= -1f && area.top >= -1f &&
                area.right <= bitmap.width + 1f && area.bottom <= bitmap.height + 1f)
            assertFalse("Popup text cannot clip vertically: $name", layout.didOverflowHeight)
            assertEquals(text.length, layout.getLineEnd(layout.lineCount - 1, visibleEnd = true))
            repeat(layout.lineCount) { line ->
                assertFalse(layout.isLineEllipsized(line))
                assertTrue(layout.getLineLeft(line) >= -1f)
                assertTrue(layout.getLineRight(line) <= layout.size.width + 1f)
            }
            val colors = mutableMapOf<Int, Int>()
            var glyphPixels = 0
            var actualForeground = 0
            pixels(bitmap, area, exclusions) { _, _, color ->
                colors[color] = (colors[color] ?: 0) + 1
                if (near(color, foreground.toArgb())) { glyphPixels++; actualForeground = color }
            }
            val actualBackground = colors.maxBy { it.value }.key
            val contrast = if (glyphPixels == 0) 0.0 else ColorUtils.calculateContrast(actualForeground, actualBackground)
            measure("$name\ttext=$text\tbounds=$area\tlines=${layout.lineCount}\tglyphs=$glyphPixels\tforeground=${hex(actualForeground)}\tbackground=${hex(actualBackground)}\tcontrast=$contrast")
            assertTrue("Actual popup glyph ink: $name", glyphPixels >= 8)
            assertTrue("Popup uses the requested paired surface: $name", near(actualBackground, background.toArgb()))
            assertTrue("Native popup text contrast: $name", contrast >= 4.5)
        } finally { bitmap.recycle() }
    }

    private fun focusedBoundary(search: SemanticsNodeInteraction, p: EsColors) {
        val area = bounds(search)
        val bitmap = drawPopup(search)
        try {
            save(bitmap, "search-focused-border")
            val ink = mutableListOf<Pair<Int, Int>>()
            val colors = mutableMapOf<Int, Int>()
            pixels(bitmap, area) { x, y, color ->
                colors[color] = (colors[color] ?: 0) + 1
                if (near(color, p.focus.toArgb())) ink += x to y
            }
            assertTrue("Search focus paints a boundary, not just a glyph", ink.size >= 40)
            val painted = Rect(ink.minOf { it.first }.toFloat(), ink.minOf { it.second }.toFloat(),
                ink.maxOf { it.first } + 1f, ink.maxOf { it.second } + 1f)
            assertTrue("Focus ink spans the real search body", painted.width >= 80f && painted.height >= 40f)
            val actualBackground = colors.maxBy { it.value }.key
            val contrast = ColorUtils.calculateContrast(p.focus.toArgb(), actualBackground)
            measure("focus\tinput=$area\tpainted=$painted\tink=${ink.size}\tbackground=${hex(actualBackground)}\tcontrast=$contrast")
            assertTrue(near(actualBackground, p.surface.toArgb()))
            assertTrue("Actual search boundary contrast", contrast >= 3.0)
        } finally { bitmap.recycle() }
    }

    private fun cursorPixels(search: SemanticsNodeInteraction, label: SemanticsNodeInteraction, p: EsColors): Rect {
        val area = bounds(search)
        val labelArea = bounds(label)
        val previousAutoAdvance = compose.mainClock.autoAdvance
        val frames = mutableListOf<Bitmap>()
        compose.mainClock.autoAdvance = false
        try {
            // Finite samples cover one full caret blink cycle after label/focus animations
            // settle. Pixels must alternate between the real text role and actual surface;
            // static text/borders cannot supply this evidence.
            repeat(5) { index ->
                compose.mainClock.advanceTimeBy(250)
                compose.waitForIdle()
                frames += drawPopup(search).also { save(it, "cursor-frame-$index") }
            }
            assertTrue("Popup geometry remains stable while sampling the caret",
                frames.all { it.width == frames.first().width && it.height == frames.first().height })
            val alternating = mutableListOf<Pair<Int, Int>>()
            pixels(frames.first(), area, listOf(labelArea)) { x, y, _ ->
                val colors = frames.map { it.getPixel(x, y) }
                if (colors.any { near(it, p.text.toArgb()) } && colors.any { near(it, p.surface.toArgb()) }) {
                    alternating += x to y
                }
            }
            measure("cursor\tchangingPixels=${alternating.size}\tframes=${frames.size}\tinput=$area")
            assertTrue("Actual popup caret alternates with its paired background", alternating.size >= 8)
            val cursor = Rect(alternating.minOf { it.first }.toFloat(), alternating.minOf { it.second }.toFloat(),
                alternating.maxOf { it.first } + 1f, alternating.maxOf { it.second } + 1f)
            measure("cursor-shape\tbounds=$cursor\tforeground=${hex(p.text.toArgb())}\tbackground=${hex(p.surface.toArgb())}")
            assertTrue("Caret is a narrow vertical mark, not changing text/layout", cursor.width <= 4f && cursor.height >= 8f)
            assertTrue(cursor.left >= area.left && cursor.right <= area.right && cursor.top >= area.top && cursor.bottom <= area.bottom)
            return cursor
        } finally {
            frames.forEach { it.recycle() }
            compose.mainClock.autoAdvance = previousAutoAdvance
        }
    }

    private fun popupView(node: SemanticsNodeInteraction): View {
        val popup = (node.fetchSemanticsNode().root as ViewRootForTest).view
        assertNotSame("Evidence view is not the activity Compose view", activityComposeView, popup)
        assertNotSame("Evidence comes from the popup window", host.get().window.decorView, popup.rootView)
        measure("capture-root\tcompose=${popup.javaClass.name}\twindow=${popup.rootView.javaClass.name}\twidth=${popup.width}\theight=${popup.height}")
        return popup
    }
    private fun drawPopup(node: SemanticsNodeInteraction): Bitmap {
        val popup = popupView(node)
        return compose.runOnIdle {
            check(popup.width > 0 && popup.height > 0)
            Bitmap.createBitmap(popup.width, popup.height, Bitmap.Config.ARGB_8888).also { popup.draw(Canvas(it)) }
        }
    }
    private fun settle() { compose.mainClock.advanceTimeBy(300); compose.waitForIdle() }
    private fun bounds(node: SemanticsNodeInteraction) = node.fetchSemanticsNode().boundsInRoot
    private fun near(actual: Int, expected: Int) = listOf(16, 8, 0).all { shift ->
        abs(((actual shr shift) and 255) - ((expected shr shift) and 255)) <= 2
    }
    private fun pixels(bitmap: Bitmap, area: Rect, exclusions: List<Rect> = emptyList(), action: (Int, Int, Int) -> Unit) {
        for (y in floor(area.top).toInt().coerceAtLeast(0) until ceil(area.bottom).toInt().coerceAtMost(bitmap.height)) {
            for (x in floor(area.left).toInt().coerceAtLeast(0) until ceil(area.right).toInt().coerceAtMost(bitmap.width)) {
                if (exclusions.none { x + 0.5f >= it.left && x + 0.5f < it.right && y + 0.5f >= it.top && y + 0.5f < it.bottom }) {
                    action(x, y, bitmap.getPixel(x, y))
                }
            }
        }
    }
    private fun save(bitmap: Bitmap, name: String) {
        output("$report-$name.png").outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
    }
    private fun measure(line: String) { output("$report-measurements.tsv").appendText(line + "\n") }
    private fun hex(color: Int) = "%08x".format(color)
    private fun output(name: String) = File("build/reports/ui-inputs-gallery/$name").also { it.parentFile!!.mkdirs() }
}
