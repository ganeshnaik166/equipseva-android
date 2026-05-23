package com.equipseva.app.designsystem.components

import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import com.equipseva.app.core.data.repair.RepairJobUrgency
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * UI smoke for [UrgencyPill]. Pins the four user-visible urgency labels
 * surfaced on every repair-job card + the detail screen. The
 * `Unknown` fallback maps to "Standard" — a UX choice to soften the
 * label when the server-side enum carries a value the client can't
 * resolve. Caught here so a future tightening (rename to "Unknown" /
 * hide entirely) is intentional.
 */
@RunWith(RobolectricTestRunner::class)
@Config(application = android.app.Application::class)
class UrgencyPillUiTest {

    @get:Rule
    val composeRule = createComposeRule()

    @Composable
    private fun Themed(content: @Composable () -> Unit) {
        MaterialTheme { content() }
    }

    @Test fun `Emergency urgency renders Emergency label`() {
        composeRule.setContent { Themed { UrgencyPill(RepairJobUrgency.Emergency) } }
        composeRule.onNodeWithText("Emergency").assertIsDisplayed()
    }

    @Test fun `SameDay urgency renders Same day label`() {
        composeRule.setContent { Themed { UrgencyPill(RepairJobUrgency.SameDay) } }
        composeRule.onNodeWithText("Same day").assertIsDisplayed()
    }

    @Test fun `Scheduled urgency renders Scheduled label`() {
        composeRule.setContent { Themed { UrgencyPill(RepairJobUrgency.Scheduled) } }
        composeRule.onNodeWithText("Scheduled").assertIsDisplayed()
    }

    @Test fun `Unknown urgency renders Standard fallback label`() {
        composeRule.setContent { Themed { UrgencyPill(RepairJobUrgency.Unknown) } }
        composeRule.onNodeWithText("Standard").assertIsDisplayed()
    }
}
