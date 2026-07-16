package com.equipseva.app.features.hospital

import com.equipseva.app.designsystem.components.PillKind
import org.junit.Assert.assertEquals
import org.junit.Test

/** Pins for the r1405 hospital commission-tier helpers. */
class CommissionTierHelpersTest {

    @Test fun `fraction renders as whole percentage`() {
        assertEquals("7%", formatRatePct(0.07))
        assertEquals("5%", formatRatePct(0.05))
        assertEquals("3%", formatRatePct(0.03))
    }

    @Test fun `tier name by rate`() {
        assertEquals("Top tier", commissionTierName(0.03))
        assertEquals("Preferred", commissionTierName(0.05))
        assertEquals("Standard", commissionTierName(0.07))
    }

    @Test fun `tier pill tone by rate`() {
        assertEquals(PillKind.Success, commissionTierPillKind(0.03))
        assertEquals(PillKind.Info, commissionTierPillKind(0.05))
        assertEquals(PillKind.Neutral, commissionTierPillKind(0.07))
    }

    @Test fun `next-tier message when a better rate exists`() {
        assertEquals(
            "Complete 2 more jobs in the next 12 months to unlock 5% commission.",
            commissionNextTierMessage(0.05, 2),
        )
        assertEquals(
            "Complete 1 more job in the next 12 months to unlock 3% commission.",
            commissionNextTierMessage(0.03, 1),
        )
    }

    @Test fun `next-tier message on the best rate`() {
        assertEquals("You're on our best commission rate.", commissionNextTierMessage(null, 0))
    }
}
