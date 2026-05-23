package com.equipseva.app.features.home

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class SlaCreditsCardTitleTest {

    @Test fun `title prepends formatted rupees with credited suffix`() {
        assertEquals(
            "₹5,000 credited for SLA misses",
            slaCreditsCardTitle(5000.0),
        )
    }

    @Test fun `for SLA misses suffix is mandatory (load-bearing context)`() {
        // Critical pin — bare "₹X credited" is ambiguous (credited
        // to whom, by whom?). The suffix communicates this is
        // compensation owed by the engineer via the pool ledger.
        val out = slaCreditsCardTitle(1.0)
        assertTrue(out.endsWith(" credited for SLA misses"))
    }

    @Test fun `zero amount still surfaces full title`() {
        // Caller gates on > 0 to render the card, but pin the helper
        // stays total.
        assertEquals(
            "₹0 credited for SLA misses",
            slaCreditsCardTitle(0.0),
        )
    }

    @Test fun `Indian lakh grouping via formatRupees`() {
        // Pin formatRupees integration — a refactor to bare
        // interpolation would lose the ₹ symbol and the grouping.
        val out = slaCreditsCardTitle(180_000.0)
        assertTrue(out.contains("₹1,80,000"))
    }
}
