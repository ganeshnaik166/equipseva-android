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
}
