package com.equipseva.app.features.amc

import org.junit.Assert.assertEquals
import org.junit.Test

class AutoPayHaltedPillTextTest {

    @Test fun `halted wire status maps to Halted label`() {
        // Critical pin — matches Razorpay subscription vocabulary
        // which is also what the hospital sees on their bank
        // statement.
        assertEquals("Halted", autoPayHaltedPillText("halted"))
    }

    @Test fun `cancelled wire status maps to Cancelled label`() {
        assertEquals("Cancelled", autoPayHaltedPillText("cancelled"))
    }

    @Test fun `completed wire status maps to Completed label`() {
        assertEquals("Completed", autoPayHaltedPillText("completed"))
    }

    @Test fun `expired wire status maps to Expired label`() {
        assertEquals("Expired", autoPayHaltedPillText("expired"))
    }

    @Test fun `unknown status falls through to Expired (defensive default)`() {
        // Pin defensive fallback for future server enum additions.
        assertEquals("Expired", autoPayHaltedPillText("some_future_state"))
    }

    @Test fun `halted and cancelled use distinct labels`() {
        // Pin distinct labels — a refactor that collapsed them
        // (both rendered Default pill colour) would lose the
        // reconciliation signal.
        assertEquals(false, autoPayHaltedPillText("halted") == autoPayHaltedPillText("cancelled"))
    }

    @Test fun `case-sensitive — Halted capital H falls through to Expired default`() {
        // Pin exact-match. Wire is lowercase.
        assertEquals("Expired", autoPayHaltedPillText("Halted"))
    }
}
