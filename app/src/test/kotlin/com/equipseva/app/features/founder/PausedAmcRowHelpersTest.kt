package com.equipseva.app.features.founder

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the two helpers behind the founder's paused-AMC row term +
 * visits sublines. Critical surfaces: glyph correctness (U+2192,
 * U+00B7) and the load-bearing " per year" suffix on the visits
 * line.
 */
class PausedAmcRowHelpersTest {

    // ---- pausedAmcTermLine -------------------------------------------

    @Test fun `term line composes start arrow end middle-dot fee per month`() {
        val out = pausedAmcTermLine(
            prettyStartDate = "1 Jun 2026",
            prettyEndDate = "31 May 2027",
            monthlyFeeRupees = 50_000.0,
        )
        // formatRupees wraps the amount with the ₹ symbol and Indian
        // grouping; verify the prose anchors around it.
        assertTrue(out.startsWith("Term 1 Jun 2026 → 31 May 2027 · "))
        assertTrue(out.endsWith(" / month"))
    }

    @Test fun `arrow between dates is U+2192 not ASCII pointer`() {
        val out = pausedAmcTermLine("a", "b", 1.0)
        assertTrue(out.contains('→'))
        assertEquals(false, out.contains("->"))
        assertEquals(false, out.contains(" to "))
    }

    @Test fun `middle dot before fee is U+00B7 not bullet`() {
        val out = pausedAmcTermLine("a", "b", 1.0)
        assertTrue(out.contains('·'))
        assertEquals(false, out.contains('•'))
    }

    @Test fun `month suffix has space-slash-space-month not slash-month`() {
        // Pin formatting — typography depends on the spacing.
        val out = pausedAmcTermLine("a", "b", 1.0)
        assertTrue(out.endsWith(" / month"))
        assertEquals(false, out.endsWith("/month"))
        assertEquals(false, out.endsWith(" / monthly"))
    }

    // ---- pausedAmcVisitsLine -----------------------------------------

    @Test fun `visits line composes N slash M per year`() {
        assertEquals(
            "Visits: 4 / 12 per year",
            pausedAmcVisitsLine(4, 12),
        )
    }

    @Test fun `per year suffix is mandatory (no drift to bare slash)`() {
        // Critical pin — without "per year" the line could be
        // mis-read as "N completed, M remaining" instead of "N
        // done out of M annual quota".
        val out = pausedAmcVisitsLine(0, 12)
        assertTrue(out.endsWith(" per year"))
    }

    @Test fun `Visits prefix has trailing colon-space`() {
        // Pin "Visits: " (colon + space), not "Visits " or "Visits-".
        val out = pausedAmcVisitsLine(1, 1)
        assertTrue(out.startsWith("Visits: "))
    }

    @Test fun `zero completed renders 0 not blank`() {
        assertEquals(
            "Visits: 0 / 12 per year",
            pausedAmcVisitsLine(0, 12),
        )
    }

    @Test fun `equal completed and per year renders verbatim (no quota-exhausted special case)`() {
        // Defensive — quota-exhausted on a paused AMC is unusual but
        // possible; pin the helper stays total/plain.
        assertEquals(
            "Visits: 12 / 12 per year",
            pausedAmcVisitsLine(12, 12),
        )
    }
}
