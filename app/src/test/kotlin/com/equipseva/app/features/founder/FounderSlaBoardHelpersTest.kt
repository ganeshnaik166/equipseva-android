package com.equipseva.app.features.founder

import com.equipseva.app.designsystem.components.PillKind
import org.junit.Assert.assertEquals
import org.junit.Test

/** Pins for the r1424 founder engineer-SLA board helpers. */
class FounderSlaBoardHelpersTest {

    @Test fun `risk pill maps bands (case-insensitive)`() {
        assertEquals("Low risk" to PillKind.Success, slaRiskPill("low"))
        assertEquals("Medium risk" to PillKind.Warn, slaRiskPill("MEDIUM"))
        assertEquals("High risk" to PillKind.Danger, slaRiskPill("high"))
        assertEquals("High risk" to PillKind.Danger, slaRiskPill("critical"))
    }

    @Test fun `risk pill handles null and unknown`() {
        assertEquals("—" to PillKind.Neutral, slaRiskPill(null))
        assertEquals("—" to PillKind.Neutral, slaRiskPill(""))
        assertEquals("Elevated" to PillKind.Neutral, slaRiskPill("elevated"))
    }

    @Test fun `pct drops redundant decimal and adds percent, null is dash`() {
        assertEquals("92%", formatSlaPct(92.0))
        assertEquals("87.5%", formatSlaPct(87.5))
        assertEquals("0%", formatSlaPct(0.0))
        assertEquals("—", formatSlaPct(null))
    }
}
