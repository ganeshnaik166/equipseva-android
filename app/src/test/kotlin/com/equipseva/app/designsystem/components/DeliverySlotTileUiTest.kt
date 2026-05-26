package com.equipseva.app.designsystem.components

import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.performClick
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * UI smoke for [DeliverySlotTile] (salvaged in #981). Checkout uses
 * one of these per slot; pin label rendering + tap delivery.
 */
@RunWith(RobolectricTestRunner::class)
@Config(application = android.app.Application::class)
class DeliverySlotTileUiTest {

    @get:Rule val composeRule = createComposeRule()

    @Composable
    private fun Themed(content: @Composable () -> Unit) {
        MaterialTheme { content() }
    }

    @Test fun `date and time-range render`() {
        composeRule.setContent {
            Themed {
                DeliverySlotTile(
                    date = "Sat, 31 May",
                    timeRange = "10am – 12pm",
                    selected = false,
                    onSelect = {},
                )
            }
        }
        composeRule.onNode(hasText("Sat, 31 May")).assertIsDisplayed()
        composeRule.onNode(hasText("10am – 12pm")).assertIsDisplayed()
    }

    @Test fun `tap invokes onSelect once`() {
        var picks = 0
        composeRule.setContent {
            Themed {
                DeliverySlotTile(
                    date = "Sat, 31 May",
                    timeRange = "10am – 12pm",
                    selected = false,
                    onSelect = { picks++ },
                )
            }
        }
        composeRule.onNode(hasText("Sat, 31 May")).performClick()
        assertEquals(1, picks)
    }

    @Test fun `selected state still renders labels`() {
        composeRule.setContent {
            Themed {
                DeliverySlotTile(
                    date = "Sat, 31 May",
                    timeRange = "10am – 12pm",
                    selected = true,
                    onSelect = {},
                )
            }
        }
        composeRule.onNode(hasText("Sat, 31 May")).assertIsDisplayed()
        composeRule.onNode(hasText("10am – 12pm")).assertIsDisplayed()
    }
}
