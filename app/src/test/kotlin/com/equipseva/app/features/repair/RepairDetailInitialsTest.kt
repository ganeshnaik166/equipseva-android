package com.equipseva.app.features.repair

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the RepairJobDetail-specific initials helper. The canonical
 * core.util.initialsOf returns the first letter of single-token names
 * ("Priyanka" → "P"); this variant uses the first TWO chars
 * ("Priyanka" → "Pr") so the chat-style avatar header on the detail
 * screen has visual weight even on mononym counterparties.
 *
 * Pinned so a future "merge with the canonical helper" refactor is
 * intentional — the screen-specific UX would silently regress
 * otherwise.
 */
class RepairDetailInitialsTest {

    @Test fun `empty name yields question mark`() {
        assertEquals("?", repairDetailInitials(""))
        assertEquals("?", repairDetailInitials("   "))
    }

    @Test fun `single-word name uses first two chars (not first letter)`() {
        // The divergence from core.util.initialsOf.
        assertEquals("Pr", repairDetailInitials("Priyanka"))
        assertEquals("Ra", repairDetailInitials("Rajesh"))
    }

    @Test fun `single-char name passes through (take(2) on length-1 still works)`() {
        assertEquals("A", repairDetailInitials("A"))
    }

    @Test fun `two-word name uses first letter of each token`() {
        assertEquals("RK", repairDetailInitials("Ravi Kumar"))
        assertEquals("AP", repairDetailInitials("Anjali Patel"))
    }

    @Test fun `three+ word name uses only the first two tokens`() {
        // Pin so the helper doesn't accidentally evolve to use 3 chars
        // — chat avatars assume a 2-char width.
        assertEquals("RK", repairDetailInitials("Ravi K Kumar"))
        assertEquals("MK", repairDetailInitials("M K G Subramanian"))
    }

    @Test fun `extra whitespace between tokens collapses (regex split)`() {
        assertEquals("RK", repairDetailInitials("Ravi    Kumar"))
        assertEquals("RK", repairDetailInitials("Ravi\tKumar"))
    }

    @Test fun `leading-trailing whitespace trimmed before tokenising`() {
        assertEquals("RK", repairDetailInitials("  Ravi Kumar  "))
    }

    @Test fun `Unicode names keep first code-point of each token`() {
        // "रवि कुमार" — Devanagari script. Pin so the regex split
        // doesn't accidentally strip non-ASCII chars and fall back
        // to "?".
        assertEquals(2, repairDetailInitials("रवि कुमार").length)
    }
}
