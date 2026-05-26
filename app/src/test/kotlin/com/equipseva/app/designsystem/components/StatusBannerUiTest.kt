package com.equipseva.app.designsystem.components

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Info
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.createComposeRule
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * UI smoke for [StatusBanner]. Pin the contract callers depend on:
 *  - title always renders
 *  - optional message renders only when non-null
 *  - optional action slot is invoked exactly once (so its content
 *    surfaces in the composition tree)
 *
 * Tone-based colour swaps live in design tokens and aren't tested
 * here — semantics tree doesn't carry the bg/fg colour, and pinning
 * exact RGB values would just track the theme.
 */
@RunWith(RobolectricTestRunner::class)
@Config(application = android.app.Application::class)
class StatusBannerUiTest {

    @get:Rule val composeRule = createComposeRule()

    @Composable
    private fun Themed(content: @Composable () -> Unit) {
        MaterialTheme { content() }
    }

    @Test fun `title renders`() {
        composeRule.setContent {
            Themed { StatusBanner(title = "KYC under review") }
        }
        composeRule.onNode(hasText("KYC under review")).assertIsDisplayed()
    }

    @Test fun `message renders when supplied`() {
        composeRule.setContent {
            Themed {
                StatusBanner(
                    title = "KYC under review",
                    message = "Engineers see your profile after we verify.",
                )
            }
        }
        composeRule.onNode(hasText("Engineers see your profile after we verify.")).assertIsDisplayed()
    }

    @Test fun `message slot is absent when message is null`() {
        composeRule.setContent {
            Themed { StatusBanner(title = "KYC under review", message = null) }
        }
        composeRule.onAllNodes(hasText("Engineers see your profile after we verify."))
            .assertCountEquals(0)
    }

    @Test fun `action slot content surfaces in the composition`() {
        composeRule.setContent {
            Themed {
                StatusBanner(
                    title = "KYC under review",
                    action = { Text("Retry") },
                )
            }
        }
        composeRule.onNode(hasText("Retry")).assertIsDisplayed()
    }

    @Test fun `Brand tone with leading icon still renders the title`() {
        composeRule.setContent {
            Themed {
                StatusBanner(
                    title = "Brand tone smoke",
                    tone = StatusBannerTone.Brand,
                    leadingIcon = Icons.Filled.Info,
                )
            }
        }
        composeRule.onNode(hasText("Brand tone smoke")).assertIsDisplayed()
    }
}
