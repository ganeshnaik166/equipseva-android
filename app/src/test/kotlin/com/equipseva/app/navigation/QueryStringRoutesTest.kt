package com.equipseva.app.navigation

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the query-string composition on the navigation routes that
 * accept optional params. Critical: URL encoding on the founder
 * integrity route (names can contain spaces, '&', '?', etc.) and
 * the absent-params short-circuit on requestSentRoute.
 */
class QueryStringRoutesTest {

    // ---- Routes.requestSentRoute -------------------------------------

    @Test fun `both null returns base route with no query string`() {
        assertEquals(
            "hospital/request_sent",
            Routes.requestSentRoute(jobId = null, jobNumber = null),
        )
    }

    @Test fun `jobId only returns single-param query string`() {
        assertEquals(
            "hospital/request_sent?jobId=abc-123",
            Routes.requestSentRoute(jobId = "abc-123", jobNumber = null),
        )
    }

    @Test fun `jobNumber only returns single-param query string`() {
        assertEquals(
            "hospital/request_sent?jobNumber=RPR-2026-00041",
            Routes.requestSentRoute(jobId = null, jobNumber = "RPR-2026-00041"),
        )
    }

    @Test fun `both present joined with ampersand in jobId-first order`() {
        // Pin ordering — jobId comes first, jobNumber second.
        assertEquals(
            "hospital/request_sent?jobId=abc-123&jobNumber=RPR-2026-00041",
            Routes.requestSentRoute(jobId = "abc-123", jobNumber = "RPR-2026-00041"),
        )
    }

    @Test fun `blank jobId is treated as null (no query param appended)`() {
        // Pin the isNullOrBlank gate.
        assertEquals(
            "hospital/request_sent?jobNumber=RPR-2026-00041",
            Routes.requestSentRoute(jobId = "   ", jobNumber = "RPR-2026-00041"),
        )
    }

    @Test fun `blank jobNumber is treated as null`() {
        assertEquals(
            "hospital/request_sent?jobId=abc",
            Routes.requestSentRoute(jobId = "abc", jobNumber = ""),
        )
    }

    @Test fun `both blank returns base route with no query string`() {
        assertEquals(
            "hospital/request_sent",
            Routes.requestSentRoute(jobId = "   ", jobNumber = ""),
        )
    }

    // ---- Routes.founderIntegrityRoute --------------------------------

    @Test fun `null userId returns base route (no query string)`() {
        assertEquals(
            "founder/integrity",
            Routes.founderIntegrityRoute(userId = null, name = null),
        )
    }

    @Test fun `blank userId returns base route`() {
        assertEquals(
            "founder/integrity",
            Routes.founderIntegrityRoute(userId = "   ", name = "anything"),
        )
    }

    @Test fun `userId only returns URL-encoded userId param`() {
        assertEquals(
            "founder/integrity?user=abc-123",
            Routes.founderIntegrityRoute(userId = "abc-123", name = null),
        )
    }

    @Test fun `userId + name returns both params URL-encoded`() {
        assertEquals(
            "founder/integrity?user=abc-123&name=Asha+Rao",
            Routes.founderIntegrityRoute(userId = "abc-123", name = "Asha Rao"),
        )
    }

    @Test fun `name with special chars is URL-encoded`() {
        // Critical pin — names can contain '&' which would break
        // parsing if unencoded.
        val out = Routes.founderIntegrityRoute(
            userId = "abc",
            name = "A & B Co",
        )
        // URLEncoder uses + for space; %26 for &
        assertEquals("founder/integrity?user=abc&name=A+%26+B+Co", out)
    }

    @Test fun `userId with special chars is URL-encoded`() {
        // Defensive — userIds are usually UUIDs but pin the encode.
        val out = Routes.founderIntegrityRoute(
            userId = "weird id?",
            name = null,
        )
        assertTrue(out.contains("user=weird+id%3F"))
    }

    @Test fun `blank name with valid userId omits the name param entirely`() {
        // Pin the isNullOrBlank gate on name when userId is present.
        assertEquals(
            "founder/integrity?user=abc",
            Routes.founderIntegrityRoute(userId = "abc", name = "   "),
        )
        assertEquals(
            "founder/integrity?user=abc",
            Routes.founderIntegrityRoute(userId = "abc", name = ""),
        )
    }
}
