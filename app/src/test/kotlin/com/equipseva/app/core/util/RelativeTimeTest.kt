package com.equipseva.app.core.util

import org.junit.Assert.assertEquals
import org.junit.Test
import java.time.Instant
import java.time.temporal.ChronoUnit

class RelativeTimeTest {

    private val now: Instant = Instant.parse("2026-04-24T10:00:00Z")

    @Test fun `under 1 minute reads as now`() {
        assertEquals("now", relativeLabel(now.minusSeconds(30), now))
    }

    @Test fun `minutes hours days weeks`() {
        assertEquals("5m", relativeLabel(now.minus(5, ChronoUnit.MINUTES), now))
        assertEquals("3h", relativeLabel(now.minus(3, ChronoUnit.HOURS), now))
        assertEquals("2d", relativeLabel(now.minus(2, ChronoUnit.DAYS), now))
        assertEquals("4w", relativeLabel(now.minus(28, ChronoUnit.DAYS), now))
    }

    @Test fun `countdown due now inside the last minute window`() {
        assertEquals("Due now", countdownLabel(now, now))
        assertEquals("Due now", countdownLabel(now.plusSeconds(30), now))
        assertEquals("Due now", countdownLabel(now.minusSeconds(30), now))
    }

    @Test fun `countdown future uses Due in chunk`() {
        assertEquals("Due in 30m", countdownLabel(now.plus(30, ChronoUnit.MINUTES), now))
        assertEquals("Due in 4h", countdownLabel(now.plus(4, ChronoUnit.HOURS), now))
        assertEquals("Due in 3d", countdownLabel(now.plus(3, ChronoUnit.DAYS), now))
    }

    @Test fun `countdown past uses Overdue by chunk`() {
        assertEquals("Overdue by 45m", countdownLabel(now.minus(45, ChronoUnit.MINUTES), now))
        assertEquals("Overdue by 2h", countdownLabel(now.minus(2, ChronoUnit.HOURS), now))
        assertEquals("Overdue by 1d", countdownLabel(now.minus(1, ChronoUnit.DAYS), now))
    }

    // Round 394 — overload that accepts ISO-8601 strings + tolerates
    // null / malformed input. Callers (founder lists, integrity feed,
    // payments rows) feed raw RPC timestamps; a parse failure must not
    // crash the screen.
    @Test fun `relativeLabel iso null returns null`() {
        org.junit.Assert.assertNull(relativeLabel(null as String?, now))
    }

    @Test fun `relativeLabel iso malformed returns null`() {
        org.junit.Assert.assertNull(relativeLabel("not-an-instant", now))
        org.junit.Assert.assertNull(relativeLabel("", now))
        org.junit.Assert.assertNull(relativeLabel("2026-05-19", now)) // bare date, no time
    }

    @Test fun `relativeLabel iso parses canonical Z`() {
        assertEquals("3h", relativeLabel("2026-04-24T07:00:00Z", now))
    }

    @Test fun `relativeLabel iso parses offset form`() {
        // 12:30 +05:30 == 07:00 UTC = 3h before our `now`.
        assertEquals("3h", relativeLabel("2026-04-24T12:30:00+05:30", now))
    }
}
