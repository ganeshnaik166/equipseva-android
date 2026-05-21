package com.equipseva.app.core.data.escrow

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the five status flags on [RepairJobEscrowRepository.EscrowRow].
 * The repair-job detail screen routes its UI banner / CTA off these
 * (e.g. show "Release escrow" only when isHeld, "Open dispute" only
 * within isInDisputeWindow). A regression in any flag's string
 * comparison would silently mis-route the affordance — worst case a
 * hospital being shown the release button before payment is captured.
 */
class EscrowRowStatusTest {

    private fun row(status: String) = RepairJobEscrowRepository.EscrowRow(
        id = "e1",
        status = status,
        amountRupees = 2500.0,
    )

    @Test fun `pending status flips isPending true and the rest false`() {
        val r = row("pending")
        assertTrue(r.isPending)
        assertFalse(r.isHeld)
        assertFalse(r.isReleased)
        assertFalse(r.isInDispute)
        assertFalse(r.isRefunded)
    }

    @Test fun `held status flips isHeld true and the rest false`() {
        val r = row("held")
        assertTrue(r.isHeld)
        assertFalse(r.isPending)
        assertFalse(r.isReleased)
        assertFalse(r.isInDispute)
        assertFalse(r.isRefunded)
    }

    @Test fun `released status flips isReleased true and the rest false`() {
        val r = row("released")
        assertTrue(r.isReleased)
        assertFalse(r.isPending)
        assertFalse(r.isHeld)
        assertFalse(r.isInDispute)
        assertFalse(r.isRefunded)
    }

    @Test fun `in_dispute status flips isInDispute true and the rest false`() {
        val r = row("in_dispute")
        assertTrue(r.isInDispute)
        assertFalse(r.isPending)
        assertFalse(r.isHeld)
        assertFalse(r.isReleased)
        assertFalse(r.isRefunded)
    }

    @Test fun `refunded status flips isRefunded true and the rest false`() {
        val r = row("refunded")
        assertTrue(r.isRefunded)
        assertFalse(r.isPending)
        assertFalse(r.isHeld)
        assertFalse(r.isReleased)
        assertFalse(r.isInDispute)
    }

    @Test fun `unknown status flips no flag (defensive)`() {
        // Forward-compat: if the server-side state machine grows a
        // new status, the client shows neither banner nor CTA rather
        // than crash. Caught here so a "default to true on unknown"
        // refactor is intentional.
        val r = row("future_status")
        assertFalse(r.isPending)
        assertFalse(r.isHeld)
        assertFalse(r.isReleased)
        assertFalse(r.isInDispute)
        assertFalse(r.isRefunded)
    }

    @Test fun `status comparison is case-sensitive`() {
        // Server-side enum is lowercase; mixed-case is not a valid key.
        val r = row("Held")
        assertFalse(r.isHeld)
    }
}
