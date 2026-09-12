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
import androidx.compose.runtime.mutableStateOf
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.assertHeightIsAtLeast
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.assertIsNotSelected
import androidx.compose.ui.test.assertIsSelected
import androidx.compose.ui.test.assertWidthIsAtLeast
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.hasAnyDescendant
import androidx.compose.ui.test.hasText
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
import com.equipseva.app.features.auth.RoleSelectViewModel.RoleSelectEffect
import com.equipseva.app.features.auth.RoleSelectViewModel.RoleSelectError
import com.equipseva.app.features.auth.RoleSelectViewModel.RoleSelectState
import com.equipseva.app.features.auth.state.FormUiState
import com.equipseva.app.testing.IsolatedUiPackageParser
import com.equipseva.app.testing.IsolatedUiTestRunner
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import java.io.File
import kotlin.math.roundToInt
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
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
 * Production screen/content in an isolated host. The VM's auth/RPC fences
 * are exercised separately; these checks cover callbacks, semantics and actual
 * text layout in Robolectric, not a device or TalkBack walkthrough.
 */
@RunWith(IsolatedUiTestRunner::class)
@OptIn(androidx.compose.ui.test.ExperimentalTestApi::class)
@Config(application = Application::class, sdk = [34], shadows = [IsolatedUiPackageParser::class],
    qualifiers = "en-rUS-w360dp-h800dp-mdpi")
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class RoleSelectScreenUiTest {
    @get:Rule val compose = createEmptyComposeRule()
    private lateinit var controller: ActivityController<ComponentActivity>
    private var renderedView: View? = null
    private var largeTextExitCalls = 0
    private val context: Context get() = ApplicationProvider.getApplicationContext()
    private val radioRole = SemanticsMatcher.expectValue(SemanticsProperties.Role, Role.RadioButton)
    private val polite = SemanticsMatcher.expectValue(SemanticsProperties.LiveRegion, LiveRegionMode.Polite)

    @Before fun startEmptyHost() {
        IsolatedUiPackageParser.assertIsolated(ApplicationProvider.getApplicationContext())
        controller = Robolectric.buildActivity(ComponentActivity::class.java).setup().visible()
    }

    @After fun closeEmptyHost() {
        if (::controller.isInitialized) controller.pause().stop().destroy()
    }

    @Test fun `screen saves then checks setup without saving again and cancels before exit`() {
        val state = MutableStateFlow(RoleSelectState())
        val effects = MutableSharedFlow<RoleSelectEffect>(extraBufferCapacity = 4)
        val calls = mutableListOf<String>()
        val viewModel = mockk<RoleSelectViewModel>()
        every { viewModel.state } returns state
        every { viewModel.effects } returns effects
        every { viewModel.onRoleSelected(any()) } answers {
            state.value = state.value.copy(selected = firstArg<UserRole>())
        }
        every { viewModel.onConfirm() } answers {
            state.value = state.value.copy(saved = true)
            effects.tryEmit(RoleSelectEffect.RoleSaved)
            Unit
        }
        every { viewModel.onCheckSavedRole() } answers {
            effects.tryEmit(RoleSelectEffect.RoleSaved)
            Unit
        }
        every { viewModel.cancelPendingSave() } answers { calls += "cancel" }
        render {
            RoleSelectScreen(
                onShowMessage = { calls += "message" },
                onBack = { calls += "back" },
                viewModel = viewModel,
                onRoleSaved = { calls += "refresh" },
                onSignOut = { calls += "sign-out" },
            )
        }

        node(R.string.role_picker_hospital).performClick()
        capture("en-360-selected")
        node(R.string.role_picker_save_continue).performScrollTo().assertIsEnabled().performClick()
        compose.runOnIdle { assertEquals(listOf("refresh"), calls) }
        node(R.string.role_picker_check_again).performScrollTo().assertIsEnabled().performClick()
        compose.runOnIdle { assertEquals(listOf("refresh", "refresh"), calls) }
        verify(exactly = 1) { viewModel.onConfirm() }
        verify(exactly = 1) { viewModel.onCheckSavedRole() }

        node(R.string.role_picker_sign_out).performScrollTo().performClick()
        compose.runOnIdle { assertEquals(listOf("refresh", "refresh", "cancel", "sign-out"), calls) }
    }

    @Test fun `only supported radio choices are exposed and selection is exclusive`() {
        val state = mutableStateOf(RoleSelectState(roles = UserRole.entries.toList()))
        render {
            RoleSelectContent(
                state = state.value,
                onRoleSelected = { state.value = state.value.copy(selected = it) },
                onConfirm = {}, onCheckSavedRole = {}, onSignOut = {},
            )
        }
        compose.onAllNodes(radioRole).assertCountEquals(2)
        listOf(UserRole.SUPPLIER, UserRole.MANUFACTURER, UserRole.LOGISTICS).forEach {
            compose.onNodeWithText(it.displayName).assertDoesNotExist()
        }
        node(R.string.role_picker_title).assert(SemanticsMatcher.keyIsDefined(SemanticsProperties.Heading))
        node(R.string.role_picker_save_continue).assertIsNotEnabled()
        node(R.string.role_picker_hospital).assert(radioRole).assertIsNotSelected().performClick()
        node(R.string.role_picker_hospital).assertIsSelected().assertHeightIsAtLeast(48.dp)
        node(R.string.role_picker_engineer).assertIsNotSelected().performScrollTo().performClick()
        node(R.string.role_picker_engineer).assertIsSelected().assertHeightIsAtLeast(48.dp)
        node(R.string.role_picker_hospital).assertIsNotSelected()
        node(R.string.role_picker_save_continue).assertIsEnabled()
    }

    @Test fun `submitting disables role changes and save while sign out stays reachable`() {
        var exits = 0
        renderState(
            RoleSelectState(selected = UserRole.HOSPITAL, form = FormUiState(submitting = true)),
            onSignOut = { exits++ },
        )
        node(R.string.role_picker_hospital).assertIsNotEnabled()
        node(R.string.role_picker_engineer).assertIsNotEnabled()
        node(R.string.role_picker_saving).assertIsNotEnabled().assert(polite)
        node(R.string.role_picker_sign_out).performScrollTo().assertIsDisplayed()
            .assertIsEnabled().assertHeightIsAtLeast(48.dp).performClick()
        assertEquals(1, exits)
    }

    @Test fun `save error is announced and retry remains actionable`() {
        var retries = 0
        renderState(
            RoleSelectState(selected = UserRole.ENGINEER, error = RoleSelectError.Network),
            onConfirm = { retries++ },
        )
        val error = context.getString(R.string.role_picker_error_network)
        compose.onNode(polite and hasAnyDescendant(hasText(error))).assertExists()
        capture("en-360-error-top")
        node(R.string.role_picker_try_again).performScrollTo().assertIsEnabled().performClick()
        assertEquals(1, retries)
        capture("en-360-error-retry")
    }

    @Test
    @Config(qualifiers = "en-rUS-w640dp-h360dp-land-mdpi")
    fun `compact landscape with large text keeps every action and full copy reachable`() {
        renderLargeText()
        assertLayout(640)
    }

    @Test
    @Config(qualifiers = "hi-rIN-w320dp-h800dp-mdpi")
    fun `Hindi narrow large text uses localized copy without truncation`() {
        renderLargeText()
        assertEquals("अपनी भूमिका चुनें", context.getString(R.string.role_picker_title))
        assertEquals("साइन आउट करें", context.getString(R.string.role_picker_sign_out))
        capture("hi-320-2x-top")
        node(R.string.role_picker_hospital).performScrollTo()
        capture("hi-320-2x-hospital")
        assertLayout(320)
        assertFullExitAtScrollEnd()
        capture("hi-320-2x-bottom")
    }

    @Test
    @Config(qualifiers = "te-rIN-w320dp-h800dp-mdpi")
    fun `Telugu narrow large text uses localized copy without truncation`() {
        renderLargeText()
        assertEquals("మీ పాత్రను ఎంచుకోండి", context.getString(R.string.role_picker_title))
        assertEquals("సైన్ అవుట్ చేయండి", context.getString(R.string.role_picker_sign_out))
        capture("te-320-2x-top")
        node(R.string.role_picker_hospital).performScrollTo()
        capture("te-320-2x-hospital")
        assertLayout(320)
        assertFullExitAtScrollEnd()
        capture("te-320-2x-bottom")
    }

    @Test fun `enabled primary actions retain readable contrast in light theme`() =
        assertPrimaryActionContrast(darkTheme = false, disabled = false)

    @Test fun `enabled primary actions retain readable contrast in dark theme`() =
        assertPrimaryActionContrast(darkTheme = true, disabled = false)

    @Test fun `disabled and saving actions retain readable labels in light theme`() =
        assertPrimaryActionContrast(darkTheme = false, disabled = true)

    @Test fun `disabled and saving actions retain readable labels in dark theme`() =
        assertPrimaryActionContrast(darkTheme = true, disabled = true)

    @Test fun `role indicators remain visible in light theme including disabled states`() =
        assertRadioContrast(darkTheme = false)

    @Test fun `role indicators remain visible in dark theme including disabled states`() =
        assertRadioContrast(darkTheme = true)

    private fun assertRadioContrast(darkTheme: Boolean) {
        val cases = listOf(
            "unselected" to RoleSelectState(),
            "selected" to RoleSelectState(selected = UserRole.HOSPITAL),
            "saving" to RoleSelectState(selected = UserRole.HOSPITAL, form = FormUiState(submitting = true)),
            "saved" to RoleSelectState(selected = UserRole.HOSPITAL, saved = true),
        )
        val state = mutableStateOf(cases.first().second)
        render(darkTheme = darkTheme) { RoleSelectContent(state.value, {}, {}, {}, {}) }
        for ((name, value) in cases) {
            compose.runOnIdle { state.value = value }
            for ((id, role) in listOf(R.string.role_picker_hospital to UserRole.HOSPITAL,
                R.string.role_picker_engineer to UserRole.ENGINEER)) {
                val card = node(id).performScrollTo().assertIsDisplayed().assert(radioRole)
                if (value.selected == role) card.assertIsSelected() else card.assertIsNotSelected()
                if (value.form.submitting || value.saved) card.assertIsNotEnabled() else card.assertIsEnabled()
                val bounds = card.fetchSemanticsNode().boundsInRoot
                val density = context.resources.displayMetrics.density
                // The 24dp radio is the trailing child after 16dp card padding.
                // Crop only its circle, excluding all label/icon/card-border ink.
                val centerX = (bounds.right - 28 * density).roundToInt()
                val centerY = bounds.center.y.roundToInt()
                val radius = (12 * density).roundToInt()
                val bitmap = drawHost()
                val label = "${if (darkTheme) "dark" else "light"}-$name-${role.name}"
                try {
                    saveBitmap(bitmap, "radio-$label")
                    val pixels = mutableMapOf<Int, Int>()
                    for (y in centerY-radius..centerY+radius) for (x in centerX-radius..centerX+radius) {
                        val color = bitmap.getPixel(x, y)
                        pixels[color] = (pixels[color] ?: 0) + 1
                    }
                    val background = checkNotNull(pixels.maxByOrNull { it.value }).key
                    val ink = pixels.filterKeys { it != background }.maxByOrNull { it.value }
                    assertTrue("A solid visible ring must exist: $label", ink != null && ink.value >= 10)
                    val foreground = checkNotNull(ink).key
                    val ratio = ColorUtils.calculateContrast(foreground, background)
                    File("build/outputs/auth-a2-ui/radio-contrast-measurements.txt").appendText(
                        "$label foreground=${foreground.toUInt().toString(16)} background=${background.toUInt().toString(16)} ratio=$ratio inkPixels=${ink.value}\n",
                    )
                    // Three to one for disabled controls is our explicit visual
                    // target; it is not a claim of a universal disabled-state rule.
                    assertTrue("Rendered radio contrast >= 3:1: $label was $ratio", ratio >= 3)
                } finally { bitmap.recycle() }
            }
        }
    }

    private fun assertPrimaryActionContrast(darkTheme: Boolean, disabled: Boolean) {
        val cases = if (disabled) listOf(
            RoleSelectState() to R.string.role_picker_save_continue,
            RoleSelectState(selected = UserRole.HOSPITAL, form = FormUiState(submitting = true)) to R.string.role_picker_saving,
        ) else listOf(
            RoleSelectState(selected = UserRole.HOSPITAL) to R.string.role_picker_save_continue,
            RoleSelectState(selected = UserRole.ENGINEER, error = RoleSelectError.Network) to R.string.role_picker_try_again,
            RoleSelectState(selected = UserRole.HOSPITAL, saved = true) to R.string.role_picker_check_again,
        )
        val state = mutableStateOf(cases.first().first)
        render(darkTheme = darkTheme) {
            RoleSelectContent(state.value, {}, {}, {}, {})
        }
        for ((value, id) in cases) {
            compose.runOnIdle { state.value = value }
            val action = node(id).performScrollTo().assertIsDisplayed()
            if (disabled) action.assertIsNotEnabled() else action.assertIsEnabled()
            val buttonBounds = action.fetchSemanticsNode().boundsInRoot
            val text = compose.onNodeWithText(context.getString(id), useUnmergedTree = true)
            val textBounds = text.fetchSemanticsNode().boundsInRoot
            val layouts = mutableListOf<TextLayoutResult>()
            text.performSemanticsAction(SemanticsActions.GetTextLayoutResult) { it(layouts) }
            val foreground = layouts.single().layoutInput.style.color
            assertTrue("text has a resolved foreground", foreground != androidx.compose.ui.graphics.Color.Unspecified)
            val label = "${if (darkTheme) "dark" else "light"}-${if (disabled) "disabled" else "enabled"}-${context.resources.getResourceEntryName(id)}"
            val bitmap = drawHost()
            try {
                saveBitmap(bitmap, "contrast-$label")
                // Sample the opaque middle of the real drawn button, away from
                // its corners and centered text/spinner. Both bounds and pixels
                // come from production Compose, not a copied token-only policy.
                val x = (buttonBounds.left + 8f).roundToInt()
                val y = buttonBounds.center.y.roundToInt()
                val background = bitmap.getPixel(x, y)
                assertEquals("opaque rendered button", 255, android.graphics.Color.alpha(background))
                val expectedGlyph = ColorUtils.compositeColors(foreground.toArgb(), background)
                val glyphPixels = mutableMapOf<Int, Int>()
                for (py in textBounds.top.toInt().coerceAtLeast(0) until textBounds.bottom.toInt().coerceAtMost(bitmap.height)) {
                    for (px in textBounds.left.toInt().coerceAtLeast(0) until textBounds.right.toInt().coerceAtMost(bitmap.width)) {
                        val pixel = bitmap.getPixel(px, py)
                        // Native alpha rounding may differ by one channel step.
                        if (listOf(16, 8, 0).all { shift ->
                            kotlin.math.abs(((pixel shr shift) and 255) - ((expectedGlyph shr shift) and 255)) <= 2
                        }) glyphPixels[pixel] = (glyphPixels[pixel] ?: 0) + 1
                    }
                }
                val solidTextPixels = glyphPixels.values.sum()
                assertTrue("composited foreground appears in actual glyph pixels: $label", solidTextPixels >= 5)
                val fg = checkNotNull(glyphPixels.maxByOrNull { it.value }).key
                val ratio = ColorUtils.calculateContrast(fg, background)
                File("build/outputs/auth-a2-ui/contrast-measurements.txt")
                    .appendText("$label foreground=${fg.toUInt().toString(16)} background=${background.toUInt().toString(16)} ratio=$ratio glyphPixels=$solidTextPixels\n")
                // Disabled controls are exempt from some accessibility contrast
                // criteria; this slice also keeps their status labels readable.
                assertTrue("rendered primary label contrast >= 4.5:1: $label was $ratio", ratio >= 4.5)
            } finally {
                bitmap.recycle()
            }
        }
    }

    private fun renderLargeText() = renderState(
        RoleSelectState(selected = UserRole.HOSPITAL, error = RoleSelectError.Network),
        fontScale = 2f,
        onSignOut = { largeTextExitCalls++ },
    )

    private fun renderState(
        state: RoleSelectState,
        fontScale: Float = 1f,
        onConfirm: () -> Unit = {},
        onSignOut: () -> Unit = {},
    ) = render(fontScale) {
        RoleSelectContent(
            state = state,
            onRoleSelected = {},
            onConfirm = onConfirm,
            onCheckSavedRole = {},
            onSignOut = onSignOut,
        )
    }

    private fun render(fontScale: Float = 1f, darkTheme: Boolean = false, content: @Composable () -> Unit) {
        controller.get().setContent {
            renderedView = LocalView.current
            EquipSevaTheme(darkTheme = darkTheme) {
                val density = LocalDensity.current
                CompositionLocalProvider(LocalDensity provides Density(density.density, fontScale)) {
                    content()
                }
            }
        }
        compose.waitForIdle()
    }

    private fun node(id: Int) = compose.onNodeWithText(context.getString(id))

    private fun assertFullExitAtScrollEnd() {
        // assertIsDisplayed alone permits a partially visible button. Scroll
        // through the final paragraph, then prove the complete exit is in view.
        node(R.string.role_picker_sign_out_hint).performScrollTo().assertIsDisplayed()
        val viewport = compose.onRoot().getUnclippedBoundsInRoot()
        val exit = node(R.string.role_picker_sign_out).assertIsEnabled().getUnclippedBoundsInRoot()
        assertTrue("entire exit starts within viewport", exit.left >= viewport.left && exit.top >= viewport.top)
        assertTrue("entire exit ends within viewport", exit.right <= viewport.right && exit.bottom <= viewport.bottom)
        node(R.string.role_picker_sign_out).performClick()
        assertEquals("visible exit invokes its callback", 1, largeTextExitCalls)
    }

    private fun assertLayout(width: Int) {
        val actionIds = listOf(
            R.string.role_picker_hospital,
            R.string.role_picker_engineer,
            R.string.role_picker_try_again,
            R.string.role_picker_sign_out,
        )
        val bounds = actionIds.map { id ->
            node(id).assertHeightIsAtLeast(48.dp).assertWidthIsAtLeast(48.dp).getUnclippedBoundsInRoot()
        }
        bounds.forEach {
            assertTrue("left target edge", it.left >= 0.dp)
            assertTrue("right target edge", it.right <= width.dp)
        }
        bounds.zipWithNext().forEach { (first, second) ->
            assertTrue("targets must not overlap", first.bottom <= second.top)
        }
        val textIds = actionIds + listOf(
            R.string.role_picker_title,
            R.string.role_picker_intro,
            R.string.role_picker_hospital_description,
            R.string.role_picker_engineer_description,
            R.string.role_picker_error_network,
            R.string.role_picker_sign_out_hint,
        )
        textIds.forEach { id ->
            val layouts = mutableListOf<TextLayoutResult>()
            compose.onNodeWithText(context.getString(id), useUnmergedTree = true)
                .performSemanticsAction(SemanticsActions.GetTextLayoutResult) { it(layouts) }
            assertTrue("rendered text layout for $id", layouts.isNotEmpty())
            layouts.forEach {
                val label = context.resources.getResourceEntryName(id)
                assertFalse("Vertical clipping: $label", it.didOverflowHeight)
                assertTrue("Width exceeds constraint: $label", it.size.width <= it.layoutInput.constraints.maxWidth)
                assertTrue("Height exceeds constraint: $label", it.size.height <= it.layoutInput.constraints.maxHeight)
                assertTrue("No lines: $label", it.lineCount > 0)
                repeat(it.lineCount) { line ->
                    assertFalse("Ellipsized line: $label", it.isLineEllipsized(line))
                    assertTrue("Line left edge: $label", it.getLineLeft(line) >= -1f)
                    assertTrue("Line right edge: $label", it.getLineRight(line) <= it.multiParagraph.width + 1f)
                }
                assertEquals("All text must be laid out: $label", it.layoutInput.text.text.trimEnd().length,
                    it.getLineEnd(it.lineCount - 1, visibleEnd = true))
            }
        }
        actionIds.forEach { node(it).performScrollTo().assertIsDisplayed() }
    }

    private fun capture(name: String) {
        val bitmap = drawHost()
        try {
            saveBitmap(bitmap, name)
        } finally {
            bitmap.recycle()
        }
    }

    private fun drawHost(): Bitmap {
        compose.waitForIdle()
        // Robolectric has no hardware frame-commit callback for PixelCopy.
        // Native Canvas draws the actual Compose host for simulated UI review;
        // these images are not device or window screenshots.
        return compose.runOnIdle {
            val view = checkNotNull(renderedView)
            check(view.width > 0 && view.height > 0)
            Bitmap.createBitmap(view.width, view.height, Bitmap.Config.ARGB_8888).also {
                view.draw(Canvas(it))
            }
        }
    }

    private fun saveBitmap(bitmap: Bitmap, name: String) {
        val output = File("build/outputs/auth-a2-ui/$name.png")
        val parent = checkNotNull(output.parentFile)
        check(parent.mkdirs() || parent.isDirectory)
        output.outputStream().use { stream ->
            check(bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream))
        }
    }
}
