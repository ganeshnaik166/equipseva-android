package com.equipseva.app.features.repair

import com.equipseva.app.designsystem.components.PillKind
import org.junit.Assert.assertEquals
import org.junit.Test

/** Pins for the r1411 service-report (DSR) helpers. */
class ServiceReportDetailHelpersTest {

    @Test fun `status pill maps signed states to Success`() {
        assertEquals("Signed off" to PillKind.Success, dsrStatusPill("both_signed"))
        assertEquals("Signed off" to PillKind.Success, dsrStatusPill("completed"))
    }

    @Test fun `status pill for engineer-signed and draft`() {
        assertEquals("Awaiting hospital" to PillKind.Warn, dsrStatusPill("engineer_signed"))
        assertEquals("Draft" to PillKind.Neutral, dsrStatusPill("draft"))
        assertEquals("Draft" to PillKind.Neutral, dsrStatusPill(""))
    }

    @Test fun `unknown status de-snakes with Neutral tone`() {
        assertEquals("In review" to PillKind.Neutral, dsrStatusPill("in_review"))
    }

    @Test fun `check pill for pass, fail, not-recorded`() {
        assertEquals("Pass" to PillKind.Success, dsrCheckPill(true))
        assertEquals("Fail" to PillKind.Danger, dsrCheckPill(false))
        assertEquals("—" to PillKind.Neutral, dsrCheckPill(null))
    }
}
