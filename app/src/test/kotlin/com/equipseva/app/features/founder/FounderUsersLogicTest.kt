package com.equipseva.app.features.founder

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the avatar-initial fallback chain on the founder Users row:
 * fullName.first → email.first → "?". Lowercase input is upper-cased
 * so the rendered glyph is consistent.
 */
class FounderUsersLogicTest {

    @Test fun `prefers full name initial when both present`() {
        // Both name and email populated — name wins.
        assertEquals(
            "A",
            founderUserInitial("Anita Rao", "irrelevant@x.in"),
        )
    }

    @Test fun `falls through to email initial when name is missing`() {
        // Common case for social-only signups where the profile row
        // hasn't been completed yet.
        assertEquals("R", founderUserInitial(null, "ravi@x.in"))
    }

    @Test fun `blank-string name passes the space through as the initial`() {
        // Sharp edge: `?.firstOrNull()` on " " returns ' ' (truthy non-null),
        // so a whitespace-only name renders as a space glyph rather than
        // falling through to the email. Pin the existing behaviour so a
        // refactor that treats blank-as-missing is reviewed; today's
        // call-sites trim before saving so this is a defensive check.
        assertEquals(" ", founderUserInitial(" ", "ravi@x.in"))
    }

    @Test fun `returns question mark when both are null`() {
        // Never empty — the avatar circle always has a glyph.
        assertEquals("?", founderUserInitial(null, null))
    }

    @Test fun `lowercase name input still renders uppercase initial`() {
        // `.uppercaseChar()` runs on the *first character only*, not
        // on the whole string — pin so we don't accidentally upper-case
        // a multi-char glyph if someone "fixes" the API.
        assertEquals("R", founderUserInitial("ravi reddy", null))
    }
}
