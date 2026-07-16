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
        assertEquals("Awaiting hospital" to PillKind.Warn, dsrStatusPill("pending_hospital_sign"))
        assertEquals("Draft" to PillKind.Neutral, dsrStatusPill("draft"))
        assertEquals("Draft" to PillKind.Neutral, dsrStatusPill(""))
    }

    // r1421 — hospital sign flow.

    @Test fun `only pending-hospital-sign is signable`() {
        assertEquals(true, canSignDsr("pending_hospital_sign"))
        assertEquals(false, canSignDsr("engineer_signed"))
        assertEquals(false, canSignDsr("signed"))
        assertEquals(false, canSignDsr("draft"))
    }

    @Test fun `signer requires name and role of at least three chars`() {
        assertEquals(true, isValidSigner("Anita Rao", "Biomedical Head"))
        assertEquals(false, isValidSigner("Al", "Head"))
        assertEquals(false, isValidSigner("Anita", "HR"))
        assertEquals(false, isValidSigner("  ", "  "))
    }

    @Test fun `unknown status de-snakes with Neutral tone`() {
        assertEquals("In review" to PillKind.Neutral, dsrStatusPill("in_review"))
    }

    @Test fun `check pill for pass, fail, not-recorded`() {
        assertEquals("Pass" to PillKind.Success, dsrCheckPill(true))
        assertEquals("Fail" to PillKind.Danger, dsrCheckPill(false))
        assertEquals("—" to PillKind.Neutral, dsrCheckPill(null))
    }

    // r1442 — engineer files the DSR.

    @Test fun `work summary needs at least 20 trimmed chars`() {
        assertEquals(false, isValidWorkSummary("Replaced the fuse"))
        assertEquals(false, isValidWorkSummary("   short   "))
        assertEquals(true, isValidWorkSummary("Replaced compressor and verified cooling to spec"))
        assertEquals(true, isValidWorkSummary("x".repeat(20)))
        assertEquals(false, isValidWorkSummary("x".repeat(19)))
    }
}
