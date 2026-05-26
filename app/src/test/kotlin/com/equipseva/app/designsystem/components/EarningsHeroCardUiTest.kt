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
 * UI smoke for [EarningsHeroCard] (salvaged in #981). Pin the contract
 * the engineer-earnings screen depends on:
 *
 *   • "This month" + "Paid" + "Pending" labels render
 *   • total / paid / pending amounts render with ₹ + thousands grouping
 *   • "Withdraw" pill click invokes onWithdraw exactly once
 */
@RunWith(RobolectricTestRunner::class)
@Config(application = android.app.Application::class)
class EarningsHeroCardUiTest {

    @get:Rule val composeRule = createComposeRule()

    @Composable
    private fun Themed(content: @Composable () -> Unit) {
        MaterialTheme { content() }
    }

    @Test fun `labels render`() {
        composeRule.setContent {
            Themed {
                EarningsHeroCard(
                    totalRupees = 1500.0,
                    paidRupees = 1000.0,
                    pendingRupees = 500.0,
                    onWithdraw = {},
                )
            }
        }
        composeRule.onNode(hasText("This month")).assertIsDisplayed()
        composeRule.onNode(hasText("Paid")).assertIsDisplayed()
        composeRule.onNode(hasText("Pending")).assertIsDisplayed()
        composeRule.onNode(hasText("Withdraw")).assertIsDisplayed()
    }

    @Test fun `total amount uses INR symbol + thousands grouping`() {
        composeRule.setContent {
            Themed {
                EarningsHeroCard(
                    totalRupees = 12500.0,
                    paidRupees = 0.0,
                    pendingRupees = 0.0,
                    onWithdraw = {},
                )
            }
        }
        composeRule.onNode(hasText("₹12,500")).assertIsDisplayed()
    }

    @Test fun `paid + pending amounts each render formatted`() {
        composeRule.setContent {
            Themed {
                EarningsHeroCard(
                    totalRupees = 15000.0,
                    paidRupees = 10000.0,
                    pendingRupees = 5000.0,
                    onWithdraw = {},
                )
            }
        }
        composeRule.onNode(hasText("₹10,000")).assertIsDisplayed()
        composeRule.onNode(hasText("₹5,000")).assertIsDisplayed()
    }

    @Test fun `withdraw pill click invokes callback once`() {
        var withdrawals = 0
        composeRule.setContent {
            Themed {
                EarningsHeroCard(
                    totalRupees = 1000.0,
                    paidRupees = 1000.0,
                    pendingRupees = 0.0,
                    onWithdraw = { withdrawals++ },
                )
            }
        }
        composeRule.onNode(hasText("Withdraw")).performClick()
        assertEquals(1, withdrawals)
    }

    @Test fun `zero amounts still render with the rupee symbol`() {
        composeRule.setContent {
            Themed {
                EarningsHeroCard(
                    totalRupees = 0.0,
                    paidRupees = 0.0,
                    pendingRupees = 0.0,
                    onWithdraw = {},
                )
            }
        }
        composeRule.onAllNodes(hasText("₹0")).fetchSemanticsNodes().also {
            // Total + paid + pending — three ₹0 strings
            assertEquals(3, it.size)
        }
    }
}
