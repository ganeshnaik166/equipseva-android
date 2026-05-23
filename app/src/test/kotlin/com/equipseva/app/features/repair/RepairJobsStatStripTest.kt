package com.equipseva.app.features.repair

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the two pure helpers behind the engineer feed's stat strip:
 *
 *   * openStatCardLabel — switches between "Open" (All radius) and
 *     "Within N km" so the count never gets decoupled from the
 *     filter that produced it. A regression to a fixed "Nearby"
 *     label would lie about the country-wide All-radius case.
 *   * pendingBidsValue — renders 0 as the em-dash placeholder
 *     (U+2014) rather than a literal "0", which would read as
 *     "you have 0 pending bids" rather than "no active bids yet".
 */
class RepairJobsStatStripTest {

    // ---- openStatCardLabel ----

    @Test fun `null radius (All) reads Open`() {
        assertEquals("Open", openStatCardLabel(null))
    }

    @Test fun `numeric radius reads Within N km`() {
        assertEquals("Within 50 km", openStatCardLabel(50))
        assertEquals("Within 10 km", openStatCardLabel(10))
        assertEquals("Within 100 km", openStatCardLabel(100))
    }

    @Test fun `zero radius still reads Within 0 km (defensive — UI doesn't expose 0)`() {
        // The picker doesn't expose 0 km, but pin a sensible
        // fallback so the helper is total.
        assertEquals("Within 0 km", openStatCardLabel(0))
    }

    @Test fun `label never reads Nearby (regression — that lied on All radius)`() {
        // A previous version always read "Nearby", which lied when
        // the user picked All radius. Pin so a refactor doesn't
        // resurrect that copy.
        listOf(null, 10, 25, 50, 100).forEach { radius ->
            val label = openStatCardLabel(radius)
            assertEquals("label should not contain 'Nearby': $label", false, label.contains("Nearby"))
        }
    }

    // ---- pendingBidsValue ----

    @Test fun `zero pending bids renders as em-dash (U+2014)`() {
        val out = pendingBidsValue(0)
        assertEquals("—", out)
        // Explicit codepoint pin so a future "fix the dash" doesn't
        // swap to ASCII "-".
        assertEquals(true, out.contains('—'))
    }

    @Test fun `negative count also renders as em-dash (defensive)`() {
        // Should be unreachable from the UI but pin so the helper
        // doesn't render "-1" if a bad payload races in.
        assertEquals("—", pendingBidsValue(-1))
    }

    @Test fun `1 pending bid renders as literal 1`() {
        assertEquals("1", pendingBidsValue(1))
    }

    @Test fun `multiple pending bids render as literal count`() {
        assertEquals("5", pendingBidsValue(5))
        assertEquals("42", pendingBidsValue(42))
    }
}
