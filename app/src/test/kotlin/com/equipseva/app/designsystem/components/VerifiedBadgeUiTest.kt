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
 * UI smoke for [VerifiedBadge]. The badge ships with two size variants
 * (regular + small) but the same "Verified" label and the same
 * green-on-pale-green palette. Pin that both variants surface the
 * label text — a regression that swallowed the label (e.g. swapping
 * to icon-only) would silently drop the affordance from every
 * verified-engineer chip in the directory + KYC banner.
 */
@RunWith(RobolectricTestRunner::class)
@Config(application = android.app.Application::class)
class VerifiedBadgeUiTest {

    @get:Rule
    val composeRule = createComposeRule()

    @Composable
    private fun Themed(content: @Composable () -> Unit) {
        MaterialTheme { content() }
    }

    @Test fun `default variant renders the Verified label`() {
        composeRule.setContent { Themed { VerifiedBadge() } }
        composeRule.onNodeWithText("Verified").assertIsDisplayed()
    }

    @Test fun `small variant renders the Verified label`() {
        composeRule.setContent { Themed { VerifiedBadge(small = true) } }
        composeRule.onNodeWithText("Verified").assertIsDisplayed()
    }
}
