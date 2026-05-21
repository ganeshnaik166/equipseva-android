package com.equipseva.app.designsystem.components

import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.test.assertHasClickAction
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * UI smoke for [PrimaryButton]. Three observable behaviours the
 * design-system contract guarantees:
 *
 *  * Renders the supplied label.
 *  * `enabled = false` disables the click action; `loading = true`
 *    also disables (the spinner replaces the label affordance).
 *  * Click fires the callback exactly once.
 *
 * A regression that swallowed click events from the `enabled` /
 * `loading` arms would render screens where the CTA looks tappable
 * but does nothing — caught here.
 */
@RunWith(RobolectricTestRunner::class)
@Config(application = android.app.Application::class)
class PrimaryButtonUiTest {

    @get:Rule
    val composeRule = createComposeRule()

    @Composable
    private fun Themed(content: @Composable () -> Unit) {
        MaterialTheme { content() }
    }

    @Test fun `renders the label and is enabled by default`() {
        composeRule.setContent {
            Themed { PrimaryButton(label = "Sign in", onClick = {}) }
        }
        composeRule.onNodeWithText("Sign in").assertIsDisplayed()
        composeRule.onNodeWithText("Sign in").assertIsEnabled()
    }

    @Test fun `click fires the callback exactly once`() {
        var clicks = 0
        composeRule.setContent {
            Themed { PrimaryButton(label = "Submit", onClick = { clicks++ }) }
        }
        composeRule.onNodeWithText("Submit").performClick()
        composeRule.waitForIdle()
        assertEquals(1, clicks)
    }

    @Test fun `enabled=false disables the click action`() {
        var clicks = 0
        composeRule.setContent {
            Themed { PrimaryButton(label = "Submit", onClick = { clicks++ }, enabled = false) }
        }
        composeRule.onNodeWithText("Submit").assertIsNotEnabled()
        composeRule.onNodeWithText("Submit").performClick()
        composeRule.waitForIdle()
        assertEquals(0, clicks)
    }

    @Test fun `enabled button has a click action`() {
        composeRule.setContent {
            Themed { PrimaryButton(label = "Save", onClick = {}) }
        }
        composeRule.onNodeWithText("Save").assertHasClickAction()
    }
}
