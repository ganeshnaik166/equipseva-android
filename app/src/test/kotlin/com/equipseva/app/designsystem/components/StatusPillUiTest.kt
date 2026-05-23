package com.equipseva.app.designsystem.components

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import com.equipseva.app.core.data.repair.RepairJobStatus
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * First Compose UI test that runs on the JVM via Robolectric (no
 * emulator needed). Proves the createComposeRule + Compose-runtime
 * stack works in this module so follow-up screen-level interaction
 * tests can layer on top.
 *
 * Tests that render product Composables should stay narrow — verify
 * the static text content + role / a11y semantics, not the exact
 * pixel layout. Pixel-level assertions belong in screenshot tests
 * (separate follow-up).
 *
 * Pattern documented (KDoc inline) for follow-up Compose UI tests:
 *   * @RunWith(RobolectricTestRunner::class).
 *   * @Config(application = android.app.Application::class) to avoid
 *     booting the prod EquipSevaApplication's Hilt graph.
 *   * `createComposeRule()` (the simpler no-Activity variant — used
 *     for testing isolated composables that don't navigate).
 *   * setContent { TargetComposable(...) } in the test body.
 *   * Use onNodeWithText / onNodeWithContentDescription to find
 *     nodes; assertIsDisplayed / assertExists to assert state.
 */
@RunWith(RobolectricTestRunner::class)
@Config(application = android.app.Application::class)
class StatusPillUiTest {

    @get:Rule
    val composeRule = createComposeRule()

    @Test fun `renders Requested label for Requested status`() {
        composeRule.setContent {
            StatusPill(status = RepairJobStatus.Requested)
        }
        composeRule.onNodeWithText("Requested").assertIsDisplayed()
    }

    @Test fun `renders En route label for EnRoute status`() {
        // Two-word labels are easy to fumble in the classifier — pin
        // explicitly to catch a future "EnRoute" / "en_route" /
        // "Enroute" drift.
        composeRule.setContent {
            StatusPill(status = RepairJobStatus.EnRoute)
        }
        composeRule.onNodeWithText("En route").assertIsDisplayed()
    }

    @Test fun `renders Completed label for Completed status`() {
        composeRule.setContent {
            StatusPill(status = RepairJobStatus.Completed)
        }
        composeRule.onNodeWithText("Completed").assertIsDisplayed()
    }

    @Test fun `renders Unknown label for Unknown status`() {
        // Unknown is the fallback bucket from RepairJobStatus.fromKey
        // when the server returns a value the client doesn't recognise.
        // Pin that the pill still renders rather than collapsing.
        composeRule.setContent {
            StatusPill(status = RepairJobStatus.Unknown)
        }
        composeRule.onNodeWithText("Unknown").assertIsDisplayed()
    }
}
