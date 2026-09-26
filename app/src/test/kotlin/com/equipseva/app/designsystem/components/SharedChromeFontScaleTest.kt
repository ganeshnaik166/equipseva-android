package com.equipseva.app.designsystem.components

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Home
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.dp
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Pins the shared chrome against text clipping at large system font scales.
 * Android 14 lets the user go to 200%, and all three components below used to
 * pin a hard height around text:
 *
 *  - [EsTopBar] — 52 dp around a title plus an optional subtitle, on ~70 screens.
 *  - [EsBottomNav] — 72 dp around the icon pill plus a label, on every screen.
 *  - [StatusChip] — 22 dp around an 11 sp label with a 14 sp line height.
 *
 * The assertions are containment, not exact numbers: the point is that the
 * container grows with its content, whatever the metrics of the font in use.
 */
@RunWith(RobolectricTestRunner::class)
@Config(application = android.app.Application::class)
class SharedChromeFontScaleTest {

    @get:Rule
    val composeRule = createComposeRule()

    @Composable
    private fun Scaled(scale: Float, content: @Composable () -> Unit) {
        MaterialTheme {
            val density = LocalDensity.current
            CompositionLocalProvider(
                LocalDensity provides Density(density.density, scale),
            ) {
                Box(Modifier.fillMaxSize()) { content() }
            }
        }
    }

    @Test fun `top bar grows to contain its title and subtitle at double font scale`() {
        composeRule.setContent {
            Scaled(2f) {
                EsTopBar(
                    modifier = Modifier.testTag("bar"),
                    title = "Notification settings",
                    subtitle = "12 categories",
                )
            }
        }
        val bar = composeRule.onNodeWithTag("bar").getUnclippedBoundsInRoot()
        val title = composeRule.onNodeWithText("Notification settings").getUnclippedBoundsInRoot()
        val subtitle = composeRule.onNodeWithText("12 categories").getUnclippedBoundsInRoot()
        assertTrue("title above the bar's top edge", title.top >= bar.top)
        assertTrue("subtitle below the bar's bottom edge", subtitle.bottom <= bar.bottom)
        assertTrue(
            "bar is not taller than its stacked text",
            bar.span >= title.span + subtitle.span,
        )
    }

    @Test fun `top bar keeps its 52dp minimum at the default font scale`() {
        composeRule.setContent {
            Scaled(1f) {
                EsTopBar(modifier = Modifier.testTag("bar"), title = "Payments")
            }
        }
        val bar = composeRule.onNodeWithTag("bar").getUnclippedBoundsInRoot()
        assertTrue("bar shrank below its design height", bar.span >= 52.dp)
    }

    @Test fun `bottom nav label stays inside the bar at one and a half font scale`() {
        composeRule.setContent {
            Scaled(1.5f) {
                EsBottomNav(
                    tabs = listOf(
                        EsBottomNavItem("home", "Home", Icons.Outlined.Home),
                        EsBottomNavItem("jobs", "Notifications", Icons.Outlined.Home),
                        EsBottomNavItem("me", "Profile", Icons.Outlined.Home),
                    ),
                    currentRoute = "home",
                    onSelect = {},
                    modifier = Modifier.testTag("nav"),
                )
            }
        }
        val nav = composeRule.onNodeWithTag("nav").getUnclippedBoundsInRoot()
        val label = composeRule.onNodeWithText("Notifications", useUnmergedTree = true)
            .getUnclippedBoundsInRoot()
        assertTrue("label clipped by the bar's bottom edge", label.bottom <= nav.bottom)
        assertTrue("label clipped by the bar's top edge", label.top >= nav.top)
    }

    @Test fun `bottom nav caps a three digit unread count`() {
        composeRule.setContent {
            Scaled(1f) {
                EsBottomNav(
                    tabs = listOf(
                        EsBottomNavItem("home", "Home", Icons.Outlined.Home, badge = 120),
                    ),
                    currentRoute = "home",
                    onSelect = {},
                )
            }
        }
        composeRule.onNodeWithText("99+", useUnmergedTree = true).assertIsDisplayed()
    }

    @Test fun `status chip grows to contain its label at double font scale`() {
        composeRule.setContent {
            Scaled(2f) {
                StatusChip(
                    label = "Pending review",
                    modifier = Modifier.testTag("chip"),
                    tone = StatusTone.Warn,
                )
            }
        }
        val chip = composeRule.onNodeWithTag("chip").getUnclippedBoundsInRoot()
        val label = composeRule.onNodeWithText("Pending review").getUnclippedBoundsInRoot()
        assertTrue("label clipped by the chip", label.span <= chip.span)
        assertTrue("label above the chip's top edge", label.top >= chip.top)
        assertTrue("label below the chip's bottom edge", label.bottom <= chip.bottom)
    }

    @Test fun `status chip keeps its 22dp minimum at the default font scale`() {
        composeRule.setContent {
            Scaled(1f) {
                StatusChip(label = "Paid", modifier = Modifier.testTag("chip"))
            }
        }
        val chip = composeRule.onNodeWithTag("chip").getUnclippedBoundsInRoot()
        assertTrue("chip shrank below its design height", chip.span >= 22.dp)
    }
}

/**
 * Vertical span of a measured node.
 *
 * `DpRect` models the four edges and does not carry a height of its own, so
 * every clipping assertion here derives it. Kept fully qualified so the name
 * cannot collide with the layout `height` modifier a later edit to this file
 * is likely to want.
 */
private val androidx.compose.ui.unit.DpRect.span: androidx.compose.ui.unit.Dp
    get() = bottom - top
