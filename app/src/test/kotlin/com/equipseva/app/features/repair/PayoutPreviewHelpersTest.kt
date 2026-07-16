package com.equipseva.app.features.repair

import org.junit.Assert.assertEquals
import org.junit.Test

/** Pins for the r1413 engineer payout-preview helpers. */
class PayoutPreviewHelpersTest {

    @Test fun `commission fraction renders as percent`() {
        assertEquals("7%", commissionPctLabel(0.07))
        assertEquals("5%", commissionPctLabel(0.05))
        assertEquals("2.5%", commissionPctLabel(0.025))
        assertEquals("0%", commissionPctLabel(0.0))
    }

    @Test fun `warranty note only for warranty jobs`() {
        assertEquals("", warrantyPayoutNote(false))
        assertEquals(
            "This is a warranty job — EquipSeva waives its commission, so you keep the full contracted amount.",
            warrantyPayoutNote(true),
        )
    }
}
