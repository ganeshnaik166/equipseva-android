package com.equipseva.app.features.home

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the singular/plural split on the pending-AMC-payment banner
 * title. Critical region: a count of 1 reads "Payment may still be
 * in progress" (no "1 payments" awkwardness); 2+ reads "N payments
 * may still be in progress". A regression that always interpolated
 * the count would surface "1 payments" on the most common case.
 */
class PendingAmcPaymentBannerTitleTest {

    @Test fun `count of 1 uses singular phrasing without leading number`() {
        assertEquals(
            "Payment may still be in progress",
            pendingAmcPaymentBannerTitle(1),
        )
    }

    @Test fun `count of 2 uses plural phrasing with leading number`() {
        assertEquals(
            "2 payments may still be in progress",
            pendingAmcPaymentBannerTitle(2),
        )
    }

    @Test fun `count of 5 uses plural phrasing`() {
        assertEquals(
            "5 payments may still be in progress",
            pendingAmcPaymentBannerTitle(5),
        )
    }

    @Test fun `count of 0 falls through to plural shape (defensive — caller gates)`() {
        // The screen gates on count > 0 before rendering, but pin
        // a sensible fallback so the helper is total. Renders as
        // "0 payments may still be in progress" — reads strangely
        // but doesn't crash.
        assertEquals(
            "0 payments may still be in progress",
            pendingAmcPaymentBannerTitle(0),
        )
    }

    @Test fun `large count interpolates verbatim`() {
        assertEquals(
            "42 payments may still be in progress",
            pendingAmcPaymentBannerTitle(42),
        )
    }
}
