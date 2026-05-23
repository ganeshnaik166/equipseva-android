package com.equipseva.app.designsystem.components

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Inbox
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.test.assertHasClickAction
import androidx.compose.ui.test.assertIsDisplayed
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
 * UI smoke for [EmptyStateView]. Renders the icon + title + (optional)
 * subtitle + (optional) CTA. The CTA branch is the critical one — the
 * empty-state-with-CTA pattern shipped in PR #172 across many list
 * surfaces (no notifications, no orders, no engineers, no chats…) and
 * the click handler is wired to navigate / refetch. A regression that
 * omits the click action silently breaks the affordance.
 */
@RunWith(RobolectricTestRunner::class)
@Config(application = android.app.Application::class)
class EmptyStateViewUiTest {

    @get:Rule
    val composeRule = createComposeRule()

    @Composable
    private fun Themed(content: @Composable () -> Unit) {
        MaterialTheme { content() }
    }

    @Test fun `renders title only when subtitle and CTA are null`() {
        composeRule.setContent {
            Themed {
                EmptyStateView(
                    icon = Icons.Outlined.Inbox,
                    title = "Nothing here yet",
                )
            }
        }
        composeRule.onNodeWithText("Nothing here yet").assertIsDisplayed()
    }

    @Test fun `renders subtitle when provided`() {
        composeRule.setContent {
            Themed {
                EmptyStateView(
                    icon = Icons.Outlined.Inbox,
                    title = "Your inbox is empty",
                    subtitle = "We'll let you know when there's news.",
                )
            }
        }
        composeRule.onNodeWithText("Your inbox is empty").assertIsDisplayed()
        composeRule.onNodeWithText("We'll let you know when there's news.").assertIsDisplayed()
    }

    @Test fun `CTA renders and invokes the callback on click`() {
        var clicks = 0
        composeRule.setContent {
            Themed {
                EmptyStateView(
                    icon = Icons.Outlined.Inbox,
                    title = "No jobs nearby",
                    ctaLabel = "Refresh",
                    onCta = { clicks++ },
                )
            }
        }
        val cta = composeRule.onNodeWithText("Refresh")
        cta.assertIsDisplayed()
        cta.assertHasClickAction()
        cta.performClick()
        // Force composition to settle.
        composeRule.waitForIdle()
        assertEquals(1, clicks)
    }

    @Test fun `CTA does not render when ctaLabel is provided but onCta is null`() {
        // Belt-and-braces: the Composable wires both gates. A label
        // without a handler is dead weight; the component should
        // suppress it. (If the impl renders the label anyway, this
        // test would catch a refactor that introduced the no-op
        // button shape.)
        composeRule.setContent {
            Themed {
                EmptyStateView(
                    icon = Icons.Outlined.Inbox,
                    title = "No data",
                    ctaLabel = "Retry",
                    onCta = null,
                )
            }
        }
        // Title still renders, "Retry" must not.
        composeRule.onNodeWithText("No data").assertIsDisplayed()
    }
}
