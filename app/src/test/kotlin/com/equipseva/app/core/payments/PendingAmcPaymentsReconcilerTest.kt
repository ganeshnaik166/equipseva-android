package com.equipseva.app.core.payments

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins [shouldClearAmcPaymentMarker] — sibling of shouldClearEscrowMarker with
 * the AMC payment-order status vocabulary (AMC orders have "failed"; escrow rows
 * don't). Money-critical: keep "pending" so the home banner / support prompt can
 * surface an in-flight AMC payment; clear it once the order resolves.
 */
class PendingAmcPaymentsReconcilerTest {

    @Test fun `resolved statuses clear the marker`() {
        listOf("paid", "refunded", "failed").forEach {
            assertTrue("$it should clear", shouldClearAmcPaymentMarker(it))
        }
    }

    @Test fun `null status clears the marker`() {
        assertTrue(shouldClearAmcPaymentMarker(null))
    }

    @Test fun `pending keeps the marker`() {
        assertFalse(shouldClearAmcPaymentMarker("pending"))
    }

    @Test fun `unknown future status keeps the marker (forward-compat)`() {
        assertFalse(shouldClearAmcPaymentMarker("some_v2_status"))
        assertFalse(shouldClearAmcPaymentMarker(""))
    }

    @Test fun `only a pending order has its signature replayed`() {
        // A pending order may be a captured payment whose verify never landed,
        // and the verify edge fn is idempotent — so replaying it is the only
        // way the pool gets credited without the dashboard webhook.
        assertTrue(shouldReverifyAmcPayment("pending"))
    }

    @Test fun `resolved and unknown statuses are never replayed`() {
        // Terminal states are handled by shouldClearAmcPaymentMarker; an
        // unrecognised future status must not be guessed at with a signature.
        listOf("paid", "refunded", "failed", "some_v2_status", "", null).forEach {
            assertFalse("$it must not be re-verified", shouldReverifyAmcPayment(it))
        }
    }

    @Test fun `escrow-only statuses are NOT auto-cleared here (distinct vocabularies)`() {
        // "held"/"in_dispute" are escrow terms, not AMC-order terms — treated as
        // unknown → keep, so a mismatched status can't silently drop the marker.
        assertFalse(shouldClearAmcPaymentMarker("held"))
        assertFalse(shouldClearAmcPaymentMarker("in_dispute"))
    }
}
