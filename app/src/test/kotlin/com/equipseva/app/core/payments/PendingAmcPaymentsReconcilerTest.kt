package com.equipseva.app.core.payments

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins [shouldClearAmcPaymentMarker] — sibling of shouldClearEscrowMarker with
 * the AMC payment-order status vocabulary (AMC orders have "failed"; escrow rows
 * don't). Paid is written before pool credit, so paid and pending must retain
 * their recovery material until verify confirms a ledger for that order.
 */
class PendingAmcPaymentsReconcilerTest {

    @Test fun `refunded and failed statuses clear the marker`() {
        listOf("refunded", "failed").forEach {
            assertTrue("$it should clear", shouldClearAmcPaymentMarker(it))
        }
    }

    @Test fun `unavailable status keeps the marker`() {
        // A hidden/missing row cannot prove that pool credit completed.
        assertFalse(shouldClearAmcPaymentMarker(null))
    }

    @Test fun `pending keeps the marker`() {
        assertFalse(shouldClearAmcPaymentMarker("pending"))
    }

    @Test fun `paid status alone keeps the marker until ledger confirmation`() {
        assertFalse(shouldClearAmcPaymentMarker("paid"))
    }

    @Test fun `unknown future status keeps the marker (forward-compat)`() {
        assertFalse(shouldClearAmcPaymentMarker("some_v2_status"))
        assertFalse(shouldClearAmcPaymentMarker(""))
    }

    @Test fun `pending and paid orders can recover through idempotent verification`() {
        // Paid can still lack its pool credit if the server stopped between
        // the order update and the credit RPC. Never infer credit from status.
        assertTrue(shouldReverifyAmcPayment("pending"))
        assertTrue(shouldReverifyAmcPayment("paid"))
    }

    @Test fun `resolved and unknown statuses are never replayed`() {
        // Terminal states are handled by shouldClearAmcPaymentMarker; an
        // unrecognised future status must not be guessed at with a signature.
        listOf("refunded", "failed", "some_v2_status", "", null).forEach {
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
