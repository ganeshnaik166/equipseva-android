package com.equipseva.app.features.amc

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class SlaBreachCreditPillTextTest {

    @Test fun `prepends Credit prefix to formatted rupees`() {
        assertEquals("Credit ₹5,000", slaBreachCreditPillText(5000.0))
    }

    @Test fun `Credit prefix is mandatory (direction-of-payment signal)`() {
        // Critical pin — a refactor that surfaced the bare amount
        // would lose the signal that this is COMPENSATION owed to
        // the hospital (deducted from engineer's pool share via
        // SLA-breach trigger).
        val out = slaBreachCreditPillText(1.0)
        assertTrue(out.startsWith("Credit "))
    }

    @Test fun `zero amount still surfaces full pill (defensive — caller gates)`() {
        // Pin total shape. Caller gates on > 0; if pill renders, it
        // surfaces "Credit ₹0".
        assertEquals("Credit ₹0", slaBreachCreditPillText(0.0))
    }

    @Test fun `large amount uses Indian lakh grouping via formatRupees`() {
        // Pin formatRupees integration — a refactor to bare
        // interpolation would surface "Credit 1.8E5" or similar.
        val out = slaBreachCreditPillText(180_000.0)
        assertTrue(out.contains("₹1,80,000"))
    }
}
