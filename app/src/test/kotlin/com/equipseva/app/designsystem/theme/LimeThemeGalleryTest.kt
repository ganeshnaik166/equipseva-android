package com.equipseva.app.designsystem.theme

import android.app.Application
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Typeface
import android.os.Build
import android.os.LocaleList
import android.view.View
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.*
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontSynthesis
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.dp
import androidx.core.graphics.ColorUtils
import androidx.test.core.app.ApplicationProvider
import com.equipseva.app.testing.IsolatedUiPackageParser
import com.equipseva.app.testing.IsolatedUiTestRunner
import java.io.File
import java.util.Locale
import kotlin.math.abs
import kotlin.math.roundToInt
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

/** Synthetic, offline production-theme specimens. Native Robolectric is not a physical-device gate. */
@RunWith(IsolatedUiTestRunner::class)
@Config(application = Application::class, sdk = [34], shadows = [IsolatedUiPackageParser::class],
    qualifiers = "en-rUS-w360dp-h800dp-mdpi")
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@OptIn(ExperimentalTestApi::class)
class LimeThemeGalleryTest {
    @get:Rule val compose = createEmptyComposeRule()
    private lateinit var host: ActivityController<ComponentActivity>
    private var view: View? = null
    private val app: Application get() = ApplicationProvider.getApplicationContext()

    @Before fun open() {
        IsolatedUiPackageParser.assertIsolated(app)
        host = Robolectric.buildActivity(ComponentActivity::class.java).setup().visible()
    }
    @After fun close() { host.pause().stop().destroy() }

    @Test fun `light roles render with readable paired content`() = pairedRoles(false)
    @Test fun `dark roles render with readable paired content`() = pairedRoles(true)
    @Test fun `light Material foreground consumers remain readable`() = materialControls(false)
    @Test fun `dark Material foreground consumers remain readable`() = materialControls(true)

    @Test @Config(qualifiers = "en-rUS-w320dp-h800dp-mdpi")
    fun `English two times text fits narrow light gallery`() = scriptSpecimen(false)
    @Test @Config(qualifiers = "en-rUS-w320dp-h800dp-mdpi")
    fun `English two times text fits narrow dark gallery`() = scriptSpecimen(true)
    @Test @Config(qualifiers = "hi-rIN-w320dp-h800dp-mdpi")
    fun `Hindi two times text fits narrow light gallery`() = scriptSpecimen(false)
    @Test @Config(qualifiers = "hi-rIN-w320dp-h800dp-mdpi")
    fun `Hindi two times text fits narrow dark gallery`() = scriptSpecimen(true)
    @Test @Config(qualifiers = "te-rIN-w320dp-h800dp-mdpi")
    fun `Telugu two times text fits narrow light gallery`() = scriptSpecimen(false)
    @Test @Config(qualifiers = "te-rIN-w320dp-h800dp-mdpi")
    fun `Telugu two times text fits narrow dark gallery`() = scriptSpecimen(true)

    @Test @Config(sdk = [26], qualifiers = "en-rUS-w320dp-h800dp-mdpi")
    fun `API26 English font resources resolve and mixed script renders`() = scriptSpecimen(false)
    @Test @Config(sdk = [26], qualifiers = "hi-rIN-w320dp-h800dp-mdpi")
    fun `API26 Hindi font resources resolve and mixed script renders`() = scriptSpecimen(false)
    @Test @Config(sdk = [26], qualifiers = "te-rIN-w320dp-h800dp-mdpi")
    fun `API26 Telugu font resources resolve and mixed script renders`() = scriptSpecimen(false)

    @Test @Config(qualifiers = "en-rUS-w640dp-h320dp-land-mdpi")
    fun `English typography remains reachable on short landscape`() = scriptSpecimen(false)
    @Test @Config(qualifiers = "hi-rIN-w640dp-h320dp-land-mdpi")
    fun `Hindi typography remains reachable on short landscape`() = scriptSpecimen(true)
    @Test @Config(qualifiers = "te-rIN-w640dp-h320dp-land-mdpi")
    fun `Telugu typography remains reachable on short landscape`() = scriptSpecimen(true)

    @Test fun `locale and theme changes update same composition without losing remembered state`() {
        val configuration = mutableStateOf(Configuration(app.resources.configuration))
        val dark = mutableStateOf(false)
        var bodyFamily: androidx.compose.ui.text.font.FontFamily? = null
        var pageFamily: androidx.compose.ui.text.font.FontFamily? = null
        host.get().setContent {
            CompositionLocalProvider(LocalConfiguration provides configuration.value) {
                EquipSevaTheme(darkTheme = dark.value) {
                    var clicks by remember { mutableIntStateOf(0) }
                    bodyFamily = EsFontFamily
                    pageFamily = EsType.H2.fontFamily
                    Button(onClick = { clicks++ }) { Text("Remembered $clicks") }
                }
            }
        }
        compose.onNodeWithText("Remembered 0").performClick()
        listOf("hi", "te", "en", "fr").forEach { language ->
            compose.runOnIdle {
                configuration.value = Configuration(configuration.value).apply {
                    setLocales(LocaleList(Locale.forLanguageTag(language)))
                }
                dark.value = !dark.value
            }
            compose.onNodeWithText("Remembered 1").assertIsDisplayed()
            compose.runOnIdle {
                val expectedBody = when (language) { "hi" -> Devanagari; "te" -> Telugu; else -> Inter }
                val expectedPage = if (language in listOf("hi", "te")) expectedBody else SpaceGrotesk
                assertEquals(expectedBody, bodyFamily)
                assertEquals(expectedPage, pageFamily)
            }
        }
    }

    private fun pairedRoles(dark: Boolean) {
        val labels = listOf("Page text", "Supporting text", "Lime action", "Disabled action",
            "Error state", "Pending state", "Success state", "Information state", "Inverse text", "Inverse support",
            "Legacy light error")
        render(dark) {
            val p = EsTheme.colors
            sample(labels[0], p.text, p.surface)
            sample(labels[1], p.muted, p.surface)
            listOf(p.action, p.disabled, p.error, p.pending, p.success, p.info, p.inverse).forEachIndexed { i, pair ->
                sample(labels[i + 2], pair.content, pair.container)
            }
            sample(labels[9], p.inverseMuted, p.inverse.container)
            sample(labels[10], LightEsColors.error.content, Surface50)
            // Focus/boundary math includes the role's actual parent and inverse-local variants.
            listOf(p.outline to p.canvas, p.focus to p.surface,
                p.inverseOutline to p.inverse.container, p.inverseFocus to p.inverse.container).forEach { (fg, bg) ->
                assertTrue(ColorUtils.calculateContrast(fg.toArgb(), bg.toArgb()) >= 3.0)
            }
        }
        labels.forEach { assertText(it, "pairs-$dark", contrast = true) }
    }

    private fun materialControls(dark: Boolean) {
        render(dark) {
            val c = MaterialTheme.colorScheme
            Button(onClick = {}) { Text("Filled button") }
            OutlinedButton(onClick = {}) { Text("Outlined button") }
            TextButton(onClick = {}) { Text("Text button") }
            Row {
                RadioButton(selected = true, onClick = {}, modifier = Modifier.testTag("radio"))
                Checkbox(checked = true, onCheckedChange = {}, modifier = Modifier.testTag("check"))
                Switch(checked = true, onCheckedChange = {}, modifier = Modifier.testTag("switch"))
                Icon(Icons.Default.Check, "Primary icon", tint = c.primary, modifier = Modifier.size(24.dp).testTag("icon"))
            }
            CircularProgressIndicator(progress = { 0.65f }, modifier = Modifier.testTag("progress"))
            InputChip(selected = true, onClick = {}, label = { Text("Selected chip") })
            Surface(color = c.primaryContainer.copy(alpha = 0.30f)) {
                Text("Selected role", color = c.onSurface, modifier = Modifier.padding(16.dp))
            }
            OutlinedTextField(value = "Service 012345", onValueChange = {}, label = { Text("Equipment") },
                isError = true, supportingText = { Text("Check the equipment name") }, modifier = Modifier.testTag("field"))
            Surface(color = Surface50) {
                Column {
                    OutlinedTextField(value = "123", onValueChange = {}, isError = true,
                        label = { Text("Legacy phone") }, supportingText = { Text("Check this phone number") },
                        colors = legacyLightFieldColors())
                    OutlinedTextField(value = "Hospital name", onValueChange = {},
                        label = { Text("Legacy name") }, colors = legacyLightFieldColors(),
                        modifier = Modifier.testTag("legacy-field"))
                    OutlinedTextField(value = "Saving name", onValueChange = {}, enabled = false,
                        label = { Text("Legacy disabled name") }, colors = legacyLightFieldColors())
                    TextButton(onClick = {}) { Text("Legacy retry", color = LightEsColors.text) }
                    CircularProgressIndicator(progress = { 0.5f }, color = LightEsColors.text,
                        modifier = Modifier.testTag("legacy-progress"))
                }
            }
        }
        listOf("Filled button", "Outlined button", "Text button", "Selected chip", "Selected role",
            "Equipment", "Check the equipment name", "Legacy phone", "Check this phone number",
            "Hospital name", "Legacy name", "Saving name", "Legacy disabled name", "Legacy retry").forEach {
            assertText(it, "material-$dark", contrast = true)
        }
        listOf("radio", "check", "switch", "icon", "progress").forEach { tag ->
            val node = compose.onNodeWithTag(tag).performScrollTo().assertIsDisplayed()
            val bitmap = draw()
            try {
                val histogram = pixels(bitmap, node.fetchSemanticsNode().boundsInRoot)
                val bg = (if (dark) DarkEsColors else LightEsColors).surface.toArgb()
                assertTrue("Visible Material $tag foreground", histogram.filterKeys {
                    ColorUtils.calculateContrast(it, bg) >= 3.0
                }.values.sum() >= 8)
            } finally { bitmap.recycle() }
        }
        compose.onNodeWithTag("field").performScrollTo().performClick()
        save(draw(), "material-$dark-focused")
        compose.onNodeWithTag("legacy-field").performScrollTo().performClick()
        save(draw(), "legacy-field-$dark-focused")
    }

    private fun scriptSpecimen(dark: Boolean) {
        val language = app.resources.configuration.locales[0].language
        val native = when (language) {
            "hi" -> "हर विवरण भरोसेमंद हाथों में — सेवा अनुरोध"
            "te" -> "ప్రతి వివరమూ నమ్మకమైన చేతుల్లో — సేవా అభ్యర్థన"
            else -> "Every detail in good hands — service requests"
        }
        val mixed = "Ganesh गणेश గణేశ్ · क्षि క్షి · ₹0123456789"
        val labels = listOf(native, "400 · $mixed", "500 · $mixed", "600 · $mixed")
        render(dark, 2f) {
            val t = MaterialTheme.typography
            val resolver = LocalFontFamilyResolver.current
            val expectedPrefix = when (language) { "hi" -> "noto_sans_devanagari"; "te" -> "noto_sans_telugu"; else -> "inter" }
            listOf(FontWeight.Normal, FontWeight.Medium, FontWeight.SemiBold).forEachIndexed { index, weight ->
                val resolved = resolver.resolve(EsFontFamily, weight, fontSynthesis = FontSynthesis.None).value as Typeface
                val suffix = listOf("regular", "medium", "semibold")[index]
                val id = app.resources.getIdentifier("${expectedPrefix}_$suffix", "font", app.packageName)
                val resource = app.resources.getFont(id)
                // Typeface.equals compares native handles, not font contents. Compose may wrap
                // the resource with an explicit weight. Compare native advances to the real asset,
                // and retain the independent resolved-weight assertion below.
                val probe = "$native $mixed AV Hamburgefonts MWii"
                fun advances(face: Typeface): FloatArray = FloatArray(probe.length).also { widths ->
                    android.graphics.Paint().apply { typeface = face; textSize = 48f }.getTextWidths(probe, widths)
                }
                val expected = advances(resource)
                val actual = advances(resolved)
                assertArrayEquals("Resolved glyph advances must match bundled font $id", expected, actual, 0.01f)
                assertFalse("Probe must distinguish bundled font from platform default",
                    advances(Typeface.DEFAULT).contentEquals(actual))
                if (Build.VERSION.SDK_INT >= 28) assertEquals(weight.weight, resolved.weight)
            }
            sample(labels[0], EsTheme.colors.text, EsTheme.colors.surface, t.headlineLarge)
            listOf(FontWeight.Normal, FontWeight.Medium, FontWeight.SemiBold).forEachIndexed { index, weight ->
                sample(labels[index + 1], EsTheme.colors.text, EsTheme.colors.surface, t.bodyLarge.copy(fontWeight = weight))
            }
        }
        val name = "api${Build.VERSION.SDK_INT}-$language-${app.resources.configuration.screenWidthDp}-2x-$dark"
        save(draw(), "$name-top")
        labels.forEach { assertText(it, name, contrast = true) }
    }

    @Composable private fun sample(text: String, fg: Color, bg: Color, style: TextStyle = MaterialTheme.typography.bodyLarge) {
        Surface(color = bg, modifier = Modifier.fillMaxWidth(), shape = MaterialTheme.shapes.large) {
            Text(text, color = fg, style = style, modifier = Modifier.padding(16.dp))
        }
    }

    private fun render(dark: Boolean, scale: Float = 1f, content: @Composable () -> Unit) {
        host.get().setContent {
            view = LocalView.current
            EquipSevaTheme(darkTheme = dark) {
                val density = LocalDensity.current
                CompositionLocalProvider(LocalDensity provides Density(density.density, scale)) {
                    Column(Modifier.fillMaxSize().background(EsTheme.colors.surface)
                        .verticalScroll(rememberScrollState()).padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        content()
                    }
                }
            }
        }
        compose.waitForIdle()
    }

    private fun assertText(label: String, name: String, contrast: Boolean) {
        val node = compose.onNodeWithText(label, useUnmergedTree = true).performScrollTo().assertIsDisplayed()
        val layouts = mutableListOf<TextLayoutResult>()
        node.performSemanticsAction(SemanticsActions.GetTextLayoutResult) { it(layouts) }
        val layout = layouts.single()
        assertFalse("Vertical clipping: $label", layout.didOverflowHeight)
        assertEquals(label.length, layout.getLineEnd(layout.lineCount - 1, visibleEnd = true))
        repeat(layout.lineCount) { line ->
            assertFalse("Ellipsis: $label", layout.isLineEllipsized(line))
            assertTrue("Left line edge: $label", layout.getLineLeft(line) >= -1f)
            assertTrue("Right line edge: $label", layout.getLineRight(line) <= layout.size.width + 1f)
        }
        val bitmap = draw()
        try {
            if (contrast) {
                val histogram = pixels(bitmap, node.fetchSemanticsNode().boundsInRoot)
                val bg = histogram.maxBy { it.value }.key
                val fg = ColorUtils.compositeColors(layout.layoutInput.style.color.toArgb(), bg)
                val glyphs = histogram.filterKeys { pixel -> listOf(16, 8, 0).all { shift ->
                    abs(((pixel shr shift) and 255) - ((fg shr shift) and 255)) <= 2
                } }
                assertTrue("Actual glyph pixels: $label", glyphs.values.sum() >= 5)
                val ratio = ColorUtils.calculateContrast(glyphs.maxBy { it.value }.key, bg)
                output("$name-measurements.txt").appendText("$label: ratio=$ratio lines=${layout.lineCount} size=${layout.size}\n")
                assertTrue("Rendered text contrast $ratio: $label", ratio >= 4.5)
            }
            output("$name-${label.hashCode()}.png").outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
        } finally { bitmap.recycle() }
    }

    private fun pixels(bitmap: Bitmap, bounds: androidx.compose.ui.geometry.Rect): Map<Int, Int> {
        val histogram = mutableMapOf<Int, Int>()
        for (y in bounds.top.roundToInt().coerceAtLeast(0) until bounds.bottom.roundToInt().coerceAtMost(bitmap.height)) {
            for (x in bounds.left.roundToInt().coerceAtLeast(0) until bounds.right.roundToInt().coerceAtMost(bitmap.width)) {
                val color = bitmap.getPixel(x, y)
                histogram[color] = (histogram[color] ?: 0) + 1
            }
        }
        return histogram
    }
    private fun draw(): Bitmap = compose.runOnIdle {
        val hostView = checkNotNull(view)
        Bitmap.createBitmap(hostView.width, hostView.height, Bitmap.Config.ARGB_8888).also { hostView.draw(Canvas(it)) }
    }
    private fun save(bitmap: Bitmap, name: String) {
        try { output("$name.png").outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) } }
        finally { bitmap.recycle() }
    }
    private fun output(name: String) = File("build/outputs/ui-foundation/$name").also { it.parentFile!!.mkdirs() }
}
