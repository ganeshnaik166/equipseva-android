package com.equipseva.app.designsystem.components

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AccountBalanceWallet
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.test.assertCountEquals
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
 * UI smoke for [PaymentMethodTile] (salvaged in #981). Pin the slot +
 * tap contract — the payment-method picker is on the checkout flow.
 */
@RunWith(RobolectricTestRunner::class)
@Config(application = android.app.Application::class)
class PaymentMethodTileUiTest {

    @get:Rule val composeRule = createComposeRule()

    @Composable
    private fun Themed(content: @Composable () -> Unit) {
        MaterialTheme { content() }
    }

    @Test fun `title renders`() {
        composeRule.setContent {
            Themed {
                PaymentMethodTile(
                    icon = Icons.Filled.AccountBalanceWallet,
                    title = "UPI",
                    selected = false,
                    onSelect = {},
                )
            }
        }
        composeRule.onNode(hasText("UPI")).assertIsDisplayed()
    }

    @Test fun `tap invokes onSelect once`() {
        var picks = 0
        composeRule.setContent {
            Themed {
                PaymentMethodTile(
                    icon = Icons.Filled.AccountBalanceWallet,
                    title = "UPI",
                    selected = false,
                    onSelect = { picks++ },
                )
            }
        }
        composeRule.onNode(hasText("UPI")).performClick()
        assertEquals(1, picks)
    }

    @Test fun `subtitle renders when supplied`() {
        composeRule.setContent {
            Themed {
                PaymentMethodTile(
                    icon = Icons.Filled.AccountBalanceWallet,
                    title = "UPI",
                    selected = false,
                    onSelect = {},
                    subtitle = "PhonePe, Google Pay, Paytm",
                )
            }
        }
        composeRule.onNode(hasText("PhonePe, Google Pay, Paytm")).assertIsDisplayed()
    }

    @Test fun `subtitle slot absent when null`() {
        composeRule.setContent {
            Themed {
                PaymentMethodTile(
                    icon = Icons.Filled.AccountBalanceWallet,
                    title = "UPI",
                    selected = false,
                    onSelect = {},
                    subtitle = null,
                )
            }
        }
        composeRule.onAllNodes(hasText("PhonePe, Google Pay, Paytm")).assertCountEquals(0)
    }
}
