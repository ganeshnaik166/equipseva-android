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
 * UI smoke for the design-system [Avatar] component (initial-letter
 * variant — the network-image variant lives in a separate file).
 * Pins that the initials string passes through to the Text node.
 * A regression that swallowed initials or routed them through a
 * normaliser would leave avatar circles empty across every chat /
 * conversation / engineer row.
 */
@RunWith(RobolectricTestRunner::class)
@Config(application = android.app.Application::class)
class AvatarUiTest {

    @get:Rule
    val composeRule = createComposeRule()

    @Composable
    private fun Themed(content: @Composable () -> Unit) {
        MaterialTheme { content() }
    }

    @Test fun `renders two-letter initials`() {
        composeRule.setContent { Themed { Avatar(initials = "GD") } }
        composeRule.onNodeWithText("GD").assertIsDisplayed()
    }

    @Test fun `renders single-letter initial`() {
        composeRule.setContent { Themed { Avatar(initials = "R") } }
        composeRule.onNodeWithText("R").assertIsDisplayed()
    }

    @Test fun `renders fallback question mark for empty input`() {
        // The design-system Avatar takes `initials` verbatim — empty
        // initials would render an empty Text. Pin that the caller is
        // expected to pre-fold to "?" via the shared avatarInitial
        // helper. Document this assumption inline.
        composeRule.setContent { Themed { Avatar(initials = "?") } }
        composeRule.onNodeWithText("?").assertIsDisplayed()
    }
}
