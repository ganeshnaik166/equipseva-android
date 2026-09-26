package com.equipseva.app.features.home

import android.app.Application
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.view.View
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ColorScheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.assertHeightIsAtLeast
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertWidthIsAtLeast
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.hasClickAction
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performSemanticsAction
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.dp
import androidx.core.graphics.ColorUtils
import androidx.test.core.app.ApplicationProvider
import com.equipseva.app.R
import com.equipseva.app.designsystem.theme.EquipSevaTheme
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.Spacing
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/** Isolated native Compose content; no Hilt application, accounts or network. */
@RunWith(RobolectricTestRunner::class)
@Config(application = Application::class, sdk = [34], qualifiers = "en-rUS-w360dp-h800dp-mdpi")
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class HospitalHomeActionsTest {
    @get:Rule val compose = createComposeRule()
    private var renderedView: View? = null
    private val context: Context get() = ApplicationProvider.getApplicationContext()
    private val actionIds = listOf(
        R.string.home_actions_request_service,
        R.string.home_actions_my_bookings,
        R.string.home_actions_browse_engineers,
    )

    private fun render(
        width: Int = 360,
        fontScale: Float = 1f,
        dark: Boolean = false,
        onRequest: () -> Unit = {},
        onBookings: () -> Unit = {},
        onBrowse: () -> Unit = {},
        onColors: (ColorScheme) -> Unit = {},
    ) {
        compose.setContent {
            renderedView = LocalView.current
            EquipSevaTheme(darkTheme = dark) {
                val density = LocalDensity.current
                CompositionLocalProvider(LocalDensity provides Density(density.density, fontScale)) {
                    onColors(MaterialTheme.colorScheme)
                    Column(
                        Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background),
                    ) {
                        Column(
                            Modifier.width(width.dp).verticalScroll(rememberScrollState()).padding(Spacing.lg),
                        ) {
                            HospitalHomeActions(onRequest, onBookings, onBrowse)
                        }
                    }
                }
            }
        }
    }

    @Test fun `three distinct actions deliver only their own callback`() {
        val calls = mutableListOf<String>()
        render(
            onRequest = { calls += "request" },
            onBookings = { calls += "bookings" },
            onBrowse = { calls += "directory" },
        )
        val buttonRole = SemanticsMatcher.expectValue(SemanticsProperties.Role, Role.Button)
        compose.onAllNodes(hasClickAction()).assertCountEquals(3)
        actionIds.forEachIndexed { index, id ->
            compose.onAllNodesWithText(context.getString(id)).assertCountEquals(1)
            compose.onNodeWithText(context.getString(id)).assert(buttonRole).assertIsEnabled().performClick()
            assertEquals(listOf("request", "bookings", "directory").take(index + 1), calls)
        }
        compose.onNodeWithText(context.getString(R.string.home_actions_title))
            .assert(SemanticsMatcher.keyIsDefined(SemanticsProperties.Heading))
    }

    @Test fun `English normal layout has reachable separated targets`() {
        render()
        compose.onNodeWithText(context.getString(R.string.home_actions_request_service)).assertIsDisplayed()
        capture("en-360-1x-top")
        assertLayout(360)
        capture("en-360-1x-bottom")
    }

    @Test
    @Config(qualifiers = "en-rUS-w320dp-h800dp-mdpi")
    fun `English narrow large text wraps without truncating actions`() {
        render(width = 320, fontScale = 2f)
        capture("en-320-2x-top")
        assertLayout(320)
        capture("en-320-2x-bottom")
    }

    @Test fun `English medium text has untruncated controls`() {
        render(fontScale = 1.3f)
        capture("en-360-1point3x-top")
        assertLayout(360)
        capture("en-360-1point3x-bottom")
    }

    @Test fun `English full width large text has untruncated controls`() {
        render(fontScale = 2f)
        capture("en-360-2x-top")
        assertLayout(360)
        capture("en-360-2x-bottom")
    }

    @Test
    @Config(qualifiers = "en-rUS-w320dp-h800dp-mdpi")
    fun `English narrow normal text has untruncated controls`() {
        render(width = 320)
        capture("en-320-1x-top")
        assertLayout(320)
        capture("en-320-1x-bottom")
    }

    @Test
    @Config(qualifiers = "en-rUS-w320dp-h800dp-mdpi")
    fun `English narrow medium text has untruncated controls`() {
        render(width = 320, fontScale = 1.3f)
        capture("en-320-1point3x-top")
        assertLayout(320)
        capture("en-320-1point3x-bottom")
    }

    @Test
    @Config(qualifiers = "en-rUS-w640dp-h360dp-land-mdpi")
    fun `compact landscape large text keeps every action scroll reachable`() {
        render(width = 640, fontScale = 2f)
        capture("en-640x360-2x-top")
        assertLayout(640)
        capture("en-640x360-2x-bottom")
    }

    @Test
    @Config(qualifiers = "hi-rIN-w320dp-h800dp-mdpi")
    fun `Hindi narrow large text uses localized resources and wraps`() {
        render(width = 320, fontScale = 2f)
        assertEquals("सेवा का अनुरोध करें", context.getString(R.string.home_actions_request_service))
        capture("hi-320-2x-top")
        assertLayout(320)
        capture("hi-320-2x-bottom")
    }

    @Test
    @Config(qualifiers = "te-rIN-w320dp-h800dp-mdpi")
    fun `Telugu narrow large text uses localized resources and wraps`() {
        render(width = 320, fontScale = 2f)
        assertEquals("సేవను అభ్యర్థించండి", context.getString(R.string.home_actions_request_service))
        capture("te-320-2x-top")
        assertLayout(320)
        capture("te-320-2x-bottom")
    }

    @Test fun `existing dark theme keeps text and action contrast`() {
        var colors: ColorScheme? = null
        render(dark = true, onColors = { colors = it })
        capture("en-360-dark-1x-top")
        assertLayout(360)
        assertContrast(checkNotNull(colors))
        capture("en-360-dark-1x")
    }

    @Test fun `existing light theme keeps text and action contrast`() {
        var colors: ColorScheme? = null
        render(onColors = { colors = it })
        compose.waitForIdle()
        assertContrast(checkNotNull(colors))
    }

    private fun assertContrast(colors: ColorScheme) {
        listOf(
            colors.onSurface to colors.surface,
            colors.onSurfaceVariant to colors.surface,
            Color.White to SevaGreen700,
        ).forEach { (foreground, background) ->
            val ratio = ColorUtils.calculateContrast(foreground.toArgb(), background.toArgb())
            assertTrue("Text contrast $ratio must be >= 4.5", ratio >= 4.5)
        }
    }

    private fun assertLayout(width: Int) {
        compose.waitForIdle()
        val bounds = actionIds.map { id ->
            compose.onNodeWithText(context.getString(id))
                .assertHeightIsAtLeast(Spacing.MinTouchTarget)
                .assertWidthIsAtLeast(Spacing.MinTouchTarget)
                .getUnclippedBoundsInRoot()
        }
        bounds.forEach {
            assertTrue("left target edge", it.left >= 0.dp)
            assertTrue("right target edge", it.right <= width.dp)
        }
        bounds.zipWithNext().forEach { (first, second) ->
            assertTrue("targets must not overlap", first.bottom <= second.top)
        }
        val textIds = actionIds + listOf(
            R.string.home_actions_title,
            R.string.home_actions_body,
            R.string.home_actions_hospital_workspace,
        )
        textIds.forEach { id ->
            val layouts = mutableListOf<TextLayoutResult>()
            compose.onNodeWithText(context.getString(id), useUnmergedTree = true)
                .performSemanticsAction(SemanticsActions.GetTextLayoutResult) { it(layouts) }
            assertTrue("rendered text layout for $id", layouts.isNotEmpty())
            layouts.forEach {
                val description = "${context.resources.getResourceEntryName(id)}: size=${it.size}, " +
                    "paragraph=${it.multiParagraph.width}x${it.multiParagraph.height}, " +
                    "constraints=${it.layoutInput.constraints}, lines=${it.lineCount}, " +
                    "widthOverflow=${it.didOverflowWidth}, heightOverflow=${it.didOverflowHeight}"
                println("HOME_TEXT_LAYOUT $description")
                // The paragraph width retains the maximum layout constraint even
                // when the node measures to a shorter intrinsic width. Therefore
                // didOverflowWidth is not a clipping oracle for these Text nodes.
                assertFalse("Vertical text clipping: $description", it.didOverflowHeight)
                assertTrue("Text width exceeds its constraint: $description",
                    it.size.width <= it.layoutInput.constraints.maxWidth)
                assertTrue("Text height exceeds its constraint: $description",
                    it.size.height <= it.layoutInput.constraints.maxHeight)
                assertTrue("Text must render at least one line: $description", it.lineCount > 0)
                repeat(it.lineCount) { line ->
                    assertFalse("Ellipsized line $line: $description", it.isLineEllipsized(line))
                    assertTrue("Line left edge $line: $description", it.getLineLeft(line) >= -1f)
                    assertTrue("Line right edge $line: $description",
                        it.getLineRight(line) <= it.multiParagraph.width + 1f)
                }
                assertEquals("All visible text must be laid out: $description",
                    it.layoutInput.text.text.trimEnd().length,
                    it.getLineEnd(it.lineCount - 1, visibleEnd = true))
            }
        }
        actionIds.forEach { id ->
            compose.onNodeWithText(context.getString(id)).performScrollTo().assertIsDisplayed()
        }
    }

    private fun capture(name: String) {
        compose.waitForIdle()
        // Robolectric has no hardware window frame-commit callback for PixelCopy.
        // Draw the actual Compose host through Android's native Canvas instead;
        // this is simulated View rendering, not a device/window screenshot.
        val bitmap = compose.runOnIdle {
            val view = checkNotNull(renderedView)
            check(view.width > 0 && view.height > 0)
            Bitmap.createBitmap(view.width, view.height, Bitmap.Config.ARGB_8888).also {
                view.draw(Canvas(it))
            }
        }
        val output = File("build/outputs/hospital-home-actions/$name.png")
        val parent = checkNotNull(output.parentFile)
        check(parent.mkdirs() || parent.isDirectory)
        output.outputStream().use { stream ->
            check(bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream))
        }
        bitmap.recycle()
    }
}
