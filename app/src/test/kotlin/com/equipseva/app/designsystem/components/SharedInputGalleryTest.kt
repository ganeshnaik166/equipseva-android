package com.equipseva.app.designsystem.components

import android.app.Application
import android.graphics.Bitmap
import android.graphics.Canvas
import android.view.View
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.material3.Icon
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.graphics.compositeOver
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.text.TextRange
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.dp
import androidx.core.graphics.ColorUtils
import androidx.test.core.app.ApplicationProvider
import com.equipseva.app.R
import com.equipseva.app.designsystem.theme.DarkEsColors
import com.equipseva.app.designsystem.theme.EquipSevaTheme
import com.equipseva.app.designsystem.theme.EsColors
import com.equipseva.app.designsystem.theme.EsTheme
import com.equipseva.app.designsystem.theme.EsType
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

/** Offline native input specimens. Activity PNGs do not claim popup-window or device coverage. */
@RunWith(IsolatedUiTestRunner::class)
@Config(application = Application::class, sdk = [34], shadows = [IsolatedUiPackageParser::class],
    qualifiers = "en-rUS-w320dp-h800dp-mdpi")
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@OptIn(ExperimentalTestApi::class)
class SharedInputGalleryTest {
    @get:Rule val compose = createEmptyComposeRule()
    private lateinit var host: ActivityController<ComponentActivity>
    private var view: View? = null
    private var pixelsPerDp = 1f
    private lateinit var report: String
    private val app: Application get() = ApplicationProvider.getApplicationContext()

    private enum class Mode(val dark: Boolean) {
        Light(false), Dark(true), FixedLightInDark(true);
        val expected: EsColors get() = if (this == Dark) DarkEsColors else LightEsColors
    }

    @Before fun open() {
        IsolatedUiPackageParser.assertIsolated(app)
        host = Robolectric.buildActivity(ComponentActivity::class.java).setup().visible()
    }
    @After fun close() { host.pause().stop().destroy() }

    @Test fun `light inputs paint paired glyphs boundaries and focus`() = paletteGallery(Mode.Light)
    @Test fun `dark inputs paint paired glyphs boundaries and focus`() = paletteGallery(Mode.Dark)
    @Test fun `explicit light inputs remain paired inside a dark parent`() = paletteGallery(Mode.FixedLightInDark)
    @Test fun `light placeholder icons and selection paint readable roles`() = decorations(Mode.Light)
    @Test fun `dark placeholder icons and selection paint readable roles`() = decorations(Mode.Dark)
    @Test fun `fixed light placeholder icons and selection stay paired in dark app`() = decorations(Mode.FixedLightInDark)

    @Test fun `English long inputs fit at two times text size in light`() = largeText(Mode.Light)
    @Test fun `English long inputs fit at two times text size in dark`() = largeText(Mode.Dark)
    @Test fun `English long fixed light inputs fit inside dark parent`() = largeText(Mode.FixedLightInDark)
    @Test @Config(qualifiers = "hi-rIN-w320dp-h800dp-mdpi")
    fun `Hindi long inputs fit at two times text size in light`() = largeText(Mode.Light)
    @Test @Config(qualifiers = "hi-rIN-w320dp-h800dp-mdpi")
    fun `Hindi long inputs fit at two times text size in dark`() = largeText(Mode.Dark)
    @Test @Config(qualifiers = "hi-rIN-w320dp-h800dp-mdpi")
    fun `Hindi long fixed light inputs fit inside dark parent`() = largeText(Mode.FixedLightInDark)
    @Test @Config(qualifiers = "te-rIN-w320dp-h800dp-mdpi")
    fun `Telugu long inputs fit at two times text size in light`() = largeText(Mode.Light)
    @Test @Config(qualifiers = "te-rIN-w320dp-h800dp-mdpi")
    fun `Telugu long inputs fit at two times text size in dark`() = largeText(Mode.Dark)
    @Test @Config(qualifiers = "te-rIN-w320dp-h800dp-mdpi")
    fun `Telugu long fixed light inputs fit inside dark parent`() = largeText(Mode.FixedLightInDark)

    @Test fun `English weighted payout input and save fit at two times text size`() = floorEditor()
    @Test @Config(qualifiers = "hi-rIN-w320dp-h800dp-mdpi")
    fun `Hindi weighted payout input and save fit at two times text size`() = floorEditor()
    @Test @Config(qualifiers = "te-rIN-w320dp-h800dp-mdpi")
    fun `Telugu weighted payout input and save fit at two times text size`() = floorEditor()

    private fun paletteGallery(mode: Mode) {
        begin("palette-${mode.name}")
        val p = mode.expected
        render(mode) { explicit ->
            Field("normal", "Service 012345", "Equipment", hint = "Enter equipment reference", palette = explicit)
            Field("error", "Check serial", "Serial number", error = "Enter a valid serial number", palette = explicit)
            Field("disabled", "Saving details", "Saved reference", hint = "Please wait", enabled = false, palette = explicit)
            Picker("picker", "Hyderabad district", "Service district", hint = "Choose the service area", palette = explicit)
            Picker("picker-error", null, "Required district", error = "Select an available district", palette = explicit)
            Picker("picker-disabled", "Saved district", "Locked district", hint = "Saved during update", enabled = false, palette = explicit)
        }

        show("normal")
        textInk("Service 012345", p.text, p.surface, "normal-value", "normal", listOf("Equipment", "Enter equipment reference"))
        textInk("Equipment", p.muted, p.surface, "normal-label", "normal")
        textInk("Enter equipment reference", p.muted, p.surface, "normal-hint", "normal")
        val unfocused = stroke(field("normal"), p.outline, p.surface, "normal-outline")
        bodyHeight("normal", p.outline)

        show("error")
        textInk("Check serial", p.text, p.surface, "error-value", "error", listOf("Serial number", "Enter a valid serial number"))
        textInk("Serial number", p.error.content, p.surface, "error-label", "error")
        textInk("Enter a valid serial number", p.error.content, p.surface, "error-support", "error")
        stroke(field("error"), p.error.content, p.surface, "error-outline")

        show("disabled")
        field("disabled").assertIsNotEnabled()
        textInk("Saving details", p.disabled.content, p.disabled.container, "disabled-value", "disabled",
            listOf("Saved reference", "Please wait"))
        // Supporting text lies outside the outlined container on the parent surface.
        textInk("Please wait", p.disabled.content, p.surface, "disabled-support", "disabled")
        stroke(field("disabled"), p.outline, p.disabled.container, "disabled-outline")

        show("picker")
        dropdownLabel("picker", "Service district", p.muted)
        textInk("Hyderabad district", p.text, p.surface, "picker-value", "picker")
        textInk("Choose the service area", p.muted, p.surface, "picker-hint", "picker")
        stroke(trigger("picker"), p.outline, p.surface, "picker-outline")
        arrow("picker", "Hyderabad district", p.muted)

        show("picker-error")
        dropdownLabel("picker-error", "Required district", p.muted)
        textInk("Choose district", p.muted, p.surface, "picker-placeholder", "picker-error")
        textInk("Select an available district", p.error.content, p.surface, "picker-error-support", "picker-error")
        stroke(trigger("picker-error"), p.error.content, p.surface, "picker-error-outline")

        show("picker-disabled")
        trigger("picker-disabled").assertIsNotEnabled()
        dropdownLabel("picker-disabled", "Locked district", p.disabled.content)
        textInk("Saved district", p.disabled.content, p.disabled.container, "picker-disabled-value", "picker-disabled")
        textInk("Saved during update", p.disabled.content, p.surface, "picker-disabled-support", "picker-disabled")
        stroke(trigger("picker-disabled"), p.outline, p.disabled.container, "picker-disabled-outline")

        show("normal")
        field("normal").performSemanticsAction(SemanticsActions.RequestFocus) { assertTrue(it()) }
        field("normal").assertIsFocused()
        settle()
        val focused = stroke(field("normal"), p.focus, p.surface, "focused-outline")
        assertNotEquals("Focus changes the actual painted boundary", unfocused, focused)
    }

    private data class ScriptCopy(val label: String, val error: String, val value: String,
        val pickerLabel: String, val district: String, val hint: String)

    private fun decorations(mode: Mode) {
        begin("decorations-${mode.name}")
        val p = mode.expected
        var value by mutableStateOf("")
        var enabled by mutableStateOf(true)
        var error by mutableStateOf<String?>(null)
        render(mode) { explicit ->
            EsField(value, { value = it }, label = "Reference", placeholder = "Serial number",
                enabled = enabled, error = error, palette = explicit ?: EsTheme.colors,
                modifier = Modifier.testTag("decorated"),
                leading = { Icon(Icons.Default.Check, null, Modifier.testTag("leading-icon")) },
                trailing = { Icon(Icons.Default.Close, null, Modifier.testTag("trailing-icon")) })
        }
        show("decorated")
        textInk("Serial number", p.muted, p.surface, "placeholder", "decorated")
        fun icons(foreground: Color, background: Color, state: String) {
            val bitmap = draw()
            try {
                save(bitmap, "$state-icons")
                listOf("leading-icon", "trailing-icon").forEach { tag ->
                    val area = bounds(compose.onNodeWithTag(tag, useUnmergedTree = true))
                    contained(area, bounds(field("decorated")), "Icon stays within input")
                    val ink = matching(bitmap, area, foreground)
                    val actualBg = histogram(bitmap, area, emptyList()).maxBy { it.value }.key
                    assertTrue("Actual $state $tag glyph", ink.size >= 8)
                    assertTrue("Paired $state icon fill", near(actualBg, background.toArgb()))
                    val ratio = ColorUtils.calculateContrast(ink.first().color, actualBg)
                    assertTrue("$state icon contrast", ratio >= 3.0)
                    measure("$state-$tag\tink=${ink.size}\tcontrast=$ratio")
                }
            } finally { bitmap.recycle() }
        }
        icons(p.muted, p.surface, "normal")
        field("decorated").performClick().performTextInput("Serial 012345")
        field("decorated").performTextInputSelection(TextRange(0, 6))
        settle()
        val bitmap = draw()
        try {
            save(bitmap, "selected-text")
            val selection = p.action.container.copy(alpha = 0.30f).compositeOver(p.surface)
            val highlight = matching(bitmap, bounds(field("decorated")), selection)
            assertTrue("Actual native selection background is painted", highlight.size >= 40)
            val selectedArea = Rect(highlight.minOf { it.x }.toFloat(), highlight.minOf { it.y }.toFloat(),
                highlight.maxOf { it.x } + 1f, highlight.maxOf { it.y } + 1f)
            val selectedInk = matching(bitmap, selectedArea, p.text)
            assertTrue("Selected text remains painted inside highlight", selectedInk.size >= 8)
            val ratio = ColorUtils.calculateContrast(selectedInk.first().color, highlight.first().color)
            assertTrue("Actual selected text contrast", ratio >= 4.5)
            measure("selection\tbounds=$selectedArea\thighlight=${highlight.size}\tglyphs=${selectedInk.size}\tcontrast=$ratio")
        } finally { bitmap.recycle() }
        field("decorated").performTextInputSelection(TextRange(value.length))
        compose.runOnIdle { error = "Enter a complete reference" }
        settle()
        icons(p.error.content, p.surface, "error")
        compose.runOnIdle { enabled = false; error = null }
        settle()
        icons(p.disabled.content, p.disabled.container, "disabled")
    }

    private fun floorEditor() {
        val language = app.resources.configuration.locales[0].language
        begin("floor-$language-320dp-2x")
        val label = app.getString(R.string.es_input_minimum_payout_label)
        val saveLabel = app.getString(R.string.job_profitability_floor_save)
        var value by mutableStateOf("1250")
        var saved: Double? = null
        render(Mode.FixedLightInDark, scale = 2f) {
            // Same screen/card insets, weighted field, unweighted Save and 8dp gap
            // as FloorEditor. This exercises the persistent input label in its narrow row.
            Column(Modifier.fillMaxWidth().background(Color.White).padding(16.dp)) {
                Text(stringResource(R.string.job_profitability_floor_editor_title), style = EsType.Body,
                    color = LightEsColors.text)
                Spacer(Modifier.height(8.dp))
                Row(Modifier.fillMaxWidth().testTag("floor-row"), verticalAlignment = Alignment.Bottom,
                    horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    EsField(value, { value = it.filter(Char::isDigit) }, label = label, type = EsFieldType.Number,
                        palette = LightEsColors, modifier = Modifier.weight(1f).testTag("floor-input"))
                    EsBtn(saveLabel, { value.toDoubleOrNull()?.let { saved = it } }, kind = EsBtnKind.Secondary,
                        modifier = Modifier.testTag("floor-save"))
                }
            }
        }
        show("floor-row")
        val row = bounds(compose.onNodeWithTag("floor-row"))
        val input = bounds(compose.onNodeWithTag("floor-input"))
        val action = compose.onNodeWithTag("floor-save").assertIsDisplayed()
        val button = bounds(action)
        contained(input, row, "Weighted payout field stays inside row")
        contained(button, row, "Save action stays inside row")
        assertTrue("Weighted input and Save cannot overlap", input.right <= button.left)
        textInk(label, LightEsColors.muted, LightEsColors.surface, "floor-label", "floor-input")
        textInk(value, LightEsColors.text, LightEsColors.surface, "floor-value", "floor-input", listOf(label))
        action.performClick()
        compose.runOnIdle { assertEquals(1250.0, checkNotNull(saved), 0.0) }
        measure("floor-row\trow=$row\tinput=$input\tsave=$button\tsaved=$saved")
    }

    private fun largeText(mode: Mode) {
        val language = app.resources.configuration.locales[0].language
        val copy = when (language) {
            "hi" -> ScriptCopy("उपकरण सेवा अनुरोध का पूरा विवरण", "आगे बढ़ने से पहले उपकरण की खराबी का विवरण भरें",
                "मॉनिटर की सेवा\nकमरा 12 · ₹1250\nबिजली की केबल जाँची", "इंजीनियर का सेवा जिला चुनें",
                "हैदराबाद · उपकरण सेवा और रखरखाव", "अपने काम के लिए सही सेवा क्षेत्र चुनें")
            "te" -> ScriptCopy("పరికరాల సేవా అభ్యర్థన వివరాలు", "కొనసాగించే ముందు పరికరాల సమస్యను వివరించండి",
                "మానిటర్ సేవ\nగది 12 · ₹1250\nవిద్యుత్ కేబుల్ తనిఖీ", "ఇంజినీర్ సేవా జిల్లాను ఎంచుకోండి",
                "హైదరాబాద్ · పరికరాల సేవ మరియు నిర్వహణ", "మీ పని కోసం సరైన సేవా ప్రాంతాన్ని ఎంచుకోండి")
            else -> ScriptCopy("Equipment service request details", "Describe the fault and equipment before continuing",
                "Monitor service\nRoom 12 · ₹1250\nPower cable checked", "Choose the engineer service district",
                "Hyderabad · equipment service and maintenance", "Choose the correct service area for your work")
        }
        begin("large-$language-${mode.name}-320dp-2x")
        val p = mode.expected
        render(mode, scale = 2f) { explicit ->
            Field("large-field", copy.value, copy.label, error = copy.error, multiline = true, palette = explicit)
            Picker("large-picker", copy.district, copy.pickerLabel, hint = copy.hint, palette = explicit)
        }
        show("large-field")
        textInk(copy.label, p.error.content, p.surface, "label", "large-field")
        val valueLayout = textInk(copy.value, p.text, p.surface, "multiline", "large-field", listOf(copy.label, copy.error))
        assertTrue("All three explicit lines survive layout", valueLayout.lineCount >= 3)
        textInk(copy.error, p.error.content, p.surface, "error", "large-field")
        show("large-picker")
        dropdownLabel("large-picker", copy.pickerLabel, p.muted)
        val selection = textInk(copy.district, p.text, p.surface, "selection", "large-picker")
        assertTrue("Long selection wraps instead of displacing its arrow", selection.lineCount >= 2)
        textInk(copy.hint, p.muted, p.surface, "hint", "large-picker")
        arrow("large-picker", copy.district, p.muted)
    }

    @Composable private fun Field(tag: String, value: String, label: String, hint: String? = null,
        error: String? = null, enabled: Boolean = true, multiline: Boolean = false, palette: EsColors?) {
        val type = if (multiline) EsFieldType.Multiline else EsFieldType.Text
        if (palette == null) {
            EsField(value, {}, modifier = Modifier.testTag(tag), label = label, hint = hint, error = error,
                enabled = enabled, type = type)
        } else {
            EsField(value, {}, modifier = Modifier.testTag(tag), label = label, hint = hint, error = error,
                enabled = enabled, type = type, palette = palette)
        }
    }

    @Composable private fun Picker(tag: String, value: String?, label: String, hint: String? = null,
        error: String? = null, enabled: Boolean = true, palette: EsColors?) {
        val options = listOfNotNull(value, "Alternative district")
        if (palette == null) {
            EsDropdown(value, {}, options, modifier = Modifier.testTag(tag), label = label, placeholder = "Choose district",
                hint = hint, error = error, enabled = enabled)
        } else {
            EsDropdown(value, {}, options, modifier = Modifier.testTag(tag), label = label, placeholder = "Choose district",
                hint = hint, error = error, enabled = enabled, palette = palette)
        }
    }

    private fun render(mode: Mode, scale: Float = 1f, content: @Composable (EsColors?) -> Unit) {
        host.get().setContent {
            view = LocalView.current
            EquipSevaTheme(darkTheme = mode.dark) {
                val density = LocalDensity.current
                pixelsPerDp = density.density
                CompositionLocalProvider(LocalDensity provides Density(density.density, scale)) {
                    Column(Modifier.fillMaxSize().background(EsTheme.colors.surface)
                        .verticalScroll(rememberScrollState()).padding(16.dp)) {
                        // The dark parent stays visible outside the explicit light specimen.
                        Column(Modifier.fillMaxWidth().background(mode.expected.surface),
                            verticalArrangement = Arrangement.spacedBy(24.dp)) {
                            content(if (mode == Mode.FixedLightInDark) LightEsColors else null)
                        }
                    }
                }
            }
        }
        settle()
    }

    private fun inside(tag: String) = hasTestTag(tag) or hasAnyAncestor(hasTestTag(tag))
    private fun field(tag: String) = compose.onNode(
        SemanticsMatcher.keyIsDefined(SemanticsProperties.EditableText) and inside(tag))
    private fun trigger(tag: String) = compose.onNode(
        SemanticsMatcher.expectValue(SemanticsProperties.Role, Role.DropdownList) and inside(tag))
    private fun show(tag: String) {
        val node = compose.onNodeWithTag(tag).performScrollTo().assertIsDisplayed()
        settle()
        val area = bounds(node)
        val viewport = bounds(compose.onRoot())
        val bitmap = draw()
        try { save(bitmap, "$tag-visible") } finally { bitmap.recycle() }
        measure("$tag-layout\tcomponent=$area\tviewport=$viewport")
        contained(area, viewport, "$tag stays wholly in the viewport")
    }
    private fun settle() { compose.mainClock.advanceTimeBy(300); compose.waitForIdle() }

    private fun textInk(text: String, foreground: Color, background: Color, name: String, owner: String,
        exclude: List<String> = emptyList()): TextLayoutResult {
        val node = compose.onNodeWithText(text, useUnmergedTree = true).assertIsDisplayed()
        val layouts = mutableListOf<TextLayoutResult>()
        node.performSemanticsAction(SemanticsActions.GetTextLayoutResult) { it(layouts) }
        val layout = layouts.single { it.layoutInput.text.text == text }
        val area = bounds(node)
        contained(area, bounds(compose.onNodeWithTag(owner)), "$name remains within its component")
        contained(area, bounds(compose.onRoot()), "$name remains within the viewport")
        assertFalse("No vertical text clipping: $name", layout.didOverflowHeight)
        assertEquals("Complete final line: $name", text.length, layout.getLineEnd(layout.lineCount - 1, visibleEnd = true))
        repeat(layout.lineCount) { line ->
            assertFalse("No ellipsis: $name", layout.isLineEllipsized(line))
            assertTrue("Left glyph layout edge: $name", layout.getLineLeft(line) >= -1f)
            assertTrue("Right glyph layout edge: $name", layout.getLineRight(line) <= layout.size.width + 1f)
        }
        // Editable semantics can span its decoration. Exclude label/support so they cannot
        // substitute for missing value glyphs, especially when disabled roles share a color.
        val exclusions = exclude.map { bounds(compose.onNodeWithText(it, useUnmergedTree = true)) }
        val bitmap = draw()
        try {
            save(bitmap, name)
            val histogram = histogram(bitmap, area, exclusions)
            val ink = matching(bitmap, area, foreground, exclusions)
            val actualBg = histogram.maxBy { it.value }.key
            val actualInk = ink.firstOrNull()?.color ?: 0
            val ratio = if (ink.isEmpty()) 0.0 else ColorUtils.calculateContrast(actualInk, actualBg)
            measure("$name\tlines=${layout.lineCount}\tbounds=$area\tink=${ink.size}\tbackground=${hex(actualBg)}\tforeground=${hex(actualInk)}\tcontrast=$ratio")
            assertTrue("Actual value/label glyph pixels: $name", ink.size >= 8)
            assertTrue("Actual paired fill: $name", near(actualBg, background.toArgb()))
            assertTrue("Rendered text contrast: $name ($ratio)", ratio >= 4.5)
            val span = ink.maxOf { it.y } - ink.minOf { it.y } + 1
            val baselineSpan = layout.getLineBaseline(layout.lineCount - 1) - layout.getLineBaseline(0)
            assertTrue("Ink reaches every laid-out line: $name", span >= baselineSpan + 2f)
        } finally { bitmap.recycle() }
        return layout
    }

    private fun dropdownLabel(tag: String, label: String, foreground: Color) {
        val control = trigger(tag).assert(hasContentDescription(label))
        val outer = bounds(compose.onNodeWithTag(tag))
        val target = bounds(control)
        val labelArea = Rect(outer.left, outer.top, outer.right, target.top)
        val bitmap = draw()
        try {
            save(bitmap, "$tag-visible-label")
            val ink = matching(bitmap, labelArea, foreground)
            measure("$tag-label\taccessibleName=$label\tregion=$labelArea\tink=${ink.size}")
            assertTrue("Semantics-cleared visible dropdown label is painted: $tag", ink.size >= 8)
            assertTrue("Label ink ends before the trigger: $tag", ink.maxOf { it.y } < target.top)
        } finally { bitmap.recycle() }
    }

    private fun arrow(tag: String, value: String, foreground: Color) {
        val target = bounds(trigger(tag))
        val selectedText = bounds(compose.onNodeWithText(value, useUnmergedTree = true))
        contained(selectedText, target, "$tag selection stays inside trigger")
        val bitmap = draw()
        try {
            save(bitmap, "$tag-arrow")
            // Only the arrow uses the muted role in this horizontal band. Scan the full
            // viewport width so a painted arrow escaping the trigger also fails containment.
            val ink = matching(bitmap, Rect(0f, target.top, bitmap.width.toFloat(), target.bottom), foreground)
            assertTrue("Actual dropdown arrow remains painted: $tag", ink.size >= 8)
            val arrow = Rect(ink.minOf { it.x }.toFloat(), ink.minOf { it.y }.toFloat(),
                ink.maxOf { it.x } + 1f, ink.maxOf { it.y } + 1f)
            measure("$tag-arrow\ttrigger=$target\ttext=$selectedText\tarrow=$arrow\tink=${ink.size}")
            contained(arrow, target, "$tag arrow stays inside trigger")
            assertTrue("Arrow cannot overlap or replace selected text: $tag", arrow.left >= selectedText.right - 1f)
        } finally { bitmap.recycle() }
    }

    private fun stroke(node: SemanticsNodeInteraction, foreground: Color, background: Color, name: String): Int {
        val area = bounds(node)
        val band = Rect(area.left, area.top + area.height * 0.30f, area.left + 4f * pixelsPerDp,
            area.top + area.height * 0.60f)
        val bitmap = draw()
        try {
            save(bitmap, name)
            val ink = matching(bitmap, band, foreground)
            assertTrue("Painted vertical border segment: $name", ink.size >= 5)
            val actual = ink.first().color
            val ratio = ColorUtils.calculateContrast(actual, background.toArgb())
            measure("$name\tband=$band\tink=${ink.size}\tcolor=${hex(actual)}\tcontrast=$ratio")
            assertTrue("Boundary contrast: $name", ratio >= 3.0)
            return actual
        } finally { bitmap.recycle() }
    }

    private fun bodyHeight(tag: String, outline: Color) {
        val bitmap = draw()
        try {
            val ink = matching(bitmap, bounds(field(tag)), outline)
            assertTrue("Native outline is visible for body measurement", ink.isNotEmpty())
            val top = ink.minOf { it.y }
            val bottom = ink.maxOf { it.y } + 1
            val physicalHeight = bottom - top
            measure("$tag-body\toutlineTop=$top\toutlineBottom=$bottom\tbodyPixels=$physicalHeight\tminimumPixels=${56f * pixelsPerDp}")
            // One physical pixel accounts for edge antialiasing. Supporting-text geometry
            // does not contribute: the measured outline belongs to the input body alone.
            assertTrue("56dp input body excludes native supporting text", physicalHeight + 1f >= 56f * pixelsPerDp)
        } finally { bitmap.recycle() }
    }

    private fun bounds(node: SemanticsNodeInteraction): Rect = node.getUnclippedBoundsInRoot().let {
        Rect(it.left.value * pixelsPerDp, it.top.value * pixelsPerDp,
            it.right.value * pixelsPerDp, it.bottom.value * pixelsPerDp)
    }
    private fun contained(inner: Rect, outer: Rect, message: String) {
        assertTrue("$message: inner=$inner outer=$outer", inner.left >= outer.left - 1f && inner.top >= outer.top - 1f &&
            inner.right <= outer.right + 1f && inner.bottom <= outer.bottom + 1f)
    }
    private data class InkPixel(val x: Int, val y: Int, val color: Int)
    private fun near(actual: Int, expected: Int) = listOf(16, 8, 0).all { shift ->
        abs(((actual shr shift) and 255) - ((expected shr shift) and 255)) <= 2
    }
    private fun visit(bitmap: Bitmap, area: Rect, exclusions: List<Rect>, action: (Int, Int, Int) -> Unit) {
        for (y in floor(area.top).toInt().coerceAtLeast(0) until ceil(area.bottom).toInt().coerceAtMost(bitmap.height)) {
            for (x in floor(area.left).toInt().coerceAtLeast(0) until ceil(area.right).toInt().coerceAtMost(bitmap.width)) {
                if (exclusions.none { x + 0.5f >= it.left && x + 0.5f < it.right && y + 0.5f >= it.top && y + 0.5f < it.bottom }) {
                    action(x, y, bitmap.getPixel(x, y))
                }
            }
        }
    }
    private fun histogram(bitmap: Bitmap, area: Rect, exclusions: List<Rect>): Map<Int, Int> {
        val counts = mutableMapOf<Int, Int>()
        visit(bitmap, area, exclusions) { _, _, color -> counts[color] = (counts[color] ?: 0) + 1 }
        return counts
    }
    private fun matching(bitmap: Bitmap, area: Rect, color: Color, exclusions: List<Rect> = emptyList()): List<InkPixel> {
        val pixels = mutableListOf<InkPixel>()
        visit(bitmap, area, exclusions) { x, y, actual -> if (near(actual, color.toArgb())) pixels += InkPixel(x, y, actual) }
        return pixels
    }
    private fun draw(): Bitmap = compose.runOnIdle {
        val nativeView = checkNotNull(view)
        Bitmap.createBitmap(nativeView.width, nativeView.height, Bitmap.Config.ARGB_8888).also { nativeView.draw(Canvas(it)) }
    }
    private fun begin(name: String) {
        report = name
        output("$report-measurements.tsv").writeText("Native Robolectric API34; synthetic input specimens; no popup/device acceptance\n")
    }
    private fun measure(line: String) { output("$report-measurements.tsv").appendText(line + "\n") }
    private fun save(bitmap: Bitmap, name: String) {
        output("$report-$name.png").outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
    }
    private fun hex(color: Int) = "%08x".format(color)
    private fun output(name: String) = File("build/reports/ui-inputs-gallery/$name").also { it.parentFile!!.mkdirs() }
}
