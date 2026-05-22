package com.equipseva.app.features.home

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the SLA-credits card subtitle's singular/plural split.
 *
 * Regression target: always-"breaches" interpolation would surface
 * "1 SLA breaches" on the most common single-breach case.
 */
class SlaCreditsCardSubtitleTest {

    @Test fun `count of 1 uses singular breach`() {
        assertEquals(
            "1 SLA breach in the last 30 days. Tap to review.",
            slaCreditsCardSubtitle(1),
        )
    }

    @Test fun `count of 2 uses plural breaches`() {
        assertEquals(
            "2 SLA breaches in the last 30 days. Tap to review.",
            slaCreditsCardSubtitle(2),
        )
    }

    @Test fun `count of 5 uses plural breaches`() {
        assertEquals(
            "5 SLA breaches in the last 30 days. Tap to review.",
            slaCreditsCardSubtitle(5),
        )
    }

    @Test fun `count of 0 uses plural (defensive — caller gates on positive)`() {
        // The card is gated on totalCreditRupees > 0 server-side
        // (no SLA card without at least one breach), but pin a
        // sensible fallback so the helper is total.
        assertEquals(
            "0 SLA breaches in the last 30 days. Tap to review.",
            slaCreditsCardSubtitle(0),
        )
    }

    @Test fun `tap-to-review CTA preserved across both branches`() {
        val one = slaCreditsCardSubtitle(1)
        val many = slaCreditsCardSubtitle(5)
        assertEquals(true, one.endsWith("Tap to review."))
        assertEquals(true, many.endsWith("Tap to review."))
    }
}
