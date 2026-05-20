package com.equipseva.app.features.founder

import java.time.OffsetDateTime
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the coarse-bucket relative-time formatter on the founder
 * integrity-flags screen. Boundaries: <1m → "now"; <60m → "Xm";
 * <24h → "Xh"; else "Xd". Bad ISO falls back to the 10-char date slug
 * so the row never crashes the LazyColumn.
 */
class FounderIntegrityLogicTest {

    private val fixedNow: Long = OffsetDateTime.parse("2025-04-12T10:00:00Z")
        .toInstant().toEpochMilli()

    private fun ago(seconds: Long): String =
        OffsetDateTime.parse("2025-04-12T10:00:00Z")
            .minusSeconds(seconds)
            .toString()

    @Test fun `sub-minute differences render as now`() {
        assertEquals("now", founderRelativeTime(ago(0), fixedNow))
        assertEquals("now", founderRelativeTime(ago(30), fixedNow))
    }

    @Test fun `minute-scale differences render as Xm`() {
        // 1m and 59m bracket the second bucket.
        assertEquals("1m", founderRelativeTime(ago(60), fixedNow))
        assertEquals("5m", founderRelativeTime(ago(60 * 5), fixedNow))
        assertEquals("59m", founderRelativeTime(ago(60 * 59), fixedNow))
    }

    @Test fun `hour-scale differences render as Xh with integer truncation`() {
        // 60m flips into the hour bucket; partial hours floor.
        assertEquals("1h", founderRelativeTime(ago(60 * 60), fixedNow))
        assertEquals("1h", founderRelativeTime(ago(60 * 90), fixedNow)) // 90m → 1h
        assertEquals("23h", founderRelativeTime(ago(60 * 60 * 23), fixedNow))
    }

    @Test fun `day-scale differences render as Xd once past 24h`() {
        assertEquals("1d", founderRelativeTime(ago(60 * 60 * 24), fixedNow))
        assertEquals("3d", founderRelativeTime(ago(60 * 60 * 24 * 3), fixedNow))
    }

    @Test fun `malformed ISO falls back to the first 10 chars`() {
        // Don't crash on a buggy RPC payload — just surface the leading
        // date slug. 10 chars covers YYYY-MM-DD or shorter.
        assertEquals("not-an-iso", founderRelativeTime("not-an-iso-string", fixedNow))
        assertEquals("", founderRelativeTime("", fixedNow))
    }

    @Test fun `future timestamps (clock skew) collapse to now`() {
        // Server slightly ahead — `mins` goes negative. The first when
        // branch (mins < 1) catches negatives so we don't surface "-1m".
        val future = OffsetDateTime.parse("2025-04-12T10:00:00Z")
            .plusSeconds(30)
            .toString()
        assertEquals("now", founderRelativeTime(future, fixedNow))
    }
}
