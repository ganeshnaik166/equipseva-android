package com.equipseva.app.features.founder

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ExpiringAmcRowHelpersTest {

    // ---- expiringAmcRowEndLine ---------------------------------------

    @Test fun `composes Ends date middle-dot fee per month`() {
        val out = expiringAmcRowEndLine("31 May 2027", 50_000.0)
        assertTrue(out.startsWith("Ends 31 May 2027 · "))
        assertTrue(out.endsWith(" / month"))
    }

    @Test fun `Ends prefix is preserved (not Term or Expires)`() {
        // Pin "Ends" — sibling pausedAmcTermLine says "Term" but the
        // expiring queue is focused on the END date only.
        val out = expiringAmcRowEndLine("x", 1.0)
        assertTrue(out.startsWith("Ends "))
    }

    @Test fun `space-slash-space-month suffix preserved`() {
        val out = expiringAmcRowEndLine("x", 1.0)
        assertTrue(out.endsWith(" / month"))
        assertEquals(false, out.endsWith("/month"))
    }

    @Test fun `middle dot separator is U+00B7`() {
        val out = expiringAmcRowEndLine("x", 1.0)
        assertTrue(out.contains(" · "))
    }

    // ---- renewalRemindersSentLabel -----------------------------------

    @Test fun `composes count slash 3`() {
        assertEquals("Reminders sent: 1/3", renewalRemindersSentLabel(1))
        assertEquals("Reminders sent: 2/3", renewalRemindersSentLabel(2))
        assertEquals("Reminders sent: 3/3", renewalRemindersSentLabel(3))
    }

    @Test fun `slash 3 denominator is mandatory (load-bearing cadence)`() {
        // Pin "/3" — a refactor to bare "N reminders sent" would lose
        // the cadence anchor (the founder needs to know it's out of 3,
        // not out of unlimited).
        val out = renewalRemindersSentLabel(2)
        assertTrue(out.contains("/3"))
    }

    @Test fun `0 reminders renders verbatim (defensive — caller gates on positive)`() {
        assertEquals("Reminders sent: 0/3", renewalRemindersSentLabel(0))
    }

    @Test fun `over-3 reminders renders verbatim (defensive — server caps but pin total)`() {
        // Pin defensively — if server ever sends 4+, render verbatim.
        assertEquals("Reminders sent: 4/3", renewalRemindersSentLabel(4))
    }

    @Test fun `Reminders sent prefix preserved verbatim`() {
        // Pin literal — "Reminders" not "Notifications" (the server
        // column name uses "renewal_notifications_sent" but the UI
        // calls them reminders for clarity).
        val out = renewalRemindersSentLabel(1)
        assertTrue(out.startsWith("Reminders sent: "))
    }
}
