package com.equipseva.app.features.amc

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the user-visible AMC-contract frequency labels. Three of the
 * four user-facing options re-spell the enum-style key into UI copy
 * ("biweekly" → "Every 2 weeks"); the fallback first-letter-uppercases
 * any unknown value so a future server-side addition still renders
 * something readable. Caught here so a rename or "Every 2 weeks" copy
 * tweak is intentional.
 */
class PrettyFrequencyTest {

    @Test fun `weekly maps to Weekly`() {
        assertEquals("Weekly", prettyFrequency("weekly"))
    }

    @Test fun `biweekly expands to Every 2 weeks copy`() {
        assertEquals("Every 2 weeks", prettyFrequency("biweekly"))
    }

    @Test fun `monthly maps to Monthly`() {
        assertEquals("Monthly", prettyFrequency("monthly"))
    }

    @Test fun `quarterly maps to Quarterly`() {
        assertEquals("Quarterly", prettyFrequency("quarterly"))
    }

    @Test fun `case-insensitive — uppercase input still maps to the override`() {
        assertEquals("Weekly", prettyFrequency("WEEKLY"))
        assertEquals("Every 2 weeks", prettyFrequency("BiWeekly"))
    }

    @Test fun `unknown frequency falls back to first-letter-capitalised input`() {
        assertEquals("Annually", prettyFrequency("annually"))
    }
}
