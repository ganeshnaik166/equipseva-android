package com.equipseva.app.designsystem.components

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.test.assertHeightIsAtLeast
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertWidthIsAtLeast
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.unit.dp
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Pins the 48 dp interactive floor on the two shared controls that carried
 * the app's most-used small targets:
 *
 *  - [EsChip] — every filter / specialization / brand / urgency pill across
 *    a dozen screens painted a 32 dp row with no touch inflation.
 *  - [EsSection]'s trailing action — the "See all" link was a bare 13 sp
 *    label, roughly 17 dp tall.
 *
 * Both are measured at the default font scale: the point is the reserved
 * interactive box, not text growth. The pill's own paint is unchanged, so a
 * regression that removed the reservation would leave the component looking
 * identical and only this test would notice.
 */
@RunWith(RobolectricTestRunner::class)
@Config(application = android.app.Application::class)
class SharedChromeTouchTargetTest {

    @get:Rule
    val composeRule = createComposeRule()

    @Composable
    private fun Themed(content: @Composable () -> Unit) {
        MaterialTheme { Box(Modifier.fillMaxSize()) { content() } }
    }

    @Test fun `clickable chip reserves the 48dp interactive minimum`() {
        composeRule.setContent { Themed { EsChip(text = "Queued", onClick = {}) } }
        composeRule.onNodeWithContentDescription("Queued")
            .assertHeightIsAtLeast(48.dp)
            .assertWidthIsAtLeast(48.dp)
    }

    @Test fun `active chip reserves the same minimum as an inactive one`() {
        composeRule.setContent {
            Themed { EsChip(text = "Queued", active = true, onClick = {}) }
        }
        composeRule.onNodeWithContentDescription("Queued").assertHeightIsAtLeast(48.dp)
    }

    @Test fun `section trailing action reserves the 48dp interactive minimum`() {
        composeRule.setContent {
            Themed {
                EsSection(title = "Recent activity", action = "See all", onAction = {}) {}
            }
        }
        composeRule.onNodeWithText("See all")
            .assertHeightIsAtLeast(48.dp)
            .assertWidthIsAtLeast(48.dp)
    }

    @Test fun `section title still renders alongside the grown action`() {
        // The action's growth changed the header row's vertical alignment;
        // guard against a layout change that pushed the title out of view.
        composeRule.setContent {
            Themed {
                EsSection(title = "Recent activity", action = "See all", onAction = {}) {}
            }
        }
        composeRule.onNodeWithText("Recent activity").assertIsDisplayed()
    }
}
