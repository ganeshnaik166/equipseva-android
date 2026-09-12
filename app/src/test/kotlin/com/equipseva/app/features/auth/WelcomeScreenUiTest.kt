package com.equipseva.app.features.auth

import android.app.Application
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.view.View
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
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
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.onRoot
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
import com.equipseva.app.testing.IsolatedUiPackageParser
import com.equipseva.app.testing.IsolatedUiTestRunner
import java.io.File
import kotlin.math.abs
import kotlin.math.roundToInt
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.android.controller.ActivityController
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * Actual Welcome content in a manifest-free synthetic host. No auth repositories,
 * accounts, browser, providers or network are used. Native-Canvas captures are
 * simulated render evidence, not device, TalkBack or native-speaker acceptance.
 */
@RunWith(IsolatedUiTestRunner::class)
@OptIn(androidx.compose.ui.test.ExperimentalTestApi::class)
@Config(application = Application::class, sdk = [34], shadows = [IsolatedUiPackageParser::class],
    qualifiers = "en-rUS-w360dp-h800dp-mdpi")
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class WelcomeScreenUiTest {
    @get:Rule val compose = createEmptyComposeRule()
    private lateinit var controller: ActivityController<ComponentActivity>
    private var renderedView: View? = null
    private val context: Context get() = ApplicationProvider.getApplicationContext()
    private val buttonRole = SemanticsMatcher.expectValue(SemanticsProperties.Role, Role.Button)

    @Before fun startIsolatedHost() {
        IsolatedUiPackageParser.assertIsolated(ApplicationProvider.getApplicationContext())
        controller = Robolectric.buildActivity(ComponentActivity::class.java).setup().visible()
    }

    @After fun closeHost() {
        if (::controller.isInitialized) controller.pause().stop().destroy()
    }

    @Test fun `four independently named buttons invoke only their own callback once`() {
        val calls = mutableListOf<String>()
        render(calls = calls)
        compose.onAllNodes(hasClickAction()).assertCountEquals(4)
        actions().forEachIndexed { index, label ->
            compose.onNodeWithText(label).performScrollTo().assert(buttonRole)
                .assertIsEnabled().assertIsDisplayed().performClick()
            compose.runOnIdle {
                assertEquals(listOf("sign-in", "sign-up", "terms", "privacy").take(index + 1), calls)
            }
        }
    }

    @Test fun `public screen keeps existing sign in and create account destinations`() {
        val calls = mutableListOf<String>()
        renderContent {
            WelcomeScreen(onSignIn = { calls += "sign-in" }, onSignUp = { calls += "sign-up" })
        }
        actions().take(2).forEach { compose.onNodeWithText(it).performScrollTo().performClick() }
        compose.runOnIdle { assertEquals(listOf("sign-in", "sign-up"), calls) }
    }

    @Test fun `brand is a heading and role explanations are informative without role selection`() {
        render()
        compose.onNodeWithText(context.getString(R.string.app_name))
            .assert(SemanticsMatcher.keyIsDefined(SemanticsProperties.Heading))
        compose.onAllNodes(SemanticsMatcher.keyIsDefined(SemanticsProperties.ContentDescription))
            .assertCountEquals(0)
        compose.onAllNodes(SemanticsMatcher.expectValue(SemanticsProperties.Role, Role.RadioButton))
            .assertCountEquals(0)
        listOf("For hospitals", "For engineers").forEach { label ->
            compose.onNodeWithText(label).performScrollTo().assertIsDisplayed()
                .assert(SemanticsMatcher.keyNotDefined(SemanticsActions.OnClick))
        }
        compose.onAllNodes(hasClickAction()).assertCountEquals(4)
        assertTrue("brand, value, both descriptions and legal copy are present", visibleTexts().size >= 11)
    }

    @Test @Config(qualifiers = "en-rUS-w320dp-h800dp-mdpi")
    fun `English 320dp at double text scale keeps every word and action reachable`() =
        assertLargeText("en", 320)

    @Test @Config(qualifiers = "hi-rIN-w320dp-h800dp-mdpi")
    fun `Hindi 320dp at double text scale keeps every word and action reachable`() =
        assertLargeText("hi", 320)

    @Test @Config(qualifiers = "te-rIN-w320dp-h800dp-mdpi")
    fun `Telugu 320dp at double text scale keeps every word and action reachable`() =
        assertLargeText("te", 320)

    @Test @Config(qualifiers = "en-rUS-w640dp-h320dp-land-mdpi")
    fun `English short landscape keeps every word and action reachable`() =
        assertLargeText("en", 640)

    @Test @Config(qualifiers = "hi-rIN-w640dp-h320dp-land-mdpi")
    fun `Hindi short landscape keeps every word and action reachable`() =
        assertLargeText("hi", 640)

    @Test @Config(qualifiers = "te-rIN-w640dp-h320dp-land-mdpi")
    fun `Telugu short landscape keeps every word and action reachable`() =
        assertLargeText("te", 640)

    @Test fun `light theme renders all text with explicit readable color pairs`() = assertRenderedContrast(false)

    @Test fun `dark theme renders all text with explicit readable color pairs`() = assertRenderedContrast(true)

    private fun assertLargeText(locale: String, width: Int) {
        val calls = mutableListOf<String>()
        render(fontScale = 2f, calls = calls)
        capture("$locale-$width-2x-initial-viewport")
        val texts = visibleTexts()
        assertTrue("all expected content exists", texts.size >= 11)
        if (locale != "en") {
            val alphabet = if (locale == "hi") Regex("[\\u0900-\\u097f]") else Regex("[\\u0c00-\\u0c7f]")
            texts.filter { it != context.getString(R.string.app_name) }.forEach {
                assertTrue("localized copy must not fall back to English: $it", alphabet.containsMatchIn(it))
            }
        }
        texts.forEach { label ->
            val text = compose.onNodeWithText(label, useUnmergedTree = true)
            text.performScrollTo().assertIsDisplayed()
            val layout = layoutOf(label)
            output("layout-$locale-$width.txt").appendText(
                "text=$label size=${layout.size} constraints=${layout.layoutInput.constraints} " +
                    "paragraphWidth=${layout.multiParagraph.width} intrinsicWidth=${layout.multiParagraph.intrinsics.maxIntrinsicWidth} " +
                    "overflowWidth=${layout.didOverflowWidth} bounds=${text.fetchSemanticsNode().boundsInRoot} " +
                    "lines=${(0 until layout.lineCount).map { line -> layout.getLineLeft(line) to layout.getLineRight(line) }}\n",
            )
            assertFalse("vertical clipping: $label", layout.didOverflowHeight)
            // The paragraph can retain its wider allocation even when the
            // measured text shrinks to its intrinsic width. Check real line
            // edges against the measured box, not didOverflowWidth's aggregate.
            assertTrue("text fits width: $label", layout.size.width <= layout.layoutInput.constraints.maxWidth)
            assertTrue("text fits height: $label", layout.size.height <= layout.layoutInput.constraints.maxHeight)
            val textBounds = text.fetchSemanticsNode().boundsInRoot
            val rootBounds = compose.onRoot().fetchSemanticsNode().boundsInRoot
            assertTrue("full text width is visible: $label", textBounds.width >= layout.size.width - 1f)
            assertTrue("text stays in viewport horizontally: $label",
                textBounds.left >= rootBounds.left && textBounds.right <= rootBounds.right)
            assertTrue("there are lines: $label", layout.lineCount > 0)
            repeat(layout.lineCount) { line ->
                assertFalse("ellipsis: $label", layout.isLineEllipsized(line))
                assertTrue("line left edge: $label", layout.getLineLeft(line) >= -1f)
                assertTrue("line right edge: $label", layout.getLineRight(line) <= layout.size.width + 1f)
            }
            assertEquals("all characters are laid out: $label", label.trimEnd().length,
                layout.getLineEnd(layout.lineCount - 1, visibleEnd = true))
        }
        actions(locale).forEachIndexed { index, label ->
            val target = compose.onNodeWithText(label).performScrollTo().assertIsDisplayed()
                .assertIsEnabled().assert(buttonRole).assertHeightIsAtLeast(48.dp).assertWidthIsAtLeast(48.dp)
            val bounds = target.getUnclippedBoundsInRoot()
            val viewport = compose.onRoot().getUnclippedBoundsInRoot()
            assertTrue("complete target inside viewport: $label",
                bounds.left >= viewport.left && bounds.right <= viewport.right &&
                    bounds.top >= viewport.top && bounds.bottom <= viewport.bottom)
            assertTrue("target respects configured width", bounds.left >= 0.dp && bounds.right <= width.dp)
            if (index < 2) {
                target.assertHeightIsAtLeast(52.dp)
                val textBounds = compose.onNodeWithText(label, useUnmergedTree = true).getUnclippedBoundsInRoot()
                assertTrue("primary text has at least 12dp breathing room above and below",
                    bounds.bottom - bounds.top >= textBounds.bottom - textBounds.top + 24.dp)
            }
            target.performClick()
            compose.runOnIdle {
                assertEquals(listOf("sign-in", "sign-up", "terms", "privacy").take(index + 1), calls)
            }
        }
        val allBounds = actions(locale).map { compose.onNodeWithText(it).getUnclippedBoundsInRoot() }
        allBounds.zipWithNext().forEach { (first, second) ->
            assertTrue("separate action hit targets must not overlap", first.bottom <= second.top)
        }
        capture("$locale-$width-2x-actions-viewport")
    }

    private fun assertRenderedContrast(darkTheme: Boolean) {
        render(darkTheme = darkTheme)
        val themeName = if (darkTheme) "dark" else "light"
        capture("$themeName-top")
        visibleTexts().forEachIndexed { index, label ->
            val text = compose.onNodeWithText(label, useUnmergedTree = true).performScrollTo().assertIsDisplayed()
            val bounds = text.fetchSemanticsNode().boundsInRoot
            val foreground = layoutOf(label).layoutInput.style.color
            assertTrue("explicit text foreground: $label", foreground != Color.Unspecified)
            val bitmap = drawHost()
            try {
                // Real rendered pixels: the most common color within the text
                // rectangle is its opaque surface, not a duplicated theme token.
                val histogram = mutableMapOf<Int, Int>()
                val left = bounds.left.roundToInt().coerceAtLeast(0)
                val right = bounds.right.roundToInt().coerceAtMost(bitmap.width)
                val top = bounds.top.roundToInt().coerceAtLeast(0)
                val bottom = bounds.bottom.roundToInt().coerceAtMost(bitmap.height)
                for (y in top until bottom) for (x in left until right) {
                    val pixel = bitmap.getPixel(x, y)
                    histogram[pixel] = (histogram[pixel] ?: 0) + 1
                }
                val background = checkNotNull(histogram.maxByOrNull { it.value }).key
                assertEquals("opaque rendered surface: $label", 255, android.graphics.Color.alpha(background))
                val expectedGlyph = ColorUtils.compositeColors(foreground.toArgb(), background)
                val glyphs = histogram.filterKeys { pixel ->
                    listOf(16, 8, 0).all { shift ->
                        abs(((pixel shr shift) and 255) - ((expectedGlyph shr shift) and 255)) <= 2
                    }
                }
                assertTrue("actual foreground glyph pixels: $label", glyphs.values.sum() >= 5)
                val glyph = checkNotNull(glyphs.maxByOrNull { it.value }).key
                val contrast = ColorUtils.calculateContrast(glyph, background)
                output("contrast-$themeName.txt").appendText(
                    "$index foreground=${glyph.toUInt().toString(16)} background=${background.toUInt().toString(16)} ratio=$contrast text=$label\n",
                )
                assertTrue("text contrast >= 4.5:1: $label was $contrast", contrast >= 4.5)
                saveBitmap(bitmap, "$themeName-text-$index")
            } finally {
                bitmap.recycle()
            }
        }
    }

    private fun render(fontScale: Float = 1f, darkTheme: Boolean = false, calls: MutableList<String> = mutableListOf()) =
        renderContent(fontScale, darkTheme) {
            WelcomeContent(
                onSignIn = { calls += "sign-in" }, onSignUp = { calls += "sign-up" },
                onTerms = { calls += "terms" }, onPrivacy = { calls += "privacy" },
            )
        }

    private fun renderContent(fontScale: Float = 1f, darkTheme: Boolean = false, content: @Composable () -> Unit) {
        controller.get().setContent {
            renderedView = LocalView.current
            EquipSevaTheme(darkTheme = darkTheme) {
                val density = LocalDensity.current
                CompositionLocalProvider(LocalDensity provides Density(density.density, fontScale)) { content() }
            }
        }
        compose.waitForIdle()
    }

    private fun visibleTexts(): List<String> = compose.onAllNodes(
        SemanticsMatcher.keyIsDefined(SemanticsProperties.Text), useUnmergedTree = true,
    ).fetchSemanticsNodes().map { node -> node.config[SemanticsProperties.Text].joinToString("") { it.text } }

    private fun layoutOf(label: String): TextLayoutResult {
        val layouts = mutableListOf<TextLayoutResult>()
        compose.onNodeWithText(label, useUnmergedTree = true)
            .performSemanticsAction(SemanticsActions.GetTextLayoutResult) { it(layouts) }
        return layouts.single()
    }

    private fun actions(locale: String = "en") = when (locale) {
        "hi" -> listOf("साइन इन करें", "खाता बनाएं", "सेवा की शर्तें", "गोपनीयता नीति")
        "te" -> listOf("సైన్ ఇన్ చేయండి", "ఖాతా సృష్టించండి", "సేవా నిబంధనలు", "గోప్యతా విధానం")
        else -> listOf("Sign in", "Create account", "Terms of service", "Privacy policy")
    }

    private fun capture(name: String) {
        val bitmap = drawHost()
        try { saveBitmap(bitmap, name) } finally { bitmap.recycle() }
    }

    private fun drawHost(): Bitmap {
        compose.waitForIdle()
        return compose.runOnIdle {
            val view = checkNotNull(renderedView)
            check(view.width > 0 && view.height > 0)
            Bitmap.createBitmap(view.width, view.height, Bitmap.Config.ARGB_8888).also { view.draw(Canvas(it)) }
        }
    }

    private fun output(name: String): File = File("build/outputs/welcome-ui/$name").also {
        val parent = checkNotNull(it.parentFile)
        check(parent.mkdirs() || parent.isDirectory)
    }

    private fun saveBitmap(bitmap: Bitmap, name: String) {
        output("$name.png").outputStream().use { check(bitmap.compress(Bitmap.CompressFormat.PNG, 100, it)) }
    }
}
