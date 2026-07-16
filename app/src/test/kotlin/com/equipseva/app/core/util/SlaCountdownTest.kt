package com.equipseva.app.core.util

import org.junit.Assert.assertEquals
import org.junit.Test

/** Pins the r1429 short-horizon SLA countdown helpers (pure over epoch ms). */
class SlaCountdownTest {

    private val now = 1_000_000_000_000L // arbitrary fixed "now"
    private fun inMin(m: Long) = now + m * 60_000L

    @Test fun `overdue once the deadline has passed`() {
        assertEquals("Overdue", slaCountdownLabel(now - 1, now))
        assertEquals("Overdue", slaCountdownLabel(now, now))
        assertEquals(SlaUrgency.Overdue, slaUrgency(now - 1, now))
    }

    @Test fun `sub-minute reads less than a minute`() {
        assertEquals("<1m left", slaCountdownLabel(now + 30_000L, now))
    }

    @Test fun `minutes-only within the hour`() {
        assertEquals("12m left", slaCountdownLabel(inMin(12), now))
        assertEquals("59m left", slaCountdownLabel(inMin(59), now))
    }

    @Test fun `whole hours drop the minute part`() {
        assertEquals("1h left", slaCountdownLabel(inMin(60), now))
        assertEquals("2h left", slaCountdownLabel(inMin(120), now))
    }

    @Test fun `hours and minutes combine`() {
        assertEquals("1h 5m left", slaCountdownLabel(inMin(65), now))
    }

    @Test fun `urgency buckets at the 15-minute window`() {
        assertEquals(SlaUrgency.Urgent, slaUrgency(inMin(15), now))
        assertEquals(SlaUrgency.Urgent, slaUrgency(inMin(1), now))
        assertEquals(SlaUrgency.Ok, slaUrgency(inMin(16), now))
    }

    @Test fun `iso overloads parse then delegate, null on bad input`() {
        // A far-future instant is never overdue.
        assertEquals(SlaUrgency.Ok, slaUrgency("2999-01-01T00:00:00Z", now))
        assertEquals(null, slaCountdownLabel("not-a-date", now))
        assertEquals(null, slaUrgency(null, now))
    }

    // r1432 — days-aware duration label (escrow release ETA).

    @Test fun `duration is days-aware and drops empty parts`() {
        assertEquals("2d 3h", durationUntilLabel(inMin(2 * 24 * 60 + 3 * 60), now))
        assertEquals("2d", durationUntilLabel(inMin(2 * 24 * 60), now))
        assertEquals("3h 20m", durationUntilLabel(inMin(3 * 60 + 20), now))
        assertEquals("3h", durationUntilLabel(inMin(3 * 60), now))
        assertEquals("45m", durationUntilLabel(inMin(45), now))
        assertEquals("<1m", durationUntilLabel(now + 30_000L, now))
    }

    @Test fun `duration is null once past (caller renders its own now copy)`() {
        assertEquals(null, durationUntilLabel(now, now))
        assertEquals(null, durationUntilLabel(now - 1, now))
        assertEquals(null, durationUntilLabel("not-a-date", now))
    }
}
