package com.equipseva.app.features.engineer

import com.equipseva.app.designsystem.components.PillKind
import org.junit.Assert.assertEquals
import org.junit.Test

/** Pins for the r1404 engineer certification-status helpers. */
class CertificationStatusHelpersTest {

    @Test fun `tier maps to badge tone case-insensitively`() {
        assertEquals(PillKind.Warn, certificationTierPillKind("gold"))
        assertEquals(PillKind.Warn, certificationTierPillKind("GOLD"))
        assertEquals(PillKind.Info, certificationTierPillKind("silver"))
        assertEquals(PillKind.Forest, certificationTierPillKind("bronze"))
    }

    @Test fun `unknown or none tier is neutral`() {
        assertEquals(PillKind.Neutral, certificationTierPillKind("none"))
        assertEquals(PillKind.Neutral, certificationTierPillKind("platinum"))
    }

    @Test fun `code-red priority label`() {
        assertEquals("Standard queue", codeRedPriorityLabel(0))
        assertEquals("Standard queue", codeRedPriorityLabel(-1))
        assertEquals("Priority 2", codeRedPriorityLabel(2))
    }

    @Test fun `percent drops redundant decimal and rounds to one place`() {
        assertEquals("7%", formatPercent(7.0))
        assertEquals("2.5%", formatPercent(2.5))
        assertEquals("2.5%", formatPercent(2.53))
        assertEquals("0%", formatPercent(0.0))
    }
}
