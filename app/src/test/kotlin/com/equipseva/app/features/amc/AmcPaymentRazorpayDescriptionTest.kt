package com.equipseva.app.features.amc

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the Razorpay description text surfaced in the checkout UI and
 * hospital payment history.
 *
 * Most-visible string at the highest-stakes moment in the funnel —
 * "1 months for X" surfacing in the Razorpay UI would erode trust.
 */
class AmcPaymentRazorpayDescriptionTest {

    @Test fun `singular at 1 month`() {
        // Critical pin — never "1 months".
        assertEquals(
            "1 month for Asha Rao",
            amcPaymentRazorpayDescription(1, "Asha Rao"),
        )
    }

    @Test fun `plural at 2 months`() {
        assertEquals(
            "2 months for Asha Rao",
            amcPaymentRazorpayDescription(2, "Asha Rao"),
        )
    }

    @Test fun `plural at 12 months (annual top-up)`() {
        assertEquals(
            "12 months for Asha Rao",
            amcPaymentRazorpayDescription(12, "Asha Rao"),
        )
    }

    @Test fun `engineer name passes through verbatim with no transformation`() {
        // Pin no transformation — caller is responsible for the name
        // shape. A refactor that title-cased or truncated would
        // misrepresent the engineer's actual identity.
        assertEquals(
            "3 months for dr. K Ramesh, B.Tech",
            amcPaymentRazorpayDescription(3, "dr. K Ramesh, B.Tech"),
        )
    }

    @Test fun `0 months reads plural (defensive — server gates positive)`() {
        assertEquals(
            "0 months for X",
            amcPaymentRazorpayDescription(0, "X"),
        )
    }

    @Test fun `for keyword joins count and name`() {
        // Pin the literal "for" — a refactor to "with" or "—"
        // would change the semantics from "payment for service"
        // to "transaction with party".
        val out = amcPaymentRazorpayDescription(1, "X")
        assertTrue(out.contains(" for "))
    }
}
