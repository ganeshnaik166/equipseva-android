package com.equipseva.app.features.amc

import org.junit.Assert.assertEquals
import org.junit.Test

/** Pins for the r1416 per-contract AMC tier-perks helpers. */
class AmcTierPerksHelpersTest {

    @Test fun `sla label — minutes vs hours vs unset`() {
        assertEquals("—", amcSlaLabel(null))
        assertEquals("—", amcSlaLabel(0))
        assertEquals("45 min", amcSlaLabel(45))
        assertEquals("90 min", amcSlaLabel(90))
        assertEquals("1 h", amcSlaLabel(60))
        assertEquals("2 h", amcSlaLabel(120))
    }

    @Test fun `discount label — percent value, trailing zero stripped`() {
        assertEquals("—", amcDiscountLabel(null))
        assertEquals("—", amcDiscountLabel(0.0))
        assertEquals("10%", amcDiscountLabel(10.0))
        assertEquals("12.5%", amcDiscountLabel(12.5))
    }
}
