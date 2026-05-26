package com.equipseva.app.designsystem.components

import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.hasContentDescription
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
 * UI smoke for [BidCard] (salvaged in #981, wired into the hospital-view
 * RepairJobDetailScreen). Pin the render contract: name + rating format
 * + currency format + optional chips/icons + click delivery.
 */
@RunWith(RobolectricTestRunner::class)
@Config(application = android.app.Application::class)
class BidCardUiTest {

    @get:Rule val composeRule = createComposeRule()

    @Composable
    private fun Themed(content: @Composable () -> Unit) {
        MaterialTheme { content() }
    }

    @Test fun `engineer name renders`() {
        composeRule.setContent {
            Themed {
                BidCard(
                    engineerName = "Asha Rao",
                    rating = 4.7f,
                    ratingCount = 23,
                    amountRupees = 1500.0,
                )
            }
        }
        composeRule.onNode(hasText("Asha Rao")).assertIsDisplayed()
    }

    @Test fun `rating is formatted to one decimal place`() {
        composeRule.setContent {
            Themed {
                BidCard(
                    engineerName = "Asha Rao",
                    rating = 4.7f,
                    ratingCount = 23,
                    amountRupees = 1500.0,
                )
            }
        }
        composeRule.onNode(hasText("4.7")).assertIsDisplayed()
    }

    @Test fun `rating count is rendered in parentheses`() {
        composeRule.setContent {
            Themed {
                BidCard(
                    engineerName = "Asha Rao",
                    rating = 4.7f,
                    ratingCount = 23,
                    amountRupees = 1500.0,
                )
            }
        }
        composeRule.onNode(hasText(" (23)")).assertIsDisplayed()
    }

    @Test fun `amount uses INR symbol with thousands grouping`() {
        composeRule.setContent {
            Themed {
                BidCard(
                    engineerName = "Asha Rao",
                    rating = 4.7f,
                    ratingCount = 23,
                    amountRupees = 12500.0,
                )
            }
        }
        composeRule.onNode(hasText("₹12,500")).assertIsDisplayed()
    }

    @Test fun `verified icon surfaces a contentDescription when isVerified=true`() {
        composeRule.setContent {
            Themed {
                BidCard(
                    engineerName = "Asha Rao",
                    rating = 4.7f,
                    ratingCount = 23,
                    amountRupees = 1500.0,
                    isVerified = true,
                )
            }
        }
        composeRule.onNode(hasContentDescription("Verified")).assertIsDisplayed()
    }

    @Test fun `verified icon absent when isVerified=false`() {
        composeRule.setContent {
            Themed {
                BidCard(
                    engineerName = "Asha Rao",
                    rating = 4.7f,
                    ratingCount = 23,
                    amountRupees = 1500.0,
                    isVerified = false,
                )
            }
        }
        composeRule.onAllNodes(hasContentDescription("Verified")).assertCountEquals(0)
    }

    @Test fun `Top match chip renders when isTopMatch=true`() {
        composeRule.setContent {
            Themed {
                BidCard(
                    engineerName = "Asha Rao",
                    rating = 4.7f,
                    ratingCount = 23,
                    amountRupees = 1500.0,
                    isTopMatch = true,
                )
            }
        }
        composeRule.onNode(hasText("Top match")).assertIsDisplayed()
    }

    @Test fun `ETA chip renders with hours when etaHours is supplied`() {
        composeRule.setContent {
            Themed {
                BidCard(
                    engineerName = "Asha Rao",
                    rating = 4.7f,
                    ratingCount = 23,
                    amountRupees = 1500.0,
                    etaHours = 6,
                )
            }
        }
        composeRule.onNode(hasText("ETA 6h")).assertIsDisplayed()
    }

    @Test fun `click invokes callback when onClick is supplied`() {
        var clicks = 0
        composeRule.setContent {
            Themed {
                BidCard(
                    engineerName = "Asha Rao",
                    rating = 4.7f,
                    ratingCount = 23,
                    amountRupees = 1500.0,
                    onClick = { clicks++ },
                )
            }
        }
        composeRule.onNode(hasText("Asha Rao")).performClick()
        assertEquals(1, clicks)
    }
}
