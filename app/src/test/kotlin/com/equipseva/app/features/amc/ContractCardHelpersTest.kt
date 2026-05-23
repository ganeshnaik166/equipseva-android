package com.equipseva.app.features.amc

import com.equipseva.app.designsystem.components.PillKind
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ContractCardHelpersTest {

    // ---- contractVisitsLabel -----------------------------------------

    @Test fun `visits label composes N slash M with visits suffix`() {
        assertEquals("4 / 12 visits", contractVisitsLabel(4, 12))
    }

    @Test fun `0 completed shows 0 not blank`() {
        assertEquals("0 / 12 visits", contractVisitsLabel(0, 12))
    }

    @Test fun `quota-exhausted renders verbatim (no special case)`() {
        assertEquals("12 / 12 visits", contractVisitsLabel(12, 12))
    }

    @Test fun `visits suffix is mandatory (not blank, not per year)`() {
        // Pin "visits" — the surface-specific noun, distinct from
        // pausedAmcVisitsLine's "per year".
        val out = contractVisitsLabel(1, 1)
        assertTrue(out.endsWith(" visits"))
    }

    // ---- contractExpiryPillTextAndKind -------------------------------

    @Test fun `null days falls back to Expires prettyDate + Warn`() {
        // Unparseable end date → use the date as-is.
        assertEquals(
            "Expires 31 May 2027" to PillKind.Warn,
            contractExpiryPillTextAndKind(null, "31 May 2027"),
        )
    }

    @Test fun `0 days reads Expires today with Danger`() {
        assertEquals(
            "Expires today" to PillKind.Danger,
            contractExpiryPillTextAndKind(0L, "31 May 2027"),
        )
    }

    @Test fun `negative days (clock skew) also reads Expires today with Danger`() {
        // Defensive — pin so a refactor that branched on `n < 0`
        // separately doesn't slip in.
        assertEquals(
            "Expires today" to PillKind.Danger,
            contractExpiryPillTextAndKind(-3L, "31 May 2027"),
        )
    }

    @Test fun `1 day reads singular Expires in 1 day with Danger`() {
        // Critical pin — singular, not "1 days".
        assertEquals(
            "Expires in 1 day" to PillKind.Danger,
            contractExpiryPillTextAndKind(1L, "x"),
        )
    }

    @Test fun `2 days reads plural N days with Danger`() {
        assertEquals(
            "Expires in 2 days" to PillKind.Danger,
            contractExpiryPillTextAndKind(2L, "x"),
        )
    }

    @Test fun `7 days (boundary INCLUSIVE for Danger)`() {
        // CRITICAL cross-surface invariant — 7 is the boundary
        // INCLUSIVE for Danger. Mirrors
        // expiringAmcPillTextAndKind on the founder side. A drift
        // to <= 6 would silently desynchronise the hospital's
        // renewal banner from the founder's expiring-30d KPI.
        assertEquals(
            "Expires in 7 days" to PillKind.Danger,
            contractExpiryPillTextAndKind(7L, "x"),
        )
    }

    @Test fun `8 days flips to Warn (still in 30d window, but amber)`() {
        assertEquals(
            "Expires in 8 days" to PillKind.Warn,
            contractExpiryPillTextAndKind(8L, "x"),
        )
    }

    @Test fun `30 days reads N days with Warn`() {
        assertEquals(
            "Expires in 30 days" to PillKind.Warn,
            contractExpiryPillTextAndKind(30L, "x"),
        )
    }

    @Test fun `large days remaining reads plural with Warn`() {
        // Caller gates on <= 30, but pin total-function shape.
        assertEquals(
            "Expires in 120 days" to PillKind.Warn,
            contractExpiryPillTextAndKind(120L, "x"),
        )
    }
}
