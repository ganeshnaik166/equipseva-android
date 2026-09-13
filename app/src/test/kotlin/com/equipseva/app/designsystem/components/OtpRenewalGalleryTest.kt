package com.equipseva.app.designsystem.components

import android.app.Application
import android.graphics.Bitmap
import android.graphics.Canvas
import android.view.View
import android.view.WindowManager
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.mutableStateOf
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.platform.ViewRootForTest
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.DialogWindowProvider
import androidx.core.graphics.ColorUtils
import androidx.test.core.app.ApplicationProvider
import com.equipseva.app.R
import com.equipseva.app.designsystem.theme.DarkEsColors
import com.equipseva.app.designsystem.theme.EquipSevaTheme
import com.equipseva.app.designsystem.theme.EsColors
import com.equipseva.app.designsystem.theme.LightEsColors
import com.equipseva.app.features.kyc.EmailVerifySheet
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
import org.robolectric.RuntimeEnvironment
import org.robolectric.android.controller.ActivityController
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/** Synthetic native-window specimens; no provider, account, device or TalkBack execution. */
@RunWith(IsolatedUiTestRunner::class)
@Config(application = Application::class, sdk = [34], shadows = [IsolatedUiPackageParser::class],
    qualifiers = "en-rUS-w320dp-h800dp-mdpi")
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@OptIn(ExperimentalTestApi::class)
class OtpRenewalGalleryTest {
    @get:Rule val compose = createEmptyComposeRule()
    private lateinit var host: ActivityController<ComponentActivity>
    private var activityView: View? = null
    private var activeModal: View? = null
    private var initialScale = 1f
    private var expectedScale = 1f
    private var modal = false
    private lateinit var report: String
    private val app: Application get() = ApplicationProvider.getApplicationContext()

    @Before fun isolate() {
        IsolatedUiPackageParser.assertIsolated(app)
        initialScale = RuntimeEnvironment.getFontScale()
    }

    @After fun close() {
        try {
            activeModal?.dispatchWindowFocusChanged(false)
            if (::host.isInitialized) {
                host.get().window.decorView.dispatchWindowFocusChanged(true)
                host.pause().stop().destroy()
            }
        } finally { RuntimeEnvironment.setFontScale(initialScale) }
    }

    @Test fun `light OTP paints real normal focus caret error and disabled states`() = fieldGallery(false)
    @Test fun `dark OTP paints real normal focus caret error and disabled states`() = fieldGallery(true)

    @Test fun `English modal at platform two times keeps copy and all actions reachable`() = sheetGallery(false)
    @Test @Config(qualifiers = "hi-rIN-w320dp-h800dp-mdpi")
    fun `Hindi modal at platform two times keeps copy and all actions reachable`() = sheetGallery(false)
    @Test @Config(qualifiers = "te-rIN-w320dp-h800dp-mdpi")
    fun `Telugu dark modal at platform two times keeps copy and all actions reachable`() = sheetGallery(true)
    @Test @Config(qualifiers = "en-rUS-w640dp-h320dp-land-mdpi")
    fun `short landscape modal at platform two times scrolls to real actions`() = sheetGallery(true)

    @Test fun `modal inherits secure host window flag`() = secureFlag(true)
    @Test fun `modal does not force secure flag on an ordinary host`() = secureFlag(false)

    private fun fieldGallery(dark: Boolean) {
        val p = if (dark) DarkEsColors else LightEsColors
        val enabled = mutableStateOf(true)
        val error = mutableStateOf<String?>(null)
        val code = mutableStateOf("123456")
        launch("field-${if (dark) "dark" else "light"}", dark) {
            Column(Modifier.fillMaxSize().background(p.surface).padding(16.dp)) {
                OtpDigitField(code.value, { code.value = it }, error = error.value, enabled = enabled.value)
            }
        }
        val field = compose.onNode(SemanticsMatcher.keyIsDefined(SemanticsProperties.EditableText))
        val labelText = app.getString(R.string.otp_code_label, 6)
        val label = compose.onNodeWithText(labelText, useUnmergedTree = true)
        val progressText = app.getString(R.string.otp_code_progress, 6, 6)
        val progress = compose.onNodeWithText(progressText, useUnmergedTree = true)
        nativeText(label, labelText, p.muted, p.surface, "normal-label")
        nativeText(progress, progressText, p.muted, p.surface, "normal-progress")
        nativeText(field, "123456", p.text, p.surface, "normal-value", listOf(bounds(label), bounds(progress)))
        boundary(field, p.outline, p.surface, "normal-outline", progress)

        field.performClick().assertIsFocused()
        settle()
        boundary(field, p.focus, p.surface, "focused-outline", progress)
        caret(field, p.text, p.surface, listOf(bounds(label), bounds(progress)))

        val errorText = "Incorrect code. Try again."
        compose.runOnIdle { error.value = errorText }
        settle()
        val errorNode = compose.onNodeWithText(errorText, useUnmergedTree = true)
        nativeText(errorNode, errorText, p.error.content, p.surface, "error-copy")
        nativeText(label, labelText, p.error.content, p.surface, "error-label")
        boundary(field, p.error.content, p.surface, "error-outline", errorNode)

        compose.runOnIdle { error.value = null; enabled.value = false }
        settle()
        field.assertIsNotEnabled()
        nativeText(field, "123456", p.disabled.content, p.disabled.container, "disabled-value",
            listOf(bounds(label), bounds(progress)))
        boundary(field, p.outline, p.disabled.container, "disabled-outline", progress)
        compose.runOnIdle { assertEquals("Rendering never changes controlled code", "123456", code.value) }
    }

    private fun sheetGallery(dark: Boolean) {
        val p = if (dark) DarkEsColors else LightEsColors
        val code = mutableStateOf("123456")
        val verifying = mutableStateOf(false)
        val sending = mutableStateOf(false)
        var submitCount = 0
        var resendCount = 0
        var closeCount = 0
        val email = "qa.synthetic@example.invalid"
        launch("sheet-${app.resources.configuration.locales[0].language}-${if (dark) "dark" else "light"}-${app.resources.configuration.screenWidthDp}dp", dark, 2f, isModal = true) {
            EmailVerifySheet(email, code.value, sending.value, verifying.value,
                { code.value = it }, { submitCount++; verifying.value = true },
                { closeCount++ }, { resendCount++; code.value = ""; sending.value = true })
        }
        val titleText = app.getString(R.string.kyc_verify_your_email)
        val title = compose.onNodeWithText(titleText, useUnmergedTree = true).performScrollTo()
        activateModal(title)
        nativeText(title, titleText, p.text, p.surface, "title-viewport")
        val targetText = app.getString(R.string.kyc_email_code_sent, email)
        val target = compose.onNodeWithText(targetText, useUnmergedTree = true).performScrollTo()
        nativeText(target, targetText, p.muted, p.surface, "target-viewport")
        val labelText = app.getString(R.string.otp_code_label, 6)
        val label = compose.onNodeWithText(labelText, useUnmergedTree = true).performScrollTo()
        nativeText(label, labelText, p.muted, p.surface, "label-viewport")
        val field = compose.onNode(SemanticsMatcher.keyIsDefined(SemanticsProperties.EditableText)).performScrollTo()
        nativeText(field, "123456", p.text, p.surface, "code-viewport")

        val verify = app.getString(R.string.kyc_verify_action)
        val resend = app.getString(R.string.kyc_email_resend_code)
        val close = app.getString(R.string.otp_close)
        action(resend, p.text, p.surface, "resend-ready")
        action(close, p.text, p.surface, "close-ready")
        action(verify, p.action.content, p.action.container, "verify-ready").performClick()
        compose.runOnIdle { assertEquals(1, submitCount) }
        settle()
        val busy = app.getString(R.string.kyc_email_verifying)
        action(busy, p.disabled.content, p.disabled.container, "verify-loading", enabled = false)
        compose.onNode(SemanticsMatcher.keyIsDefined(SemanticsProperties.EditableText)).assertIsNotEnabled()
        button(resend).assertIsNotEnabled()
        button(close).assertIsNotEnabled()

        compose.runOnIdle { verifying.value = false }
        settle()
        action(resend, p.text, p.surface, "resend-again").performClick()
        compose.runOnIdle { assertEquals(1, resendCount); assertEquals("", code.value) }
        settle()
        val sendingText = app.getString(R.string.otp_sending_to, email)
        val sendingCopy = compose.onNodeWithText(sendingText, useUnmergedTree = true).performScrollTo()
        nativeText(sendingCopy, sendingText, p.muted, p.surface, "sending-viewport")
        compose.runOnIdle { sending.value = false }
        settle()
        action(close, p.text, p.surface, "close-final").performClick()
        compose.runOnIdle { assertEquals(1, closeCount); assertEquals(1, submitCount) }
    }

    private fun secureFlag(secure: Boolean) {
        launch("secure-$secure", false, isModal = true, secure = secure) {
            EmailVerifySheet("qa.synthetic@example.invalid", "", false, false, {}, {}, {}, {})
        }
        val hostWindow = host.get().window
        val hostAttributesSecure = hostWindow.attributes.flags and WindowManager.LayoutParams.FLAG_SECURE != 0
        val hostRootParams = hostWindow.decorView.rootView.layoutParams as? WindowManager.LayoutParams
        assertNotNull("Secure inheritance reads actual attached host root window parameters", hostRootParams)
        val hostRootSecure = checkNotNull(hostRootParams).flags and WindowManager.LayoutParams.FLAG_SECURE != 0
        assertEquals("Actual host Window has the requested secure flag", secure, hostAttributesSecure)
        assertEquals("Actual host root exposes the requested flag to Material", secure, hostRootSecure)
        val field = compose.onNode(SemanticsMatcher.keyIsDefined(SemanticsProperties.EditableText))
        val view = evidenceView(field)
        val provider = generateSequence(view as View?) { it.parent as? View }
            .filterIsInstance<DialogWindowProvider>().firstOrNull()
        assertNotNull("The actual modal view exposes its own Android Window", provider)
        val actual = checkNotNull(provider).window.attributes.flags and WindowManager.LayoutParams.FLAG_SECURE != 0
        assertNotSame("Secure policy is checked on the separate modal Window", hostWindow, checkNotNull(provider).window)
        measure("secure\trequested=$secure\thostAttributes=$hostAttributesSecure\thostRoot=$hostRootSecure\tactualModal=$actual")
        assertEquals("Native window inherits host FLAG_SECURE", secure, actual)
        // This checks the Android flag only, not OS screenshot blocking or device security.
    }

    private fun launch(name: String, dark: Boolean, scale: Float = 1f,
        isModal: Boolean = false, secure: Boolean = false, content: @Composable () -> Unit) {
        modal = isModal
        expectedScale = scale
        report = name
        output("$report-measurements.tsv").writeText("API34 native Canvas; synthetic values; no device/provider acceptance\n")
        RuntimeEnvironment.setFontScale(scale)
        host = Robolectric.buildActivity(ComponentActivity::class.java).setup().visible()
        if (secure) host.get().window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        else host.get().window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        host.get().setContent {
            activityView = LocalView.current
            EquipSevaTheme(darkTheme = dark, content = content)
        }
        settle()
        if (!modal) compose.runOnIdle { host.get().window.decorView.dispatchWindowFocusChanged(true) }
    }

    private fun button(text: String) = compose.onNode(hasText(text) and hasClickAction())

    private fun action(text: String, foreground: Color, background: Color, name: String,
        enabled: Boolean = true): SemanticsNodeInteraction {
        val action = button(text).performScrollTo().assertIsDisplayed()
        if (enabled) action.assertIsEnabled() else action.assertIsNotEnabled()
        val area = unclippedBounds(action)
        assertTrue("Action remains at least 48dp high", area.height >= 48f * app.resources.displayMetrics.density - 1f)
        val view = evidenceView(action)
        assertTrue("Entire clickable action remains inside its native viewport: $name",
            contains(Rect(0f, 0f, view.width.toFloat(), view.height.toFloat()), area))
        val label = compose.onNodeWithText(text, useUnmergedTree = true)
        val labelArea = unclippedBounds(label)
        assertTrue("Action label is physically inside its clickable body", contains(area, labelArea))
        nativeText(label, text, foreground, background, name)
        return action
    }

    private fun nativeText(node: SemanticsNodeInteraction, text: String, foreground: Color,
        background: Color, name: String, exclusions: List<Rect> = emptyList()) {
        node.assertIsDisplayed()
        val layouts = mutableListOf<TextLayoutResult>()
        node.performSemanticsAction(SemanticsActions.GetTextLayoutResult) { it(layouts) }
        val layout = layouts.single { it.layoutInput.text.text == text }
        assertEquals("Actual native owner fontScale for $name", expectedScale, layout.layoutInput.density.fontScale, 0.001f)
        assertFalse("Complete vertical text for $name", layout.didOverflowHeight)
        assertEquals(text.length, layout.getLineEnd(layout.lineCount - 1, visibleEnd = true))
        repeat(layout.lineCount) { line ->
            assertFalse(layout.isLineEllipsized(line))
            assertTrue(layout.getLineLeft(line) >= -1f)
            assertTrue(layout.getLineRight(line) <= layout.size.width + 1f)
        }
        val area = unclippedBounds(node)
        val bitmap = draw(node)
        try {
            save(bitmap, name)
            assertTrue("Text bounds contained in native viewport: $name", contains(Rect(0f, 0f, bitmap.width.toFloat(), bitmap.height.toFloat()), area))
            val colors = mutableMapOf<Int, Int>()
            var glyphs = 0
            var actualForeground = 0
            pixels(bitmap, area, exclusions) { _, _, color ->
                colors[color] = (colors[color] ?: 0) + 1
                if (near(color, foreground.toArgb())) { glyphs++; actualForeground = color }
            }
            val actualBackground = colors.maxByOrNull { it.value }?.key ?: error("Empty text sample")
            assertTrue("Actual glyph ink must exist for $name", glyphs >= 8)
            assertTrue("Actual paired text surface for $name", near(actualBackground, background.toArgb()))
            val ratio = ColorUtils.calculateContrast(actualForeground, actualBackground)
            measure("$name\tfontScale=${layout.layoutInput.density.fontScale}\tlineHeight=${layout.getLineBottom(0) - layout.getLineTop(0)}\tbounds=$area\tglyphs=$glyphs\tfg=${hex(actualForeground)}\tbg=${hex(actualBackground)}\tcontrast=$ratio")
            assertTrue("Actual text contrast >=4.5 for $name", ratio >= 4.5)
        } finally { bitmap.recycle() }
    }

    private fun boundary(field: SemanticsNodeInteraction, foreground: Color, background: Color,
        name: String, supporting: SemanticsNodeInteraction) {
        val area = bounds(field)
        // Native editable bounds also contain supporting text. In the error state that
        // text shares the border color, so it cannot contribute to outline height.
        val supportArea = unclippedBounds(supporting)
        val bodyArea = Rect(area.left, area.top, area.right, minOf(area.bottom, supportArea.top))
        assertTrue("Supporting copy follows the sampled input body", bodyArea.height > 0f)
        val bitmap = draw(field)
        try {
            save(bitmap, name)
            val ink = mutableListOf<Pair<Int, Int>>()
            val colors = mutableMapOf<Int, Int>()
            val rowInk = mutableMapOf<Int, Int>()
            pixels(bitmap, bodyArea) { x, y, color ->
                colors[color] = (colors[color] ?: 0) + 1
                if (near(color, foreground.toArgb())) {
                    ink += x to y
                    rowInk[y] = (rowInk[y] ?: 0) + 1
                }
            }
            assertTrue("Actual boundary pixels exist: $name", ink.size >= 40)
            val painted = pixelBounds(ink)
            val horizontalEdges = rowInk.filterValues { it >= bodyArea.width * 0.5f }.keys.sorted()
            assertTrue("Real top and bottom outline rows span the control, excluding supporting glyphs",
                horizontalEdges.size >= 2)
            val edgeHeight = horizontalEdges.last() - horizontalEdges.first() + 1f
            assertTrue("Actual outline spans the 56dp input minimum with one physical-pixel tolerance",
                painted.width >= 80f && edgeHeight >= 56f * app.resources.displayMetrics.density - 1f)
            val edgeWidth = 4f * app.resources.displayMetrics.density
            assertTrue("Boundary reaches both physical control edges rather than counting text",
                ink.count { it.first <= area.left + edgeWidth } >= 8 &&
                    ink.count { it.first >= area.right - edgeWidth - 1f } >= 8)
            val actualBackground = colors.maxBy { it.value }.key
            assertTrue(near(actualBackground, background.toArgb()))
            val ratio = ColorUtils.calculateContrast(foreground.toArgb(), actualBackground)
            measure("$name\tbodySample=$bodyArea\tsupporting=$supportArea\tpainted=$painted\tedgeHeight=$edgeHeight\tcontrast=$ratio")
            assertTrue("Actual outline contrast >=3", ratio >= 3.0)
        } finally { bitmap.recycle() }
    }

    private fun caret(field: SemanticsNodeInteraction, foreground: Color, background: Color, exclusions: List<Rect>) {
        val area = bounds(field)
        val previous = compose.mainClock.autoAdvance
        val frames = mutableListOf<Bitmap>()
        compose.mainClock.autoAdvance = false
        try {
            repeat(5) { index ->
                compose.mainClock.advanceTimeBy(250)
                compose.waitForIdle()
                frames += draw(field).also { save(it, "caret-$index") }
            }
            assertTrue(frames.all { it.width == frames.first().width && it.height == frames.first().height })
            val ink = mutableListOf<Pair<Int, Int>>()
            pixels(frames.first(), area, exclusions) { x, y, _ ->
                val values = frames.map { it.getPixel(x, y) }
                if (values.any { near(it, foreground.toArgb()) } && values.any { near(it, background.toArgb()) }) ink += x to y
            }
            assertTrue("Real caret alternates with paired fill over finite frames", ink.size >= 8)
            val mark = pixelBounds(ink)
            assertTrue(mark.width <= 4f && mark.height >= 8f && contains(area, mark))
            assertTrue(ColorUtils.calculateContrast(foreground.toArgb(), background.toArgb()) >= 4.5)
            measure("caret\tpixels=${ink.size}\tbounds=$mark\tframes=${frames.size}")
        } finally {
            frames.forEach { it.recycle() }
            compose.mainClock.autoAdvance = previous
        }
    }

    private fun activateModal(node: SemanticsNodeInteraction) {
        activeModal = evidenceView(node).rootView
        compose.runOnIdle {
            host.get().window.decorView.dispatchWindowFocusChanged(false)
            activeModal!!.dispatchWindowFocusChanged(true)
        }
    }

    private fun evidenceView(node: SemanticsNodeInteraction): View {
        val view = (node.fetchSemanticsNode().root as ViewRootForTest).view
        if (modal) {
            assertNotSame("Modal evidence must not capture activity content", activityView, view)
            assertNotSame("Modal owns a separate Android window", host.get().window.decorView, view.rootView)
        }
        measure("native-root\tcompose=${view.javaClass.name}\twindow=${view.rootView.javaClass.name}\twidth=${view.width}\theight=${view.height}")
        return view
    }

    private fun draw(node: SemanticsNodeInteraction): Bitmap {
        val view = evidenceView(node)
        return compose.runOnIdle {
            check(view.width > 0 && view.height > 0)
            Bitmap.createBitmap(view.width, view.height, Bitmap.Config.ARGB_8888).also { view.draw(Canvas(it)) }
        }
    }

    private fun settle() { compose.mainClock.advanceTimeBy(400); compose.waitForIdle() }
    private fun bounds(node: SemanticsNodeInteraction) = node.fetchSemanticsNode().boundsInRoot
    private fun unclippedBounds(node: SemanticsNodeInteraction): Rect {
        val area = node.getUnclippedBoundsInRoot()
        val density = app.resources.displayMetrics.density
        return Rect(area.left.value * density, area.top.value * density,
            area.right.value * density, area.bottom.value * density)
    }
    private fun contains(outer: Rect, inner: Rect) = inner.left >= outer.left - 1f && inner.top >= outer.top - 1f &&
        inner.right <= outer.right + 1f && inner.bottom <= outer.bottom + 1f
    private fun near(actual: Int, expected: Int) = listOf(16, 8, 0).all { abs(((actual shr it) and 255) - ((expected shr it) and 255)) <= 2 }
    private fun pixelBounds(ink: List<Pair<Int, Int>>) = Rect(ink.minOf { it.first }.toFloat(), ink.minOf { it.second }.toFloat(),
        ink.maxOf { it.first } + 1f, ink.maxOf { it.second } + 1f)
    private fun pixels(bitmap: Bitmap, area: Rect, exclusions: List<Rect> = emptyList(), action: (Int, Int, Int) -> Unit) {
        for (y in floor(area.top).toInt().coerceAtLeast(0) until ceil(area.bottom).toInt().coerceAtMost(bitmap.height)) {
            for (x in floor(area.left).toInt().coerceAtLeast(0) until ceil(area.right).toInt().coerceAtMost(bitmap.width)) {
                if (exclusions.none { x + 0.5f >= it.left && x + 0.5f < it.right &&
                        y + 0.5f >= it.top && y + 0.5f < it.bottom }) action(x, y, bitmap.getPixel(x, y))
            }
        }
    }
    private fun save(bitmap: Bitmap, name: String) {
        output("$report-$name.png").outputStream().use { check(bitmap.compress(Bitmap.CompressFormat.PNG, 100, it)) }
    }
    private fun measure(line: String) { output("$report-measurements.tsv").appendText(line + "\n") }
    private fun hex(value: Int) = "%08x".format(value)
    private fun output(name: String) = File("build/reports/otp-renewal-gallery/$name").also { checkNotNull(it.parentFile).mkdirs() }
}
