package com.equipseva.app.features.kyc

import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import com.equipseva.app.core.data.engineers.VerificationStatus
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Compose UI smoke tests for the three-step KYC timeline. Pure-Kotlin
 * coverage of the (status, submitted) → step-state mapping lives in
 * `KycStatusTimelineRenderTest`; this file pins the user-visible
 * step labels + subtitle copy that actually renders on screen.
 *
 * A regression that drops one of the three steps from the row, or
 * swaps the subtitle for a stale string, gets caught here.
 */
@RunWith(RobolectricTestRunner::class)
@Config(application = android.app.Application::class)
class KycStatusTimelineUiTest {

    @get:Rule
    val composeRule = createComposeRule()

    @Composable
    private fun Themed(content: @Composable () -> Unit) {
        MaterialTheme { content() }
    }

    @Test fun `pending without docs renders the draft subtitle`() {
        composeRule.setContent {
            Themed {
                KycStatusTimeline(status = VerificationStatus.Pending, submitted = false)
            }
        }
        composeRule.onNodeWithText("Submitted").assertIsDisplayed()
        composeRule.onNodeWithText("Under review").assertIsDisplayed()
        composeRule.onNodeWithText("Verified").assertIsDisplayed()
        composeRule.onNodeWithText(
            "Upload documents and submit to start the review.",
        ).assertIsDisplayed()
    }

    @Test fun `pending with docs renders the submitted subtitle`() {
        composeRule.setContent {
            Themed {
                KycStatusTimeline(status = VerificationStatus.Pending, submitted = true)
            }
        }
        composeRule.onNodeWithText(
            "Submitted. A reviewer is checking your documents.",
        ).assertIsDisplayed()
    }

    @Test fun `verified state renders the complete subtitle`() {
        composeRule.setContent {
            Themed {
                KycStatusTimeline(status = VerificationStatus.Verified, submitted = true)
            }
        }
        composeRule.onNodeWithText("Your verification is complete.").assertIsDisplayed()
    }

    @Test fun `rejected state renders the re-upload subtitle`() {
        composeRule.setContent {
            Themed {
                KycStatusTimeline(status = VerificationStatus.Rejected, submitted = true)
            }
        }
        composeRule.onNodeWithText(
            "Your documents were rejected. Re-upload to send it back for review.",
        ).assertIsDisplayed()
    }
}
