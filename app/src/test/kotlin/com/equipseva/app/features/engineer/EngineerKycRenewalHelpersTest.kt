package com.equipseva.app.features.engineer

import com.equipseva.app.designsystem.components.PillKind
import org.junit.Assert.assertEquals
import org.junit.Test

/** Pins for the r1401 KYC-renewal nudge pill. */
class EngineerKycRenewalHelpersTest {

    @Test fun `overdue reads Overdue with Danger tone`() {
        assertEquals("Overdue" to PillKind.Danger, renewalPillTextAndKind(-2.0))
    }

    @Test fun `due soon reads Due soon with Warn tone`() {
        assertEquals("Due soon" to PillKind.Warn, renewalPillTextAndKind(5.0))
    }

    @Test fun `scheduled reads Scheduled with Info tone`() {
        assertEquals("Scheduled" to PillKind.Info, renewalPillTextAndKind(45.0))
    }
}
