package com.equipseva.app.features.auth

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.assertIsNotSelected
import androidx.compose.ui.test.assertIsSelected
import androidx.compose.ui.test.isSelectable
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import com.equipseva.app.designsystem.theme.EquipSevaTheme
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Behavioural pins for the unwired N01 chooser: three radio options, Continue
 * gated on a choice, Sign in always available, and the callbacks carrying the
 * exact [PublicRegistrationIntent]. No screenshot golden is involved (the
 * Roborazzi gate only scans `designsystem/` previews and the hand-written
 * `*ScreenScreenshotTest` fixtures).
 */
@RunWith(RobolectricTestRunner::class)
@Config(application = android.app.Application::class)
class RegistrationIntentContentUiTest {

    @get:Rule
    val composeRule = createComposeRule()

    private var selectedIntent: PublicRegistrationIntent? = null
    private var continueTaps = 0
    private var signInTaps = 0

    private fun setContent(initial: PublicRegistrationIntent? = null) {
        composeRule.setContent {
            var selected by androidx.compose.runtime.remember { mutableStateOf(initial) }
            EquipSevaTheme(darkTheme = false) {
                RegistrationIntentContent(
                    selected = selected,
                    onSelect = {
                        selected = it
                        selectedIntent = it
                    },
                    onContinue = { continueTaps++ },
                    onSignIn = { signInTaps++ },
                )
            }
        }
    }

    @Test
    fun `renders exactly three selectable purposes with the plan's labels`() {
        setContent()
        composeRule.onAllNodes(isSelectable()).assertCountEquals(3)
        composeRule.onNodeWithText("Biomedical engineer").assertIsNotSelected()
        composeRule.onNodeWithText("Hospital admin").assertIsNotSelected()
        composeRule.onNodeWithText("Engineering team").assertIsNotSelected()
    }

    @Test
    fun `continue stays disabled until a purpose is chosen and then reports the tap`() {
        setContent()
        composeRule.onNodeWithText("Continue").assertIsNotEnabled()
        composeRule.onNodeWithText("Continue").performClick()
        assertEquals(0, continueTaps)

        composeRule.onNodeWithText("Hospital admin").performScrollTo().performClick()
        assertEquals(PublicRegistrationIntent.HOSPITAL, selectedIntent)
        composeRule.onNodeWithText("Hospital admin").assertIsSelected()
        composeRule.onNodeWithText("Biomedical engineer").assertIsNotSelected()

        composeRule.onNodeWithText("Continue").assertIsEnabled()
        composeRule.onNodeWithText("Continue").performClick()
        assertEquals(1, continueTaps)
    }

    @Test
    fun `choosing the team purpose is only a local draft value`() {
        setContent()
        composeRule.onNodeWithText("Engineering team").performScrollTo().performClick()
        assertEquals(PublicRegistrationIntent.ENGINEERING_ORGANISATION, selectedIntent)
        // The stored key is the draft key, never a backend role name.
        assertEquals("engineering_organisation", selectedIntent?.savedKey)
        assertNull(UserRole.entries.firstOrNull { it.name == selectedIntent?.name })
    }

    @Test
    fun `sign in is available before and after a choice`() {
        setContent()
        composeRule.onNodeWithText("Sign in").assertIsEnabled()
        composeRule.onNodeWithText("Sign in").performClick()
        assertEquals(1, signInTaps)
        composeRule.onNodeWithText("Biomedical engineer").performScrollTo().performClick()
        composeRule.onNodeWithText("Sign in").performClick()
        assertEquals(2, signInTaps)
    }

    @Test
    fun `a restored choice renders selected`() {
        setContent(initial = PublicRegistrationIntent.BIOMEDICAL_ENGINEER)
        composeRule.onNodeWithText("Biomedical engineer").assertIsSelected()
        composeRule.onNodeWithText("Continue").assertIsEnabled()
    }
}
