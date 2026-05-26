package com.equipseva.app.designsystem.components

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Build
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
 * UI smoke for [RoleSelectCard] (salvaged in #981). The role picker on
 * the signup flow renders one card per role; verify the slot contract
 * + selection behaviour callers depend on.
 */
@RunWith(RobolectricTestRunner::class)
@Config(application = android.app.Application::class)
class RoleSelectCardUiTest {

    @get:Rule val composeRule = createComposeRule()

    @Composable
    private fun Themed(content: @Composable () -> Unit) {
        MaterialTheme { content() }
    }

    @Test fun `title and description render`() {
        composeRule.setContent {
            Themed {
                RoleSelectCard(
                    icon = Icons.Filled.Build,
                    title = "Engineer",
                    description = "Bid on hospital repair jobs",
                    hue = 150,
                    selected = false,
                    onSelect = {},
                )
            }
        }
        composeRule.onNode(hasText("Engineer")).assertIsDisplayed()
        composeRule.onNode(hasText("Bid on hospital repair jobs")).assertIsDisplayed()
    }

    @Test fun `tap invokes onSelect once when enabled`() {
        var picks = 0
        composeRule.setContent {
            Themed {
                RoleSelectCard(
                    icon = Icons.Filled.Build,
                    title = "Engineer",
                    description = "Bid on hospital repair jobs",
                    hue = 150,
                    selected = false,
                    onSelect = { picks++ },
                )
            }
        }
        composeRule.onNode(hasText("Engineer")).performClick()
        assertEquals(1, picks)
    }

    @Test fun `tap is swallowed when enabled=false`() {
        var picks = 0
        composeRule.setContent {
            Themed {
                RoleSelectCard(
                    icon = Icons.Filled.Build,
                    title = "Engineer",
                    description = "Bid on hospital repair jobs",
                    hue = 150,
                    selected = false,
                    onSelect = { picks++ },
                    enabled = false,
                )
            }
        }
        runCatching { composeRule.onNode(hasText("Engineer")).performClick() }
        assertEquals(0, picks)
    }

    @Test fun `badge renders when supplied`() {
        composeRule.setContent {
            Themed {
                RoleSelectCard(
                    icon = Icons.Filled.Build,
                    title = "Engineer",
                    description = "Bid on hospital repair jobs",
                    hue = 150,
                    selected = false,
                    onSelect = {},
                    badge = "KYC required",
                )
            }
        }
        composeRule.onNode(hasText("KYC required")).assertIsDisplayed()
    }

    @Test fun `badge absent when null`() {
        composeRule.setContent {
            Themed {
                RoleSelectCard(
                    icon = Icons.Filled.Build,
                    title = "Engineer",
                    description = "Bid on hospital repair jobs",
                    hue = 150,
                    selected = false,
                    onSelect = {},
                    badge = null,
                )
            }
        }
        composeRule.onAllNodes(hasText("KYC required")).assertCountEquals(0)
    }
}
