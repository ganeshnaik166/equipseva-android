package com.equipseva.app.core.payments

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the AMC-payment-marker reconciliation decision. Sibling to
 * shouldClearEscrowMarker but the status vocabulary differs — AMC
 * payment orders have an explicit "failed" state (Razorpay rejected
 * the charge), whereas escrow rows model the same end-state as
 * "refunded".
 *
 * Same critical region: "pending" must KEEP the marker so the home
 * banner / support prompt can surface it. Auto-clearing would silently
 * drop an in-flight AMC payment record on a transient race.
 */
class ShouldClearAmcPaymentMarkerTest {

    @Test fun `paid clears the marker (terminal, ledger in order)`() {
        assertTrue(shouldClearAmcPaymentMarker("paid"))
    }

    @Test fun `refunded clears the marker (terminal)`() {
        assertTrue(shouldClearAmcPaymentMarker("refunded"))
    }

    @Test fun `failed clears the marker (Razorpay rejected the charge)`() {
        // AMC-specific terminal status — escrow rows don't have this.
        // Pin so a future refactor that collapses failed into
        // "in_dispute" surfaces.
        assertTrue(shouldClearAmcPaymentMarker("failed"))
    }

    @Test fun `null clears the marker (row missing or RLS denied)`() {
        assertTrue(shouldClearAmcPaymentMarker(null))
    }

    @Test fun `pending keeps the marker`() {
        // The home banner / support prompt surfaces a pending marker
        // so the hospital can chase the bank charge. Auto-clearing
        // would silently drop the in-flight record.
        assertFalse(shouldClearAmcPaymentMarker("pending"))
    }

    @Test fun `unknown future status keeps the marker (forward-compat)`() {
        assertFalse(shouldClearAmcPaymentMarker("future_state"))
    }

    @Test fun `empty string keeps the marker`() {
        assertFalse(shouldClearAmcPaymentMarker(""))
    }

    @Test fun `status comparison is case-sensitive`() {
        // Server emits lowercase; mixed case is invalid.
        assertFalse(shouldClearAmcPaymentMarker("PAID"))
        assertFalse(shouldClearAmcPaymentMarker("Failed"))
    }

    @Test fun `escrow's in_dispute does NOT match the AMC vocab`() {
        // AMC payment orders never use "in_dispute" — pin so the
        // shape doesn't accidentally inherit escrow semantics.
        assertFalse(shouldClearAmcPaymentMarker("in_dispute"))
    }
}
