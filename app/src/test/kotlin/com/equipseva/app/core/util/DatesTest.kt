package com.equipseva.app.core.util

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class DatesTest {

    @Test fun `parseInstantOrNull returns null for null receiver`() {
        val s: String? = null
        assertNull(s.parseInstantOrNull())
    }

    @Test fun `parseInstantOrNull returns null for malformed input`() {
        assertNull("not-an-instant".parseInstantOrNull())
        assertNull("2026-05-11".parseInstantOrNull()) // bare date, no time zone
        assertNull("".parseInstantOrNull())
    }

    @Test fun `parseInstantOrNull parses canonical ISO-8601 instant`() {
        val parsed = "2026-05-11T07:42:00Z".parseInstantOrNull()
        assertEquals(java.time.Instant.parse("2026-05-11T07:42:00Z"), parsed)
    }

    @Test fun `prettyDate renders ISO date in default zone`() {
        val out = prettyDate("2026-05-11T07:42:00Z")
        // Format is dd MMM yyyy. Exact day might shift by zone but not month/year.
        assert(out.contains("May")) { "expected May in $out" }
        assert(out.contains("2026")) { "expected 2026 in $out" }
    }

    @Test fun `prettyDate falls back on malformed input`() {
        assertEquals("not-an-iso", prettyDate("not-an-iso"))
    }

    @Test fun `prettyDateTime falls back on malformed input`() {
        // First 16 chars with T -> space.
        assertEquals("malformed-input-", prettyDateTime("malformed-input-"))
    }

    // Regression guard for PR #672 — formatters must be pinned to
    // Asia/Kolkata regardless of where the test (or production device)
    // runs. The previous `ZoneId.systemDefault()` made these strings
    // wander by 5h30 on UTC servers / hosts, so we pick a UTC
    // timestamp that crosses the IST midnight boundary.
    @Test fun `prettyDate renders Asia Kolkata day for late-UTC instant`() {
        // 2026-05-10T22:30:00Z = 2026-05-11T04:00:00 in IST.
        assertEquals("11 May 2026", prettyDate("2026-05-10T22:30:00Z"))
    }

    @Test fun `prettyDateTime renders Asia Kolkata clock for late-UTC instant`() {
        // Same instant — IST clock reads 04:00 not 22:30.
        assertEquals("11 May 2026, 04:00", prettyDateTime("2026-05-10T22:30:00Z"))
    }

    // isWithinDays — round 314 Renew-CTA gating. Anchor cases off
    // LocalDate.now(IST) so the test is stable regardless of run time.
    @Test fun `isWithinDays returns false for malformed input`() {
        org.junit.Assert.assertFalse(isWithinDays("not-a-date", 14))
        org.junit.Assert.assertFalse(isWithinDays("", 7))
    }

    @Test fun `isWithinDays returns true for today`() {
        val today = java.time.LocalDate.now(java.time.ZoneId.of("Asia/Kolkata")).toString()
        org.junit.Assert.assertTrue(isWithinDays(today, 14))
    }

    @Test fun `isWithinDays returns true for date inside window`() {
        val plusTen = java.time.LocalDate.now(java.time.ZoneId.of("Asia/Kolkata"))
            .plusDays(10).toString()
        org.junit.Assert.assertTrue(isWithinDays(plusTen, 14))
    }

    @Test fun `isWithinDays returns false for date outside window`() {
        val plusThirty = java.time.LocalDate.now(java.time.ZoneId.of("Asia/Kolkata"))
            .plusDays(30).toString()
        org.junit.Assert.assertFalse(isWithinDays(plusThirty, 14))
    }

    @Test fun `isWithinDays returns false for past date`() {
        val yesterday = java.time.LocalDate.now(java.time.ZoneId.of("Asia/Kolkata"))
            .minusDays(1).toString()
        org.junit.Assert.assertFalse(isWithinDays(yesterday, 14))
    }
}
