package com.equipseva.app.features.home

import java.time.Instant
import java.time.temporal.ChronoUnit
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the pure non-Composable helpers sitting at the bottom of
 * HomeHubScreen — the greeting bucket and the "X ago" formatter. Both
 * were previously reading the wall clock directly which made them
 * untestable; they're now parameter-driven thin wrappers.
 */
class HomeHubScreenHelpersTest {

    /* --------- greetingForHour --------- */

    @Test fun `greetingForHour returns Good morning before noon`() {
        assertEquals("Good morning", greetingForHour(0))
        assertEquals("Good morning", greetingForHour(7))
        assertEquals("Good morning", greetingForHour(11))
    }

    @Test fun `greetingForHour switches to afternoon at noon`() {
        // Boundary: 12 is afternoon, not morning. The `< 12` check shipped
        // wrong once (`<= 12`) so the boundary is worth pinning.
        assertEquals("Good afternoon", greetingForHour(12))
        assertEquals("Good afternoon", greetingForHour(16))
    }

    @Test fun `greetingForHour switches to evening at 5pm`() {
        assertEquals("Good evening", greetingForHour(17))
        assertEquals("Good evening", greetingForHour(20))
        assertEquals("Good evening", greetingForHour(23))
    }

    /* --------- relativeTimeBetween --------- */

    private val now: Instant = Instant.parse("2026-05-20T12:00:00Z")

    @Test fun `relativeTimeBetween returns empty for null timestamp`() {
        assertEquals("", relativeTimeBetween(null, now))
    }

    @Test fun `relativeTimeBetween rounds sub-minute deltas to just now`() {
        val at = now.minus(30, ChronoUnit.SECONDS)
        assertEquals("just now", relativeTimeBetween(at, now))
    }

    @Test fun `relativeTimeBetween formats minute deltas with m ago`() {
        assertEquals("1m ago", relativeTimeBetween(now.minus(1, ChronoUnit.MINUTES), now))
        assertEquals("45m ago", relativeTimeBetween(now.minus(45, ChronoUnit.MINUTES), now))
        assertEquals("59m ago", relativeTimeBetween(now.minus(59, ChronoUnit.MINUTES), now))
    }

    @Test fun `relativeTimeBetween formats hour deltas with h ago at the 60m boundary`() {
        assertEquals("1h ago", relativeTimeBetween(now.minus(60, ChronoUnit.MINUTES), now))
        assertEquals("3h ago", relativeTimeBetween(now.minus(3, ChronoUnit.HOURS), now))
        assertEquals("23h ago", relativeTimeBetween(now.minus(23, ChronoUnit.HOURS), now))
    }

    @Test fun `relativeTimeBetween formats day deltas with d ago at the 24h boundary`() {
        assertEquals("1d ago", relativeTimeBetween(now.minus(24, ChronoUnit.HOURS), now))
        assertEquals("3d ago", relativeTimeBetween(now.minus(3, ChronoUnit.DAYS), now))
    }

    @Test fun `relativeTimeBetween floors fractional buckets toward the lower unit`() {
        // 119 min → 1h, not "2h". Floor division is the shipped behaviour
        // and the friendlier UX (we'd rather under-promise recency).
        assertEquals("1h ago", relativeTimeBetween(now.minus(119, ChronoUnit.MINUTES), now))
    }
}
