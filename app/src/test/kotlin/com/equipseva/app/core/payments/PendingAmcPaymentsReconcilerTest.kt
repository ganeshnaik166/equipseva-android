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

    @Test fun `escrow-only statuses are NOT auto-cleared here (distinct vocabularies)`() {
        // "held"/"in_dispute" are escrow terms, not AMC-order terms — treated as
        // unknown → keep, so a mismatched status can't silently drop the marker.
        assertFalse(shouldClearAmcPaymentMarker("held"))
        assertFalse(shouldClearAmcPaymentMarker("in_dispute"))
    }
}
