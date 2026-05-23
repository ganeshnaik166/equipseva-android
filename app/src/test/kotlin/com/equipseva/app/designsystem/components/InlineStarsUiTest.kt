package com.equipseva.app.designsystem.components

import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * UI smoke for [InlineStars]. Pins the user-visible rating + count
 * strings:
 *
 *  * Rating formatted to 1 decimal via Locale.US ("4.5", not "4,5") —
 *    a comma-decimal locale slipping through would render the rating
 *    as a list, breaking the directory chip everywhere.
 *  * Count rendered in parentheses ("(127)").
 *
 * Star icon is decorative (contentDescription = null) so we don't
 * assert on it.
 */
@RunWith(RobolectricTestRunner::class)
@Config(application = android.app.Application::class)
class InlineStarsUiTest {

    @get:Rule
    val composeRule = createComposeRule()

    @Composable
    private fun Themed(content: @Composable () -> Unit) {
        MaterialTheme { content() }
    }

    @Test fun `renders rating with one decimal place`() {
        composeRule.setContent { Themed { InlineStars(rating = 4.5, count = 12) } }
        composeRule.onNodeWithText("4.5").assertIsDisplayed()
    }

    @Test fun `renders rating with trailing zero when whole`() {
        // 4.0 → "4.0" not "4". The %.1f format always emits one
        // decimal, which is the contract we want for visual alignment
        // across rows.
        composeRule.setContent { Themed { InlineStars(rating = 4.0, count = 1) } }
        composeRule.onNodeWithText("4.0").assertIsDisplayed()
    }

    @Test fun `renders count in parentheses`() {
        composeRule.setContent { Themed { InlineStars(rating = 4.8, count = 127) } }
        composeRule.onNodeWithText("(127)").assertIsDisplayed()
    }

    @Test fun `zero count renders as parens-zero`() {
        composeRule.setContent { Themed { InlineStars(rating = 0.0, count = 0) } }
        composeRule.onNodeWithText("(0)").assertIsDisplayed()
        composeRule.onNodeWithText("0.0").assertIsDisplayed()
    }

    @Test fun `small variant still renders the same strings`() {
        composeRule.setContent { Themed { InlineStars(rating = 3.7, count = 42, small = true) } }
        composeRule.onNodeWithText("3.7").assertIsDisplayed()
        composeRule.onNodeWithText("(42)").assertIsDisplayed()
    }
}
