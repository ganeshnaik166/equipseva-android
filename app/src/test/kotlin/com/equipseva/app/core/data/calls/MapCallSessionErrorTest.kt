package com.equipseva.app.core.data.calls

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the (statusCode, code, message) → [CallSessionResult] error
 * mapper for the in-app masked-call flow. Two precedence regions:
 *
 *   1) A typed body `code` ALWAYS wins over HTTP status (the edge
 *      function emits codes explicitly when it can).
 *   2) Status-only mapping is the fallback when an upstream router
 *      returns its own envelope (no parseable body code).
 *
 * Pin the four-way status fallback (503/422/403/429) so a refactor
 * doesn't accidentally collapse them into a generic Error which the
 * user can't recover from.
 */
class MapCallSessionErrorTest {

    // ---- typed code wins ----

    @Test fun `code provider_not_configured wins regardless of status`() {
        val out = mapCallSessionError(
            statusCode = 200,
            code = "provider_not_configured",
            message = null,
        )
        assertTrue(out is CallSessionResult.ProviderNotConfigured)
    }

    @Test fun `code rate_limited keeps the provided message`() {
        val out = mapCallSessionError(
            statusCode = 503,
            code = "rate_limited",
            message = "Wait 1 minute and retry.",
        )
        assertTrue(out is CallSessionResult.RateLimited)
        assertEquals("Wait 1 minute and retry.", (out as CallSessionResult.RateLimited).message)
    }

    @Test fun `code rate_limited with null message falls back to canned copy`() {
        val out = mapCallSessionError(
            statusCode = 429,
            code = "rate_limited",
            message = null,
        )
        assertEquals(
            "Too many call attempts today.",
            (out as CallSessionResult.RateLimited).message,
        )
    }

    @Test fun `code missing_phone maps to MissingPhone (no message)`() {
        val out = mapCallSessionError(
            statusCode = 422,
            code = "missing_phone",
            message = "ignored",
        )
        assertTrue(out is CallSessionResult.MissingPhone)
    }

    @Test fun `code not_participant maps to NotParticipant`() {
        val out = mapCallSessionError(
            statusCode = 403,
            code = "not_participant",
            message = "ignored",
        )
        assertTrue(out is CallSessionResult.NotParticipant)
    }

    // ---- status-only fallback (when code is null or unrecognised) ----

    @Test fun `null code, 503 maps to ProviderNotConfigured`() {
        val out = mapCallSessionError(statusCode = 503, code = null, message = null)
        assertTrue(out is CallSessionResult.ProviderNotConfigured)
    }

    @Test fun `null code, 422 maps to MissingPhone`() {
        val out = mapCallSessionError(statusCode = 422, code = null, message = null)
        assertTrue(out is CallSessionResult.MissingPhone)
    }

    @Test fun `null code, 403 maps to NotParticipant`() {
        val out = mapCallSessionError(statusCode = 403, code = null, message = null)
        assertTrue(out is CallSessionResult.NotParticipant)
    }

    @Test fun `null code, 429 maps to RateLimited with provided message`() {
        val out = mapCallSessionError(
            statusCode = 429,
            code = null,
            message = "Slow down.",
        )
        assertTrue(out is CallSessionResult.RateLimited)
        assertEquals("Slow down.", (out as CallSessionResult.RateLimited).message)
    }

    @Test fun `null code, 429 with null message uses canned RateLimited copy`() {
        val out = mapCallSessionError(statusCode = 429, code = null, message = null)
        assertEquals(
            "Too many call attempts today.",
            (out as CallSessionResult.RateLimited).message,
        )
    }

    @Test fun `unknown status falls through to generic Error with HTTP code`() {
        val out = mapCallSessionError(statusCode = 500, code = null, message = null)
        assertTrue(out is CallSessionResult.Error)
        assertEquals(
            "Couldn't start the call (HTTP 500).",
            (out as CallSessionResult.Error).message,
        )
    }

    @Test fun `generic Error keeps the provided message when present`() {
        val out = mapCallSessionError(
            statusCode = 500,
            code = null,
            message = "Upstream said no.",
        )
        assertEquals("Upstream said no.", (out as CallSessionResult.Error).message)
    }

    @Test fun `unrecognised typed code falls through to status-only mapping`() {
        // Forward-compat: a future edge-function code that the client
        // doesn't know about must NOT crash — fall through to the
        // status fallback.
        val out = mapCallSessionError(
            statusCode = 422,
            code = "future_unknown_code",
            message = null,
        )
        assertTrue(out is CallSessionResult.MissingPhone)
    }
}
