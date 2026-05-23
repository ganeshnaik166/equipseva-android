package com.equipseva.app.features.founder

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class EscrowDisputeAmountHeldLineTest {

    @Test fun `amount renders with rupee prefix and held suffix`() {
        val out = escrowDisputeAmountHeldLine(10_000.0)
        assertTrue(out.startsWith("₹"))
        assertTrue(out.endsWith(" held"))
    }

    @Test fun `held suffix is mandatory (escrow-state signal)`() {
        // Critical pin — "held" is load-bearing context: distinct
        // from "released" / "refunded" used on resolved rows.
        assertTrue(escrowDisputeAmountHeldLine(1.0).endsWith(" held"))
    }

    @Test fun `zero amount still surfaces held suffix`() {
        val out = escrowDisputeAmountHeldLine(0.0)
        assertTrue(out.endsWith(" held"))
    }

    @Test fun `large amount uses Indian lakh grouping (via formatRupees)`() {
        // Pin formatRupees integration — a refactor to bare interpolation
        // would surface "1.8E5 held" instead of "₹1,80,000 held".
        val out = escrowDisputeAmountHeldLine(180_000.0)
        assertTrue(out.contains("1,80,000"))
    }
}
