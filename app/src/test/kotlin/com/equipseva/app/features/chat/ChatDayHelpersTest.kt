package com.equipseva.app.features.chat

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import java.time.LocalDate

/**
 * Pins the three chat-day helpers used by the day-separator header on
 * the message list:
 *
 *   * [formatTime] — wall-clock IST "HH:mm" for a single message
 *     timestamp; null when the ISO is missing or unparseable so the
 *     row hides the timestamp entirely.
 *   * [dayKey] — the local-IST date key used to group messages into
 *     "day buckets"; falls back to "unknown" so a single garbage
 *     timestamp doesn't crash the list.
 *   * [dayLabelAt] (pure form of [dayLabel]) — the user-facing
 *     header copy. Today / Yesterday / "dd MMM" pattern.
 *
 * Caught here so a refactor that touched the IST handling (e.g.
 * switched to system default zone) would break the day-boundary on
 * carrier-flashed UTC devices.
 */
class ChatDayHelpersTest {

    // ---- formatTime ----

    @Test fun `formatTime renders IST 12-hour clock with AM PM`() {
        // 2026-05-21 04:30Z = 10:00 IST → 10:00 AM (formatter is `h:mm a`).
        assertEquals("10:00 AM", formatTime("2026-05-21T04:30:00Z"))
    }

    @Test fun `formatTime renders single-digit hour without zero pad`() {
        // 2026-05-20 23:30Z = 05:00 IST next day. Formatter uses `h`
        // not `hh`, so single-digit hours stay un-padded. Pin so the
        // chat row reads "5:00 AM" not "05:00 AM".
        assertEquals("5:00 AM", formatTime("2026-05-20T23:30:00Z"))
    }

    @Test fun `formatTime renders PM for IST afternoon`() {
        // 2026-05-21 10:30Z = 16:00 IST → 4:00 PM.
        assertEquals("4:00 PM", formatTime("2026-05-21T10:30:00Z"))
    }

    @Test fun `formatTime null on null or unparseable input`() {
        assertNull(formatTime(null))
        assertNull(formatTime("not-iso"))
        assertNull(formatTime(""))
    }

    // ---- dayKey ----

    @Test fun `dayKey returns the IST date as the string key`() {
        assertEquals("2026-05-21", dayKey("2026-05-20T23:30:00Z"))
        // 04:30Z = 10:00 IST same day → same key.
        assertEquals("2026-05-21", dayKey("2026-05-21T04:30:00Z"))
    }

    @Test fun `dayKey returns unknown for null or unparseable input`() {
        assertEquals("unknown", dayKey(null))
        assertEquals("unknown", dayKey("garbage"))
    }

    // ---- dayLabelAt ----

    @Test fun `dayLabelAt returns Today for today's key`() {
        assertEquals("Today", dayLabelAt("2026-05-21", LocalDate.of(2026, 5, 21)))
    }

    @Test fun `dayLabelAt returns Yesterday for yesterday's key`() {
        assertEquals("Yesterday", dayLabelAt("2026-05-20", LocalDate.of(2026, 5, 21)))
    }

    @Test fun `dayLabelAt renders dd MMM for older dates`() {
        // 3 days ago — "18 May" (ENGLISH, no year)
        assertEquals("18 May", dayLabelAt("2026-05-18", LocalDate.of(2026, 5, 21)))
    }

    @Test fun `dayLabelAt returns empty string for unknown key`() {
        assertEquals("", dayLabelAt("unknown", LocalDate.of(2026, 5, 21)))
    }

    @Test fun `dayLabelAt returns empty for malformed key`() {
        // Defensive — a future refactor that wrote an unexpected key
        // (eg. an Instant string) must not crash the row.
        assertEquals("", dayLabelAt("2026-13-99", LocalDate.of(2026, 5, 21)))
        assertEquals("", dayLabelAt("oops", LocalDate.of(2026, 5, 21)))
    }
}
