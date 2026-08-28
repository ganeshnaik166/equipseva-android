package com.equipseva.app.core.payments

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins [shouldClearEscrowMarker] — decides whether a locally-stored
 * "escrow payment in flight" marker is dropped after the server tells us the
 * escrow's real status. Money-critical: clearing a still-"pending" marker would
 * hide the retry affordance from a hospital whose verify call died mid-flight;
 * failing to clear a resolved one would nag them forever.
 *
 * The source carries a "pinned semantics" KDoc but had no test — this makes the
 * pin real: a future relax that auto-cleared "pending" (or an unknown status)
 * would fail here.
 */
class PendingEscrowPaymentsReconcilerTest {

    @Test fun `resolved statuses clear the marker`() {
        listOf("held", "released", "refunded", "in_dispute").forEach {
            assertTrue("$it should clear", shouldClearEscrowMarker(it))
        }
    }

    @Test fun `null status clears the marker`() {
        // Row gone (settled + purged / never existed) — nothing to retry.
        assertTrue(shouldClearEscrowMarker(null))
    }

    @Test fun `pending keeps the marker so the hospital can retry`() {
        assertFalse(shouldClearEscrowMarker("pending"))
    }

    @Test fun `unknown future status keeps the marker (forward-compat)`() {
        assertFalse(shouldClearEscrowMarker("some_v2_status"))
        assertFalse(shouldClearEscrowMarker(""))
    }
}
