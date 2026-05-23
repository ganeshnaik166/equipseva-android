package com.equipseva.app.core.payments

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the escrow-marker reconciliation decision. Critical region:
 * "pending" status keeps the marker — the hospital paid via Razorpay
 * but the verify-payment edge function never completed (process
 * death). Auto-clearing here would silently drop an in-flight payment
 * and the hospital would have no UI affordance to retry.
 *
 * Unknown statuses are also kept (forward-compat) so a future
 * server-side status the reconciler doesn't recognise doesn't trigger
 * an over-eager clear.
 */
class ShouldClearEscrowMarkerTest {

    // ---- terminal / post-pending statuses → clear ----

    @Test fun `held clears the marker`() {
        assertTrue(shouldClearEscrowMarker("held"))
    }

    @Test fun `released clears the marker`() {
        assertTrue(shouldClearEscrowMarker("released"))
    }

    @Test fun `refunded clears the marker`() {
        assertTrue(shouldClearEscrowMarker("refunded"))
    }

    @Test fun `in_dispute clears the marker (post-pending, hospital can chase dispute)`() {
        assertTrue(shouldClearEscrowMarker("in_dispute"))
    }

    // ---- null (row missing) → clear ----

    @Test fun `null status clears the marker (row missing, can't act)`() {
        // RLS denied / escrow row never created / row deleted — we
        // can't act on what we can't see; clear so the marker
        // doesn't linger forever.
        assertTrue(shouldClearEscrowMarker(null))
    }

    // ---- pending → keep ----

    @Test fun `pending keeps the marker (verify call never completed)`() {
        // The hospital paid via Razorpay but the edge function
        // verify-payment never completed (process death). Marker
        // must STAY so the home UI surfaces the in-flight banner
        // and the hospital can retry from the job-detail screen.
        // Pin so a future "tidy up after N days" auto-clear is
        // intentional.
        assertFalse(shouldClearEscrowMarker("pending"))
    }

    // ---- unknown future status → keep (forward-compat) ----

    @Test fun `unknown future status keeps the marker (forward-compat)`() {
        // A v2 status the reconciler doesn't recognise must NOT
        // trigger an over-eager clear. Pin so a future "tolerant
        // clear-on-unknown" change is reviewed.
        assertFalse(shouldClearEscrowMarker("future_state"))
    }

    @Test fun `empty string keeps the marker`() {
        assertFalse(shouldClearEscrowMarker(""))
    }

    @Test fun `status comparison is case-sensitive`() {
        // Server emits lowercase; mixed case is not a valid status.
        assertFalse(shouldClearEscrowMarker("HELD"))
        assertFalse(shouldClearEscrowMarker("Released"))
    }
}
