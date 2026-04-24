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
}
