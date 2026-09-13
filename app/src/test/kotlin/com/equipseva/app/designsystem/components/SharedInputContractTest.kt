package com.equipseva.app.designsystem.components

import android.app.Application
import android.text.InputType
import android.view.View
import android.view.KeyEvent
import android.view.InputDevice
import android.os.SystemClock
import android.view.inputmethod.EditorInfo
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.input.InputMode
import androidx.compose.ui.input.InputModeManager
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.platform.LocalInputModeManager
import androidx.compose.ui.platform.ViewRootForTest
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.dp
import androidx.test.core.app.ApplicationProvider
import androidx.test.platform.app.InstrumentationRegistry
import com.equipseva.app.designsystem.theme.EquipSevaTheme
import com.equipseva.app.features.notifications.QuietHourField
import com.equipseva.app.testing.IsolatedUiPackageParser
import com.equipseva.app.testing.IsolatedUiTestRunner
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
import org.robolectric.shadows.ShadowWindowManagerGlobal
import java.io.File

/** Synthetic component contracts. No account, network, or auth implementation is involved. */
@RunWith(IsolatedUiTestRunner::class)
@Config(application = Application::class, sdk = [34], shadows = [IsolatedUiPackageParser::class],
    qualifiers = "en-rUS-w320dp-h800dp-mdpi")
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@OptIn(ExperimentalTestApi::class)
class SharedInputContractTest {
    @get:Rule val compose = createEmptyComposeRule()
    private lateinit var host: ActivityController<ComponentActivity>
    private lateinit var inputView: View
    private lateinit var inputMode: InputModeManager
    private var initialTouchMode = true
    private val trigger = SemanticsMatcher.expectValue(SemanticsProperties.Role, Role.DropdownList)
    @Before fun open() {
        initialTouchMode = ShadowWindowManagerGlobal.getInTouchMode()
        IsolatedUiPackageParser.assertIsolated(ApplicationProvider.getApplicationContext())
        host = Robolectric.buildActivity(ComponentActivity::class.java).setup().visible()
    }
    @After fun close() {
        try { host.pause().stop().destroy() }
        finally { InstrumentationRegistry.getInstrumentation().setInTouchMode(initialTouchMode) }
    }

    @Test fun `editable node retains its label after typing and exposes exact error`() {
        val value = mutableStateOf("")
        render { EsField(value.value, { value.value = it }, label = "Email address", error = "Enter a valid email") }
        val field = compose.onNode(hasSetTextAction())
        val named = hasText("Email address") or hasContentDescription("Email address")
        field.assert(named).assert(SemanticsMatcher.expectValue(SemanticsProperties.Error, "Enter a valid email"))
        field.performTextInput("person@example.test")
        field.assert(named).assertTextContains("person@example.test")
    }

    @Test fun `password stays masked and next moves focus without submitting`() {
        var calls = 0
        render {
            EsField("synthetic-secret", {}, label = "Password", type = EsFieldType.Password,
                onImeAction = { calls++ })
            EsField("", {}, label = "Next field")
        }
        val fields = compose.onAllNodes(hasSetTextAction())
        fields[0].assert(SemanticsMatcher.keyIsDefined(SemanticsProperties.Password))
        assertFalse(fields[0].fetchSemanticsNode().config.getOrElse(SemanticsProperties.ContentDescription) { emptyList() }
            .any { it.contains("synthetic-secret") })
        fields[0].performClick().performImeAction()
        fields[1].assertIsFocused()
        compose.runOnIdle { assertEquals(0, calls) }
    }

    @Test fun `submit IME actions use the latest callback and null stays non submitting`() {
        val action = mutableStateOf(ImeAction.Done)
        val callback = mutableStateOf<(() -> Unit)?>(null)
        var old = 0
        var fresh = 0
        render { EsField("", {}, label = "Final field", imeAction = action.value, onImeAction = callback.value) }
        val field = compose.onNode(hasSetTextAction())
        field.performClick().performImeAction()
        compose.runOnIdle { callback.value = { old++ } }
        compose.runOnIdle { callback.value = { fresh++ } }
        listOf(ImeAction.Done, ImeAction.Send, ImeAction.Go, ImeAction.Search).forEach {
            compose.runOnIdle { action.value = it }
            field.performClick().performImeAction()
        }
        compose.runOnIdle { assertEquals(0, old); assertEquals(4, fresh); callback.value = null }
        field.performClick().performImeAction()
        compose.runOnIdle { assertEquals(4, fresh) }
    }

    @Test fun `disabled time display preserves its outer picker action`() {
        var opens = 0
        render { QuietHourField("22:00", "Start time", { opens++ }, modifier = Modifier.testTag("time-picker")) }
        compose.onNodeWithTag("time-picker").assertIsEnabled()
            .assertContentDescriptionEquals("Start time, 22:00")
            .assert(SemanticsMatcher.expectValue(SemanticsProperties.Role, Role.Button))
        compose.onAllNodes(hasClickAction()).assertCountEquals(1)
        compose.onNode(hasSetTextAction()).assertDoesNotExist()
        // The last56dp is the physical text display at mdpi; tap its center, below the label.
        compose.onNodeWithTag("time-picker").performTouchInput { click(Offset(center.x, height - 28f)) }
        compose.runOnIdle { assertEquals(1, opens) }
        compose.onNodeWithTag("time-picker").performSemanticsAction(SemanticsActions.OnClick) { assertTrue(it()) }
        compose.runOnIdle { assertEquals(2, opens) }
    }

    @Test fun `dropdown trigger has name exact error and a 56dp physical target`() {
        render { EsDropdown(null, {}, listOf("First"), label = "Service state", error = "Choose your service state") }
        compose.onNode(trigger).assertHeightIsAtLeast(56.dp)
            .assert(hasText("Service state") or hasContentDescription("Service state"))
            .assert(SemanticsMatcher.expectValue(SemanticsProperties.Error, "Choose your service state"))
    }

    @Test fun `disabled then reenabled menu requires a fresh gesture`() {
        val enabled = mutableStateOf(true)
        render { EsDropdown(null, {}, listOf("First"), enabled = enabled.value) }
        compose.onNode(trigger).performClick()
        compose.onNodeWithText("First").assertIsDisplayed()
        compose.runOnIdle { enabled.value = false }
        compose.onNodeWithText("First").assertDoesNotExist()
        compose.runOnIdle { enabled.value = true }
        compose.onNodeWithText("First").assertDoesNotExist()
        compose.onNode(trigger).performClick()
        compose.onNodeWithText("First").assertIsDisplayed()
    }

    @Test fun `empty then restored options do not reopen an old menu`() {
        val options = mutableStateOf(listOf("First"))
        render { EsDropdown(null, {}, options.value) }
        compose.onNode(trigger).performClick()
        compose.runOnIdle { options.value = emptyList() }
        compose.onNode(trigger).assertIsNotEnabled()
        compose.runOnIdle { options.value = listOf("First") }
        compose.onNodeWithText("First").assertDoesNotExist()
        compose.onNode(trigger).performClick()
        compose.onNodeWithText("First").assertIsDisplayed()
    }

    @Test fun `option replacement clears hidden search without changing controlled value`() {
        val options = mutableStateOf((1..10).map { "Option $it" })
        val emitted = mutableListOf<String>()
        render { EsDropdown("Stored state", { emitted += it }, options.value) }
        compose.onNode(trigger).performClick()
        compose.onNode(hasSetTextAction()).performTextInput("Option 10")
        compose.runOnIdle { options.value = listOf("Fresh state") }
        compose.onNodeWithText("Fresh state").assertDoesNotExist()
        compose.onNode(trigger).performClick()
        compose.onNode(hasSetTextAction()).assertDoesNotExist()
        compose.onNodeWithText("Fresh state").assertIsDisplayed().performClick()
        compose.onNode(trigger).assertTextContains("Stored state")
        compose.runOnIdle { assertEquals(listOf("Fresh state"), emitted) }
    }

    @Test fun `late menu selection cannot publish after options replacement`() {
        val options = mutableStateOf(listOf("Old state"))
        val emitted = mutableListOf<String>()
        render { EsDropdown(null, { emitted += it }, options.value) }
        compose.onNode(trigger).performClick()
        val late = compose.onNodeWithText("Old state").fetchSemanticsNode().config[SemanticsActions.OnClick].action!!
        compose.runOnIdle { options.value = listOf("Fresh state") }
        compose.runOnIdle { late(); assertTrue(emitted.isEmpty()) }
        compose.onNode(trigger).performClick()
        compose.onNodeWithText("Fresh state").performClick()
        compose.runOnIdle { assertEquals(listOf("Fresh state"), emitted) }
    }

    @Test fun `same option from a retired opening cannot select in a fresh opening`() {
        val emitted = mutableListOf<String>()
        render { EsDropdown(null, { emitted += it }, listOf("Same state")) }
        compose.onNode(trigger).performClick()
        val old = compose.onNodeWithText("Same state").fetchSemanticsNode().config[SemanticsActions.OnClick].action!!
        compose.onNodeWithText("Same state").performClick()
        compose.onNode(trigger).performClick()
        compose.runOnIdle { old(); assertEquals(listOf("Same state"), emitted) }
        compose.onNodeWithText("Same state").performClick()
        compose.runOnIdle { assertEquals(listOf("Same state", "Same state"), emitted) }
    }

    @Test fun `duplicate same frame selection emits once and disposal invalidates callbacks`() {
        val visible = mutableStateOf(true)
        val emitted = mutableListOf<String>()
        render { if (visible.value) EsDropdown(null, { emitted += it }, listOf("Exact & unchanged")) }
        compose.onNode(trigger).performClick()
        val select = compose.onNodeWithText("Exact & unchanged").fetchSemanticsNode().config[SemanticsActions.OnClick].action!!
        compose.runOnIdle { select(); select(); assertEquals(listOf("Exact & unchanged"), emitted) }
        compose.onNode(trigger).performClick()
        val disposed = compose.onNodeWithText("Exact & unchanged").fetchSemanticsNode().config[SemanticsActions.OnClick].action!!
        compose.runOnIdle { visible.value = false }
        compose.runOnIdle { disposed(); assertEquals(listOf("Exact & unchanged"), emitted) }
    }

    @Test fun `observed A B A controlled value never revives the first opening`() {
        val value = mutableStateOf("A")
        val calls = mutableListOf<String>()
        render { EsDropdown(value.value, { calls += it }, listOf("Candidate")) }
        compose.onNode(trigger).performClick()
        val old = compose.onNodeWithText("Candidate").fetchSemanticsNode().config[SemanticsActions.OnClick].action!!
        compose.runOnIdle { value.value = "B" }
        compose.waitForIdle()
        compose.runOnIdle { value.value = "A" }
        compose.onNodeWithText("Candidate").assertDoesNotExist()
        compose.onNode(trigger).performClick()
        compose.runOnIdle { old(); assertTrue(calls.isEmpty()) }
        compose.onNodeWithText("Candidate").performClick()
        compose.runOnIdle { assertEquals(listOf("Candidate"), calls) }
    }

    @Test fun `searchable mode transition retires the query and disabled stale callback`() {
        val searchable = mutableStateOf(true)
        val enabled = mutableStateOf(true)
        val calls = mutableListOf<String>()
        render { EsDropdown(null, { calls += it }, (1..10).map { "Option $it" },
            searchable = searchable.value, enabled = enabled.value) }
        compose.onNode(trigger).performClick()
        compose.onNode(hasSetTextAction()).performTextInput("not found")
        compose.onNodeWithText("No matches").assertIsNotEnabled()
        compose.runOnIdle { searchable.value = false }
        compose.onNodeWithText("No matches").assertDoesNotExist()
        compose.onNode(trigger).performClick()
        val old = compose.onNodeWithText("Option 1").fetchSemanticsNode().config[SemanticsActions.OnClick].action!!
        compose.runOnIdle { enabled.value = false }
        compose.runOnIdle { old(); assertTrue(calls.isEmpty()) }
        compose.runOnIdle { enabled.value = true }
        compose.onNodeWithText("Option 1").assertDoesNotExist()
        compose.onNode(trigger).performClick()
        compose.onNodeWithText("Option 1").performClick()
        compose.runOnIdle { assertEquals(listOf("Option 1"), calls) }
    }

    @Test fun `hardware keyboard opens selects dismisses and returns focus`() {
        val calls = mutableListOf<String>()
        // A new popup gets its input mode from the platform, not the activity's Compose local.
        InstrumentationRegistry.getInstrumentation().setInTouchMode(false)
        render { EsDropdown(null, { calls += it }, listOf("First", "Second"), label = "Service state") }
        compose.runOnIdle { assertTrue(inputMode.requestInputMode(InputMode.Keyboard)) }
        val control = compose.onNode(trigger)
        control.performSemanticsAction(SemanticsActions.RequestFocus) { assertTrue(it()) }
        control.assertIsFocused().performKeyInput { pressKey(Key.Enter) }
        val first = compose.onNodeWithText("First")
        val popupView = (first.fetchSemanticsNode().root as ViewRootForTest).view
        assertNotSame(inputView, popupView)
        assertFalse("Popup has its own keyboard-mode window", popupView.isInTouchMode)
        first.performSemanticsAction(SemanticsActions.RequestFocus) { assertTrue(it()) }
        first.performKeyInput { pressKey(Key.DirectionDown) }
        compose.onNodeWithText("Second").assertIsFocused().performKeyInput { pressKey(Key.DirectionUp) }
        first.assertIsFocused()
        first.performKeyInput { pressKey(Key.Enter) }
        compose.runOnIdle { assertEquals(listOf("First"), calls) }
        control.assertIsFocused().performKeyInput { pressKey(Key.Enter) }
        compose.onNodeWithText("Second").performSemanticsAction(SemanticsActions.RequestFocus) { assertTrue(it()) }
        dismissPopup(compose.onNodeWithText("Second"))
        compose.onNodeWithText("Second").assertDoesNotExist()
        control.assertIsFocused()
    }

    @Test fun `native popup dismissal clears a searched opening before reopening`() {
        val calls = mutableListOf<String>()
        render { EsDropdown(null, { calls += it }, (1..10).map { "Option $it" }) }
        compose.onNode(trigger).performClick()
        compose.onNode(hasSetTextAction()).performTextInput("Option 10")
        compose.onNodeWithText("Option 1", substring = false).assertDoesNotExist()
        dismissPopup(compose.onNode(hasSetTextAction()))
        compose.onNode(hasSetTextAction()).assertDoesNotExist()
        compose.onNode(trigger).performClick()
        compose.onNodeWithText("Option 1", substring = false).assertIsDisplayed().performClick()
        compose.runOnIdle { assertEquals(listOf("Option 1"), calls) }
    }

    @Test fun `password and email preserve baseline native type and disable autocorrect and capitalization`() {
        val type = mutableStateOf(EsFieldType.Password)
        render {
            EsField("", {}, label = "Input", type = type.value, imeAction = ImeAction.Done)
            // Unchanged baseline KeyboardOptions/visual transform. Compare the actual bridge output.
            OutlinedTextField("", {}, label = { Text("Baseline input") }, singleLine = true,
                visualTransformation = if (type.value == EsFieldType.Password) PasswordVisualTransformation() else VisualTransformation.None,
                keyboardOptions = KeyboardOptions(autoCorrectEnabled = false, capitalization = KeyboardCapitalization.None,
                    keyboardType = if (type.value == EsFieldType.Password) KeyboardType.Password else KeyboardType.Email,
                    imeAction = ImeAction.Done))
        }
        val records = mutableListOf<String>()
        listOf(EsFieldType.Password to InputType.TYPE_TEXT_VARIATION_PASSWORD,
            EsFieldType.Email to InputType.TYPE_TEXT_VARIATION_EMAIL_ADDRESS).forEach { (kind, variation) ->
            compose.runOnIdle { type.value = kind }
            val infos = (0..1).map { index ->
                compose.onAllNodes(hasSetTextAction())[index].performClick()
                val info = EditorInfo()
                compose.runOnIdle {
                    assertNotNull("A real Compose input connection must exist", inputView.onCreateInputConnection(info))
                    assertEquals(variation, info.inputType and InputType.TYPE_MASK_VARIATION)
                    assertEquals(0, info.inputType and (InputType.TYPE_TEXT_FLAG_AUTO_CORRECT or
                        InputType.TYPE_TEXT_FLAG_CAP_SENTENCES or InputType.TYPE_TEXT_FLAG_CAP_WORDS or InputType.TYPE_TEXT_FLAG_CAP_CHARACTERS))
                    assertEquals(EditorInfo.IME_ACTION_DONE, info.imeOptions and EditorInfo.IME_MASK_ACTION)
                }
                info
            }
            assertEquals("Preserve baseline bridge flags", infos[1].inputType, infos[0].inputType)
            records += "$kind current=0x${infos[0].inputType.toString(16)} baseline=0x${infos[1].inputType.toString(16)}"
        }
        File("build/reports/ui-inputs-gallery/native-ime-options.txt").apply { checkNotNull(parentFile).mkdirs(); writeText(records.joinToString("\n")) }
    }

    @Test fun `retained native IME action cannot submit after disable and fresh input still submits`() {
        val enabled = mutableStateOf(true)
        val callback = mutableStateOf<() -> Unit>({ error("Old callback must never execute") })
        var calls = 0
        render { EsField("", {}, label = "Final field", enabled = enabled.value, imeAction = ImeAction.Done,
            onImeAction = callback.value) }
        compose.onNode(hasSetTextAction()).performClick()
        val old = compose.runOnIdle { checkNotNull(inputView.onCreateInputConnection(EditorInfo())) }
        compose.runOnIdle { enabled.value = false; callback.value = { calls++ } }
        compose.runOnIdle { old.performEditorAction(EditorInfo.IME_ACTION_DONE) }
        compose.runOnIdle { assertEquals(0, calls); enabled.value = true }
        compose.runOnIdle { assertEquals(0, calls) }
        compose.onNode(hasSetTextAction()).performClick()
        compose.runOnIdle { checkNotNull(inputView.onCreateInputConnection(EditorInfo())).performEditorAction(EditorInfo.IME_ACTION_DONE) }
        compose.runOnIdle { assertEquals(1, calls) }
    }

    @Test fun `outer ETA focus observer and caller ASCII filter keep their contracts`() {
        val value = mutableStateOf("")
        val focus = mutableListOf<Boolean>()
        render {
            EsField(value.value, { value.value = it.filter { char -> char in '0'..'9' } },
                label = "Arrival minutes", type = EsFieldType.Number,
                modifier = Modifier.onFocusChanged { focus += it.isFocused })
            EsField("", {}, label = "Next field")
        }
        val fields = compose.onAllNodes(hasSetTextAction())
        fields[0].performClick().performTextInput("12x३-4")
        compose.runOnIdle { assertEquals("124", value.value); assertTrue(focus.last()) }
        fields[0].performImeAction()
        fields[1].assertIsFocused()
        compose.runOnIdle { assertFalse(focus.last()) }
    }

    @Test @Config(qualifiers = "en-rUS-w640dp-h320dp-land-mdpi")
    fun `short landscape keeps large text fields and searched choices reachable`() {
        val value = mutableStateOf("Monitor service\nRoom 12\nPower cable checked")
        val selected = mutableStateOf<String?>(null)
        val label = "Equipment service request details"
        val error = "Describe all equipment faults before continuing"
        render(scale = 2f) {
            EsField(value.value, { value.value = it }, label = label, error = error, type = EsFieldType.Multiline)
            EsDropdown(selected.value, { selected.value = it }, (1..12).map { "Option $it" }, label = "Service district")
        }
        listOf(label, error).forEach { text ->
            val node = compose.onNodeWithText(text, useUnmergedTree = true).performScrollTo().assertIsDisplayed()
            val area = node.getUnclippedBoundsInRoot()
            val viewport = compose.onRoot().getUnclippedBoundsInRoot()
            assertTrue("Complete copy is reachable by scrolling", area.top >= viewport.top &&
                area.bottom <= viewport.bottom && area.left >= viewport.left && area.right <= viewport.right)
            val layouts = mutableListOf<androidx.compose.ui.text.TextLayoutResult>()
            node.performSemanticsAction(SemanticsActions.GetTextLayoutResult) { it(layouts) }
            val layout = layouts.single()
            assertFalse(layout.didOverflowHeight)
            assertEquals(text.length, layout.getLineEnd(layout.lineCount - 1, visibleEnd = true))
        }
        val control = compose.onNode(trigger).performScrollTo().assertIsDisplayed().assertHeightIsAtLeast(56.dp)
        control.performClick()
        val search = compose.onNode(hasSetTextAction() and hasAnyAncestor(isPopup())).assertIsDisplayed()
        search.performClick().performTextInput("12")
        val option = compose.onNodeWithText("Option 12").assertIsDisplayed()
        val popup = (option.fetchSemanticsNode().root as ViewRootForTest).view
        val searchBounds = search.fetchSemanticsNode().boundsInRoot
        val optionBounds = option.fetchSemanticsNode().boundsInRoot
        assertTrue("Search and chosen option fit the short popup", searchBounds.top >= 0f &&
            searchBounds.bottom <= optionBounds.top && optionBounds.bottom <= popup.height)
        compose.runOnIdle {
            val bitmap = android.graphics.Bitmap.createBitmap(popup.width, popup.height, android.graphics.Bitmap.Config.ARGB_8888)
            try {
                popup.draw(android.graphics.Canvas(bitmap))
                File("build/reports/ui-inputs-gallery/landscape-640dp-2x-popup.png").apply {
                    checkNotNull(parentFile).mkdirs()
                    outputStream().use { bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, it) }
                }
            } finally { bitmap.recycle() }
        }
        option.performClick()
        compose.onNode(isPopup()).assertDoesNotExist()
        compose.runOnIdle { assertEquals("Option 12", selected.value) }
    }

    private fun dismissPopup(node: SemanticsNodeInteraction) {
        // Escape is handled by PopupLayout, above the Compose view targeted by performKeyInput.
        val popup = (node.fetchSemanticsNode().root as ViewRootForTest).view.rootView
        assertNotSame(inputView.rootView, popup)
        compose.runOnIdle {
            val time = SystemClock.uptimeMillis()
            listOf(KeyEvent.ACTION_DOWN, KeyEvent.ACTION_UP).forEach { action ->
                assertTrue("Native popup consumes Escape", popup.dispatchKeyEvent(KeyEvent(time, time, action,
                    KeyEvent.KEYCODE_ESCAPE, 0, 0, -1, 0, 0, InputDevice.SOURCE_KEYBOARD)))
            }
        }
        compose.waitForIdle()
    }

    private fun render(scale: Float = 1f, content: @Composable () -> Unit) {
        host.get().setContent {
            EquipSevaTheme(darkTheme = false) {
                inputView = LocalView.current
                inputMode = LocalInputModeManager.current
                val density = LocalDensity.current
                CompositionLocalProvider(LocalDensity provides Density(density.density, scale)) {
                    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp),
                        verticalArrangement = Arrangement.spacedBy(16.dp)) { content() }
                }
            }
        }
        compose.waitForIdle()
    }
}
