package com.equipseva.app.features.home

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the two pure helpers behind the home dashboard's greeting
 * banner + "X ago" labels:
 *
 *   * [greetingForHour] — three-bucket greeting; the boundary copy
 *     was reviewed by product and pins are intentional. Morning ends
 *     at noon (exclusive of 12:00) and afternoon ends at 5 PM
 *     (exclusive of 17:00).
 *   * [relativeTimeFromMinutes] — the four-bucket cadence; pin
 *     boundary minutes so a refactor doesn't off-by-one the labels.
 */
class HomeHubHelpersTest {

    // ---- greetingForHour ----

    @Test fun `early morning before noon greets Good morning`() {
        assertEquals("Good morning", greetingForHour(0))
        assertEquals("Good morning", greetingForHour(11))
    }

    @Test fun `noon switches to Good afternoon`() {
        // The bucket gate is strict less-than 12, so noon belongs to
        // afternoon. Pinning so a future tweak (e.g. extending
        // morning through 13:00) doesn't silently drift.
        assertEquals("Good afternoon", greetingForHour(12))
        assertEquals("Good afternoon", greetingForHour(16))
    }

    @Test fun `5 PM and later greets Good evening`() {
        assertEquals("Good evening", greetingForHour(17))
        assertEquals("Good evening", greetingForHour(23))
    }

    // ---- relativeTimeFromMinutes ----

    @Test fun `under one minute reads just now`() {
        assertEquals("just now", relativeTimeFromMinutes(0))
    }

    @Test fun `1 to 59 minutes reads Nm ago`() {
        assertEquals("1m ago", relativeTimeFromMinutes(1))
        assertEquals("59m ago", relativeTimeFromMinutes(59))
    }

    @Test fun `60 to 1439 minutes reads Nh ago via integer division`() {
        assertEquals("1h ago", relativeTimeFromMinutes(60))
        assertEquals("1h ago", relativeTimeFromMinutes(119))
        assertEquals("2h ago", relativeTimeFromMinutes(120))
        // 1439 = 23*60 + 59 → still 23h ago.
        assertEquals("23h ago", relativeTimeFromMinutes(1439))
    }

    @Test fun `24 hours flips to days ago`() {
        assertEquals("1d ago", relativeTimeFromMinutes(60L * 24L))
        assertEquals("1d ago", relativeTimeFromMinutes(60L * 24L * 2 - 1))
        assertEquals("2d ago", relativeTimeFromMinutes(60L * 24L * 2))
    }

    @Test fun `large values still bucket as days, not crash`() {
        assertEquals("30d ago", relativeTimeFromMinutes(60L * 24L * 30))
    }
}
