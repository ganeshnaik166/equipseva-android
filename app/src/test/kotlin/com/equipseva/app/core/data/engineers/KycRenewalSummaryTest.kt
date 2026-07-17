package com.equipseva.app.core.data.engineers

import org.junit.Assert.assertEquals
import org.junit.Test

/** Pins for the r1401 engineer KYC-renewal helpers. */
class KycRenewalSummaryTest {

    // ---- renewalUrgency -----------------------------------------------

    @Test fun `just past due within half a day stays due soon`() {
        // r1459: pill must not say Overdue while formatRenewalDue still reads
        // "Due today" (the -0.5..0 window). Overdue cut aligned to <= -0.5.
        assertEquals("due_soon", renewalUrgency(-0.1))
        assertEquals("due_soon", renewalUrgency(-0.4))
    }

    @Test fun `half a day or more past due is overdue`() {
        assertEquals("overdue", renewalUrgency(-0.5))
        assertEquals("overdue", renewalUrgency(-30.0))
    }

    @Test fun `zero to 14 days is due soon`() {
        assertEquals("due_soon", renewalUrgency(0.0))
        assertEquals("due_soon", renewalUrgency(14.0))
    }

    @Test fun `beyond 14 days is scheduled`() {
        assertEquals("scheduled", renewalUrgency(14.01))
        assertEquals("scheduled", renewalUrgency(60.0))
    }

    // ---- formatRenewalDue ---------------------------------------------

    @Test fun `overdue phrasing with plural`() {
        assertEquals("Overdue by 3 days", formatRenewalDue(-3.0))
        assertEquals("Overdue by 1 day", formatRenewalDue(-1.0))
    }

    @Test fun `near zero reads due today`() {
        assertEquals("Due today", formatRenewalDue(0.0))
        assertEquals("Due today", formatRenewalDue(0.4))
        assertEquals("Due today", formatRenewalDue(-0.4))
    }

    @Test fun `future reads due in N days`() {
        assertEquals("Due in 1 day", formatRenewalDue(1.0))
        assertEquals("Due in 10 days", formatRenewalDue(9.6))
    }

    // ---- renewalItemLabel ---------------------------------------------

    @Test fun `known item keys map to labels`() {
        assertEquals("Aadhaar", renewalItemLabel("aadhaar"))
        assertEquals("PAN", renewalItemLabel("pan"))
        assertEquals("Police verification", renewalItemLabel("police_verification"))
        assertEquals("Qualification certificate", renewalItemLabel("qualification_certificate"))
        assertEquals("Profile photo / selfie", renewalItemLabel("selfie"))
    }

    @Test fun `unknown item key de-snakes and capitalises`() {
        assertEquals("Gst certificate", renewalItemLabel("gst_certificate"))
    }
}
