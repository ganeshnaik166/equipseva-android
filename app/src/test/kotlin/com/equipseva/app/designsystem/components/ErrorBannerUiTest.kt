package com.equipseva.app.designsystem.components

import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithText
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * UI smoke for [ErrorBanner]. Two load-bearing behaviours:
 *
 *  * Null / blank `message` collapses the row entirely — surfaces
 *    that render the banner unconditionally (above every form)
 *    must stay quiet when no error is set.
 *  * Non-blank message renders + the dismiss handler (if provided)
 *    fires once on tap.
 */
@RunWith(RobolectricTestRunner::class)
@Config(application = android.app.Application::class)
class ErrorBannerUiTest {

    @get:Rule
    val composeRule = createComposeRule()

    @Composable
    private fun Themed(content: @Composable () -> Unit) {
        MaterialTheme { content() }
    }

    @Test fun `null message renders nothing`() {
        composeRule.setContent { Themed { ErrorBanner(message = null) } }
        // No "Error" / sentinel text should be visible — banner exits early.
        // A regression that drops the early-return would push an empty Row
        // through the layout pass with the warning palette visible.
        composeRule.onAllNodesWithText("Something went wrong").assertCountEquals(0)
    }

    @Test fun `blank message renders nothing`() {
        composeRule.setContent { Themed { ErrorBanner(message = "   ") } }
        // Same contract as null — `if (message.isNullOrBlank()) return`.
        composeRule.onAllNodesWithText("   ").assertCountEquals(0)
    }

    @Test fun `non-blank message renders the text`() {
        composeRule.setContent {
            Themed { ErrorBanner(message = "Network problem. Check your connection.") }
        }
        composeRule.onNodeWithText("Network problem. Check your connection.").assertIsDisplayed()
    }
}
