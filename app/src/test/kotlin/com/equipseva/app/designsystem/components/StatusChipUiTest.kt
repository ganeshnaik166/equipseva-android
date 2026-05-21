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
 * Compose UI tests for [StatusChip] — verifies the label string
 * survives recomposition under each StatusTone (so a future "wrap the
 * label in an icon-only Box" refactor that hides the text gets
 * caught). Tone → Color mapping lives in MaterialTheme.colorScheme
 * and isn't asserted here — that's a pixel concern.
 *
 * Composables here are wrapped in MaterialTheme because StatusChip
 * reads `MaterialTheme.colorScheme` for tone colours; without the
 * provider the test would crash on first paint.
 */
@RunWith(RobolectricTestRunner::class)
@Config(application = android.app.Application::class)
class StatusChipUiTest {

    @get:Rule
    val composeRule = createComposeRule()

    @Composable
    private fun Themed(content: @Composable () -> Unit) {
        MaterialTheme { content() }
    }

    @Test fun `neutral tone shows label`() {
        composeRule.setContent {
            Themed { StatusChip(label = "Pending review", tone = StatusTone.Neutral) }
        }
        composeRule.onNodeWithText("Pending review").assertIsDisplayed()
    }

    @Test fun `success tone shows label`() {
        composeRule.setContent {
            Themed { StatusChip(label = "Verified", tone = StatusTone.Success) }
        }
        composeRule.onNodeWithText("Verified").assertIsDisplayed()
    }

    @Test fun `danger tone shows label`() {
        composeRule.setContent {
            Themed { StatusChip(label = "Rejected", tone = StatusTone.Danger) }
        }
        composeRule.onNodeWithText("Rejected").assertIsDisplayed()
    }

    @Test fun `warn tone shows label`() {
        composeRule.setContent {
            Themed { StatusChip(label = "Awaiting", tone = StatusTone.Warn) }
        }
        composeRule.onNodeWithText("Awaiting").assertIsDisplayed()
    }

    @Test fun `info tone shows label`() {
        composeRule.setContent {
            Themed { StatusChip(label = "New", tone = StatusTone.Info) }
        }
        composeRule.onNodeWithText("New").assertIsDisplayed()
    }
}
