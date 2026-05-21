package com.equipseva.app.features.notifications

import com.equipseva.app.core.data.notifications.Notification
import org.junit.Assert.assertEquals
import org.junit.Test
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

/**
 * Pins the inbox grouping: notifications bucket into "Today /
 * Yesterday / Last week / Earlier" headers using the wall-clock day in
 * IST. Two things this catches:
 *
 *   1) The grouping is by *date in IST*, not by elapsed-hours. A
 *      notification at 11:30 PM IST and one at 12:30 AM IST the next
 *      day end up in different buckets even though they're an hour
 *      apart. Caught here so a refactor doesn't switch to a
 *      Duration-based scheme that would re-bucket on DST or
 *      cross-zone devices.
 *   2) `sentAt = null` (legacy rows) falls back to Instant.EPOCH —
 *      they bucket under "Earlier", not crash.
 */
class GroupByDayAtTest {

    private val zone = ZoneId.of("Asia/Kolkata")

    private fun n(id: String, instant: Instant?): Notification = Notification(
        id = id,
        title = "t",
        body = "b",
        kind = null,
        data = emptyMap(),
        sentAt = instant,
        readAt = null,
        deepLink = null,
    )

    @Test fun `empty input yields empty output`() {
        val out = groupByDayAt(emptyList(), LocalDate.of(2026, 5, 21), zone)
        assertEquals(emptyList<Pair<String, List<Notification>>>(), out)
    }

    @Test fun `same-day notification buckets under Today`() {
        val today = LocalDate.of(2026, 5, 21)
        // 5:00 AM IST on 2026-05-21 → 2026-05-20T23:30:00Z (IST = UTC+5:30).
        val rows = listOf(n("a", Instant.parse("2026-05-20T23:30:00Z")))
        val out = groupByDayAt(rows, today, zone)
        assertEquals(1, out.size)
        assertEquals("Today", out[0].first)
        assertEquals(listOf("a"), out[0].second.map { it.id })
    }

    @Test fun `previous calendar day buckets under Yesterday`() {
        val today = LocalDate.of(2026, 5, 21)
        // Noon on 2026-05-20 IST.
        val rows = listOf(n("a", Instant.parse("2026-05-20T06:30:00Z")))
        val out = groupByDayAt(rows, today, zone)
        assertEquals("Yesterday", out[0].first)
    }

    @Test fun `3 days ago buckets under Last week`() {
        val today = LocalDate.of(2026, 5, 21)
        val rows = listOf(n("a", Instant.parse("2026-05-18T06:30:00Z")))
        val out = groupByDayAt(rows, today, zone)
        assertEquals("Last week", out[0].first)
    }

    @Test fun `exactly 6 days ago still buckets under Last week`() {
        val today = LocalDate.of(2026, 5, 21)
        val rows = listOf(n("a", Instant.parse("2026-05-15T06:30:00Z")))
        val out = groupByDayAt(rows, today, zone)
        assertEquals("Last week", out[0].first)
    }

    @Test fun `7-or-more days ago buckets under Earlier`() {
        val today = LocalDate.of(2026, 5, 21)
        val rows = listOf(n("a", Instant.parse("2026-05-14T06:30:00Z")))
        val out = groupByDayAt(rows, today, zone)
        assertEquals("Earlier", out[0].first)
    }

    @Test fun `null sentAt falls back to epoch which buckets under Earlier`() {
        val today = LocalDate.of(2026, 5, 21)
        val rows = listOf(n("legacy", null))
        val out = groupByDayAt(rows, today, zone)
        assertEquals("Earlier", out[0].first)
    }

    @Test fun `buckets preserve insertion order and group multiple per header`() {
        val today = LocalDate.of(2026, 5, 21)
        val rows = listOf(
            n("t1", Instant.parse("2026-05-20T23:30:00Z")),  // today (5am IST)
            n("y1", Instant.parse("2026-05-20T06:30:00Z")),  // yesterday
            n("t2", Instant.parse("2026-05-21T05:00:00Z")),  // today (10:30am IST)
            n("e1", Instant.parse("2026-04-01T00:00:00Z")),  // earlier
        )
        val out = groupByDayAt(rows, today, zone)
        // Order: Today (rows 0,2), Yesterday (row 1), Earlier (row 3).
        // Pin the insertion order — the screen renders headers in
        // arrival order so the most-recent-day shows first when
        // recent items arrive first.
        assertEquals(listOf("Today", "Yesterday", "Earlier"), out.map { it.first })
        assertEquals(listOf("t1", "t2"), out[0].second.map { it.id })
        assertEquals(listOf("y1"), out[1].second.map { it.id })
        assertEquals(listOf("e1"), out[2].second.map { it.id })
    }

    @Test fun `future-dated sentAt still buckets under Today on clock skew`() {
        // Server clock skew can stamp a notification slightly into the
        // future; bucket those as Today rather than ducking the row.
        val today = LocalDate.of(2026, 5, 21)
        val rows = listOf(n("a", Instant.parse("2026-05-22T05:00:00Z")))
        val out = groupByDayAt(rows, today, zone)
        assertEquals("Today", out[0].first)
    }
}
