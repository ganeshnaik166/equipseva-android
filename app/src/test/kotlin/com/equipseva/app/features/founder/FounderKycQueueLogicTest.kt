package com.equipseva.app.features.founder

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the three pure derivations on the founder KYC queue row:
 *  - `founderEngineerInitial` — avatar circle glyph.
 *  - `founderEngineerContactLine` — "email · phone" w/ fallback.
 *  - `founderEngineerMetaLine` — experience + radius + location strip.
 */
class FounderKycQueueLogicTest {

    @Test fun `initial returns first uppercased character of name`() {
        // Lowercase input should still render uppercase — pins the
        // `.uppercaseChar()` call so a refactor to `.uppercase()` on
        // the whole string (which would also flip casing of later
        // chars) is rejected.
        assertEquals("R", founderEngineerInitial("Ravi"))
        assertEquals("R", founderEngineerInitial("ravi"))
        assertEquals("D", founderEngineerInitial("dr. Anita"))
    }

    @Test fun `initial falls back to E for empty name`() {
        // E for "engineer" — keeps the avatar non-empty when the RPC
        // returns a profile with a missing full_name.
        assertEquals("E", founderEngineerInitial(""))
    }

    @Test fun `contact line joins email and phone with separator`() {
        assertEquals(
            "ravi@x.in · +91 98...",
            founderEngineerContactLine("ravi@x.in", "+91 98..."),
        )
    }

    @Test fun `contact line drops the separator when only one field`() {
        // Either-only case — never trailing/leading " · ".
        assertEquals("ravi@x.in", founderEngineerContactLine("ravi@x.in", null))
        assertEquals("+91 98...", founderEngineerContactLine(null, "+91 98..."))
    }

    // Blank-string edge cases on contact line are deliberately not pinned
    // here — the helper uses listOfNotNull which only filters nulls, and
    // the exact "blank passes through but joinToString shapes the
    // separator" behaviour is fragile to refactor + the agent flagged it
    // as a future tightening target. A `null` test is below.

    @Test fun `contact line falls back to No contact when both null`() {
        // Only the both-null case triggers the empty-list ifBlank path.
        assertEquals("No contact", founderEngineerContactLine(null, null))
    }

    @Test fun `meta line joins experience, radius, city, state`() {
        // The standard happy-path — all four fields present.
        assertEquals(
            "5 yrs exp · 30km radius · Hyderabad, Telangana",
            founderEngineerMetaLine(
                experienceYears = 5,
                serviceRadiusKm = 30,
                city = "Hyderabad",
                state = "Telangana",
            ),
        )
    }

    @Test fun `meta line drops nullable experience and radius without stray separators`() {
        // Missing fields collapse the strip — no leading " · ".
        assertEquals(
            "Hyderabad, Telangana",
            founderEngineerMetaLine(null, null, "Hyderabad", "Telangana"),
        )
        assertEquals(
            "5 yrs exp · Hyderabad",
            founderEngineerMetaLine(5, null, "Hyderabad", null),
        )
    }

    @Test fun `meta line joins city alone or state alone via comma rule`() {
        // The location sub-line uses ", " between city and state, but
        // either one alone should NOT have a trailing comma. Pins the
        // .ifBlank-null fallback so the row stays clean for
        // partially-filled profiles.
        assertEquals("Hyderabad", founderEngineerMetaLine(null, null, "Hyderabad", null))
        assertEquals("Telangana", founderEngineerMetaLine(null, null, null, "Telangana"))
    }

    @Test fun `meta line empty when everything is null`() {
        // Profiles fresh out of signup may have no coverage data —
        // the row should collapse the meta strip rather than render
        // a blank line.
        assertEquals("", founderEngineerMetaLine(null, null, null, null))
    }
}
