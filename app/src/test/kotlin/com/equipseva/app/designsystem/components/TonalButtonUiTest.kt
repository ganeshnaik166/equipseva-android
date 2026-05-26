package com.equipseva.app.designsystem.components

import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.performClick
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * UI smoke for [TonalButton]. Pin the click + enabled-state contract;
 * caller-visible side effects depend on both behaving correctly.
 */
@RunWith(RobolectricTestRunner::class)
@Config(application = android.app.Application::class)
class TonalButtonUiTest {

    @get:Rule val composeRule = createComposeRule()

    @Composable
    private fun Themed(content: @Composable () -> Unit) {
        MaterialTheme { content() }
    }

    @Test fun `label renders`() {
        composeRule.setContent {
            Themed { TonalButton(label = "Continue", onClick = {}) }
        }
        composeRule.onNode(hasText("Continue")).assertIsDisplayed()
    }

    @Test fun `click invokes onClick exactly once`() {
        var clicks = 0
        composeRule.setContent {
            Themed { TonalButton(label = "Continue", onClick = { clicks++ }) }
        }
        composeRule.onNode(hasText("Continue")).performClick()
        assertEquals(1, clicks)
    }

    @Test fun `default is enabled`() {
        composeRule.setContent {
            Themed { TonalButton(label = "Continue", onClick = {}) }
        }
        composeRule.onNode(hasText("Continue")).assertIsEnabled()
    }

    @Test fun `enabled=false renders disabled and swallows clicks`() {
        var clicks = 0
        composeRule.setContent {
            Themed {
                TonalButton(
                    label = "Continue",
                    onClick = { clicks++ },
                    enabled = false,
                )
            }
        }
        composeRule.onNode(hasText("Continue")).assertIsNotEnabled()
        // performClick on a disabled button: framework still dispatches the
        // gesture but Material's Button blocks the onClick callback. Pin
        // the contract — no callbacks while disabled.
        runCatching { composeRule.onNode(hasText("Continue")).performClick() }
        assertEquals(0, clicks)
    }

}
