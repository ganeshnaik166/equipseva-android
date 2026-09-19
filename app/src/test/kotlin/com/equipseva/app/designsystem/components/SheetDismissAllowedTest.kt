package com.equipseva.app.designsystem.components

import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.SheetValue
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the gesture policy shared by the seven modal sheets whose action
 * cannot be interrupted (delete account, report content, and the five
 * founder approve / reject / save sheets).
 *
 * Critical regression target: the original code refused the dismiss
 * *callback* while busy and left the drag gesture free. The sheet then
 * animated to Hidden, the composable stayed in composition, and the
 * still-mounted dialog window swallowed every tap on the screen behind an
 * invisible scrim whose tap handler was disabled — recoverable only with
 * the Back button. On the delete-account sheet, the wrong-password error
 * was rendered behind that hidden sheet and never seen.
 *
 * A refactor that inverted this predicate, or dropped the `busy` term,
 * would restore that dead screen.
 */
@OptIn(ExperimentalMaterial3Api::class)
class SheetDismissAllowedTest {

    @Test fun `hiding is refused while the action is in flight`() {
        assertFalse(sheetDismissAllowed(SheetValue.Hidden, busy = true))
    }

    @Test fun `hiding is allowed once the action has finished`() {
        // The sheet must still close normally — the gate is a pause, not a
        // trap. Callers flip busy to false before dismissing.
        assertTrue(sheetDismissAllowed(SheetValue.Hidden, busy = false))
    }

    @Test fun `expanding is always allowed even while busy`() {
        // Only Hidden loses the screen; blocking Expanded would freeze the
        // sheet mid-drag with no way to settle.
        assertTrue(sheetDismissAllowed(SheetValue.Expanded, busy = true))
        assertTrue(sheetDismissAllowed(SheetValue.Expanded, busy = false))
    }

    @Test fun `partially expanded is always allowed even while busy`() {
        assertTrue(sheetDismissAllowed(SheetValue.PartiallyExpanded, busy = true))
        assertTrue(sheetDismissAllowed(SheetValue.PartiallyExpanded, busy = false))
    }

    @Test fun `Hidden is the only refused target`() {
        // Enumerated so a new SheetValue in a future Material release has to
        // be considered rather than silently defaulting to blocked.
        val refused = SheetValue.entries.filterNot { sheetDismissAllowed(it, busy = true) }
        assertTrue(
            "unexpected refusals: $refused",
            refused == listOf(SheetValue.Hidden),
        )
    }
}
