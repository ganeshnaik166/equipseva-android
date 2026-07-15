package com.equipseva.app.features.engineer

import com.equipseva.app.designsystem.components.PillKind
import org.junit.Assert.assertEquals
import org.junit.Test

/** Pins for the r1397 SLA-card pills (on-time + dispute-rate bands → tone). */
class EngineerSlaHelpersTest {

    @Test fun `excellent on-time reads Excellent with Success tone`() {
        assertEquals("Excellent" to PillKind.Success, onTimePillTextAndKind(99.0))
        assertEquals("Excellent" to PillKind.Success, onTimePillTextAndKind(95.0))
    }

    @Test fun `good on-time reads Good with Warn tone`() {
        assertEquals("Good" to PillKind.Warn, onTimePillTextAndKind(90.0))
    }

    @Test fun `low on-time reads Needs work with Danger tone`() {
        assertEquals("Needs work" to PillKind.Danger, onTimePillTextAndKind(70.0))
    }

    @Test fun `clean dispute rate reads Clean record with Success tone`() {
        assertEquals("Clean record" to PillKind.Success, disputeRatePillTextAndKind(0.0))
    }

    @Test fun `low dispute rate reads Low with Warn tone`() {
        assertEquals("Low" to PillKind.Warn, disputeRatePillTextAndKind(2.0))
    }

    @Test fun `elevated dispute rate reads Elevated with Danger tone`() {
        assertEquals("Elevated" to PillKind.Danger, disputeRatePillTextAndKind(9.0))
    }
}
