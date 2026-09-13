package com.equipseva.app.designsystem.components

import android.app.Application
import android.view.View
import android.view.KeyEvent
import android.os.SystemClock
import android.text.InputType
import android.view.inputmethod.EditorInfo
import androidx.activity.ComponentActivity
import androidx.activity.findViewTreeOnBackPressedDispatcherOwner
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.platform.ViewRootForTest
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.compose.ui.unit.dp
import androidx.test.core.app.ApplicationProvider
import com.equipseva.app.R
import com.equipseva.app.designsystem.theme.EquipSevaTheme
import com.equipseva.app.features.kyc.EmailVerifySheet
import com.equipseva.app.testing.IsolatedUiPackageParser
import com.equipseva.app.testing.IsolatedUiTestRunner
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

/** Synthetic field and actual KYC sheet contracts; no account or provider execution. */
@RunWith(IsolatedUiTestRunner::class)
@Config(application = Application::class, sdk = [34], shadows = [IsolatedUiPackageParser::class],
    qualifiers = "en-rUS-w320dp-h800dp-mdpi")
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@OptIn(ExperimentalTestApi::class)
class OtpRenewalContractTest {
    @get:Rule val compose = createEmptyComposeRule()
    private lateinit var host: ActivityController<ComponentActivity>
    private lateinit var inputView: View
    private var initialScale = 1f
    private val app: Application get() = ApplicationProvider.getApplicationContext()
    private val editable = SemanticsMatcher.keyIsDefined(SemanticsProperties.EditableText)

    @Before fun open() {
        IsolatedUiPackageParser.assertIsolated(app)
        initialScale = RuntimeEnvironment.getFontScale()
    }
    @After fun close() {
        try { if (::host.isInitialized) host.pause().stop().destroy() }
        finally { RuntimeEnvironment.setFontScale(initialScale) }
    }

    @Test fun `one visible named editor grows to the input minimum`() {
        render { OtpDigitField("12", {}) }
        compose.onAllNodes(hasSetTextAction()).assertCountEquals(1)
        compose.onNode(hasSetTextAction()).assertIsDisplayed().assertHeightIsAtLeast(56.dp)
            .assert(hasContentDescription("6-digit code") or hasText("6-digit code"))
    }

    @Test fun `ASCII filtering matches the live KYC contract and preserves leading zero`() {
        var changed = ""
        render { OtpDigitField("", { changed = it }) }
        compose.onNode(hasSetTextAction()).performTextInput("०01２23x456789")
        compose.runOnIdle { assertEquals("012345", changed) }
    }

    @Test fun `entered count reflects rendered capacity instead of excess caller text`() {
        render { OtpDigitField("123456789", {}) }
        compose.onNode(hasSetTextAction()).assert(
            SemanticsMatcher.expectValue(SemanticsProperties.StateDescription, "6 of 6 digits entered"))
    }

    @Test @Config(qualifiers = "hi-rIN-w320dp-h800dp-mdpi")
    fun `Hindi editor has a localized persistent name`() {
        render { OtpDigitField("12", {}) }
        compose.onNode(hasSetTextAction()).assertHasClickAction()
            .assert(hasContentDescription("6-अंकों का कोड") or hasText("6-अंकों का कोड"))
    }

    @Test fun `decorative digits do not create duplicate text stops`() {
        render { OtpDigitField("123", {}) }
        compose.onAllNodes(hasText("1"), useUnmergedTree = true).assertCountEquals(0)
        val descriptions = compose.onNode(hasSetTextAction()).fetchSemanticsNode().config
            .getOrElse(SemanticsProperties.ContentDescription) { emptyList() }
        assertFalse(descriptions.any { it.contains("123") })
    }

    @Test fun `exact optional error is attached to the visible editor`() {
        val error = mutableStateOf<String?>("Wrong code. Try again.")
        render { OtpDigitField("12", {}, error = error.value) }
        compose.onNode(hasSetTextAction()).assertIsDisplayed()
            .assert(SemanticsMatcher.expectValue(SemanticsProperties.Error, error.value!!))
        compose.runOnIdle { error.value = null }
        compose.onNode(hasSetTextAction()).assert(SemanticsMatcher.keyNotDefined(SemanticsProperties.Error))
    }

    @Test fun `sending sheet does not claim the code has already been sent`() {
        render { EmailVerifySheet("care@example.test", "", true, false, {}, {}, {}, {}) }
        compose.onNodeWithText(app.getString(R.string.kyc_email_code_sent, "care@example.test")).assertDoesNotExist()
        compose.onNode(hasSetTextAction()).assertIsDisplayed()
    }

    @Test fun `native connection supports replacement middle edits deletion and leading zeros`() {
        val code = mutableStateOf("")
        var submissions = 0
        render { OtpDigitField(code.value, { code.value = it }, onImeAction = { submissions++ }) }
        compose.onNode(editable).performClick()
        val info = EditorInfo()
        val connection = compose.runOnIdle { requireNotNull(inputView.onCreateInputConnection(info)) }
        assertEquals(InputType.TYPE_CLASS_NUMBER, info.inputType and InputType.TYPE_MASK_CLASS)
        assertEquals(InputType.TYPE_NUMBER_VARIATION_PASSWORD, info.inputType and InputType.TYPE_MASK_VARIATION)
        assertEquals(EditorInfo.IME_ACTION_DONE, info.imeOptions and EditorInfo.IME_MASK_ACTION)
        fun edit(expected: String, operation: () -> Unit) {
            compose.runOnIdle(operation)
            compose.runOnIdle { assertEquals(expected, code.value); assertEquals(0, submissions) }
        }
        edit("001234") { connection.commitText("001234", 1) }
        edit("008734") { connection.setSelection(2, 4); connection.commitText("87", 1) }
        edit("00734") { connection.setSelection(3, 3); connection.deleteSurroundingText(1, 0) }
        edit("006734") { connection.commitText("6", 1) }
        edit("98") { connection.setSelection(0, 6); connection.commitText("१२9a8", 1) }
        edit("") { connection.deleteSurroundingText(2, 0) }
    }

    @Test fun `old editor action reads latest code callback and enabled state`() {
        val code = mutableStateOf("12345")
        val enabled = mutableStateOf(true)
        val callbackName = mutableStateOf("old")
        val calls = mutableListOf<String>()
        render {
            val name = callbackName.value
            OtpDigitField(code.value, { code.value = it }, enabled = enabled.value,
                onImeAction = { calls += name })
        }
        compose.onNode(editable).performClick()
        val oldConnection = compose.runOnIdle { requireNotNull(inputView.onCreateInputConnection(EditorInfo())) }
        compose.runOnIdle { oldConnection.performEditorAction(EditorInfo.IME_ACTION_DONE) }
        compose.runOnIdle { assertTrue(calls.isEmpty()); code.value = "001234"; callbackName.value = "new" }
        compose.runOnIdle { assertTrue("External value changes do not submit", calls.isEmpty()) }
        compose.runOnIdle { oldConnection.performEditorAction(EditorInfo.IME_ACTION_DONE) }
        compose.runOnIdle { assertEquals(listOf("new"), calls); enabled.value = false }
        compose.runOnIdle {
            oldConnection.performEditorAction(EditorInfo.IME_ACTION_DONE)
            oldConnection.commitText("9", 1)
        }
        compose.runOnIdle { assertEquals(listOf("new"), calls); assertEquals("001234", code.value); enabled.value = true }
        compose.onNode(editable).performClick().performImeAction()
        compose.runOnIdle { assertEquals(listOf("new", "new"), calls) }
    }

    @Test fun `disposed input cannot edit or submit and a fresh editor still works`() {
        val shown = mutableStateOf(true)
        val code = mutableStateOf("001234")
        var submissions = 0
        render { if (shown.value) OtpDigitField(code.value, { code.value = it }, onImeAction = { submissions++ }) }
        compose.onNode(editable).performClick()
        val connection = compose.runOnIdle { requireNotNull(inputView.onCreateInputConnection(EditorInfo())) }
        compose.runOnIdle { shown.value = false }
        compose.runOnIdle { connection.commitText("9", 1); connection.performEditorAction(EditorInfo.IME_ACTION_DONE) }
        compose.runOnIdle { assertEquals("001234", code.value); assertEquals(0, submissions); shown.value = true }
        compose.onNode(editable).performClick().performImeAction()
        compose.runOnIdle { assertEquals(1, submissions) }
    }

    @Test fun `excess controlled value is not silently submitted as a truncated code`() {
        var submissions = 0
        render { OtpDigitField("0012349", {}, onImeAction = { submissions++ }) }
        compose.onNode(editable).performClick().performImeAction()
        compose.runOnIdle { assertEquals(0, submissions) }
    }

    @Test fun `sheet callbacks retire on email change and removal and refresh within one email`() {
        val shown = mutableStateOf(true)
        val email = mutableStateOf("a@example.test")
        val generation = mutableStateOf("first")
        val calls = mutableListOf<String>()
        render {
            val current = generation.value
            if (shown.value) EmailVerifySheet(email.value, "001234", false, false, {},
                { calls += "verify-$current" }, { calls += "close-$current" }, { calls += "resend-$current" })
        }
        val verify = button(R.string.kyc_verify_action).fetchSemanticsNode().config[SemanticsActions.OnClick].action!!
        val resend = button(R.string.kyc_email_resend_code).fetchSemanticsNode().config[SemanticsActions.OnClick].action!!
        val close = button(R.string.otp_close).fetchSemanticsNode().config[SemanticsActions.OnClick].action!!
        compose.runOnIdle { generation.value = "latest" }
        compose.runOnIdle { verify() }
        compose.runOnIdle { assertEquals(listOf("verify-latest"), calls); calls.clear(); email.value = "b@example.test" }
        compose.runOnIdle { verify(); resend(); close() }
        compose.runOnIdle { assertTrue(calls.isEmpty()) }
        button(R.string.kyc_verify_action).performClick()
        val newClose = button(R.string.otp_close).fetchSemanticsNode().config[SemanticsActions.OnClick].action!!
        compose.runOnIdle { assertEquals(listOf("verify-latest"), calls); calls.clear(); shown.value = false }
        compose.runOnIdle { newClose() }
        compose.runOnIdle { assertTrue(calls.isEmpty()); shown.value = true }
        button(R.string.otp_close).performClick()
        compose.runOnIdle { assertEquals(listOf("close-latest"), calls) }
    }

    @Test fun `sheet renders and announces the exact retry error while retaining code`() {
        val failure = "Code expired. Request a new code."
        render { EmailVerifySheet("a@example.test", "001234", false, false, {}, {}, {}, {}, error = failure) }
        compose.onNode(editable).assertTextContains("001234")
            .assert(SemanticsMatcher.expectValue(SemanticsProperties.Error, failure))
        compose.onNodeWithText(failure, useUnmergedTree = true).assertIsDisplayed()
            .assert(SemanticsMatcher.expectValue(SemanticsProperties.LiveRegion, androidx.compose.ui.semantics.LiveRegionMode.Polite))
        button(R.string.kyc_verify_action).assertIsEnabled()
        button(R.string.kyc_email_resend_code).assertIsEnabled()
    }

    @Test fun `sending blocks current and retained submit actions but keeps edit close and fresh verify`() {
        val sending = mutableStateOf(false)
        val code = mutableStateOf("001234")
        var submissions = 0
        var dismissed = 0
        render { EmailVerifySheet("a@example.test", code.value, sending.value, false,
            { code.value = it }, { submissions++ }, { dismissed++ }, {}) }
        val retainedVerify = button(R.string.kyc_verify_action).fetchSemanticsNode().config[SemanticsActions.OnClick].action!!
        compose.onNode(editable).performClick()
        val modalView = (compose.onNode(editable).fetchSemanticsNode().root as ViewRootForTest).view
        val connection = compose.runOnIdle { requireNotNull(modalView.onCreateInputConnection(EditorInfo())) }
        compose.runOnIdle { sending.value = true }
        compose.runOnIdle { retainedVerify(); connection.performEditorAction(EditorInfo.IME_ACTION_DONE) }
        compose.runOnIdle { assertEquals("Neither entry point submits while sending", 0, submissions) }
        button(R.string.kyc_verify_action).assertIsNotEnabled()
        button(R.string.otp_close).assertIsEnabled().performClick()
        compose.onNode(editable).assertIsEnabled().performTextReplacement("009876")
        compose.runOnIdle { assertEquals(1, dismissed); assertEquals("009876", code.value); sending.value = false }
        button(R.string.kyc_verify_action).assertIsEnabled().performClick()
        compose.runOnIdle { assertEquals(1, submissions) }
    }

    @Test @Config(sdk = [32])
    fun `native back cannot hide a verifying sheet and dismisses once ready`() {
        val verifying = mutableStateOf(false)
        val shown = mutableStateOf(true)
        var dismissed = 0
        render { if (shown.value) EmailVerifySheet("a@example.test", "001234", false, verifying.value,
            {}, {}, { dismissed++; shown.value = false }, {}) }
        val dialog = requireNotNull(ShadowDialog.getLatestDialog())
        assertTrue(dialog.isShowing)
        assertNotSame(host.get().window.decorView, dialog.window!!.decorView)
        val modalView = (compose.onNode(editable).fetchSemanticsNode().root as ViewRootForTest).view
        assertSame("Back belongs to the modal dialog", dialog, modalView.findViewTreeOnBackPressedDispatcherOwner())
        compose.onNode(editable).assertIsDisplayed().assertTextContains("001234")
        compose.runOnIdle { verifying.value = true }
        compose.onNode(editable).assertIsDisplayed().assertTextContains("001234")
        assertSame(dialog, ShadowDialog.getLatestDialog())
        nativeBack(dialog)
        compose.onNode(editable).assertIsDisplayed().assertTextContains("001234")
        compose.runOnIdle { assertEquals(0, dismissed); assertTrue(dialog.isShowing); verifying.value = false }
        nativeBack(dialog)
        compose.runOnIdle { assertEquals(1, dismissed); assertFalse(dialog.isShowing) }
    }

    private fun nativeBack(dialog: android.app.Dialog) {
        compose.runOnIdle {
            val now = SystemClock.uptimeMillis()
            listOf(KeyEvent.ACTION_DOWN, KeyEvent.ACTION_UP).forEach { action ->
                dialog.dispatchKeyEvent(KeyEvent(now, now, action, KeyEvent.KEYCODE_BACK, 0))
            }
        }
        compose.mainClock.advanceTimeBy(800)
        compose.waitForIdle()
    }

    private fun button(resource: Int) = compose.onNode(hasText(app.getString(resource)) and
        SemanticsMatcher.expectValue(SemanticsProperties.Role, Role.Button))

    private fun render(scale: Float = 1f, dark: Boolean = false, content: @Composable () -> Unit) {
        RuntimeEnvironment.setFontScale(scale)
        host = Robolectric.buildActivity(ComponentActivity::class.java).setup().visible()
        host.get().setContent {
            inputView = LocalView.current
            EquipSevaTheme(darkTheme = dark) {
                Column(Modifier.fillMaxSize().padding(16.dp)) { content() }
            }
        }
        compose.waitForIdle()
    }
}
