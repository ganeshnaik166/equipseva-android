package com.equipseva.app.core.data.calls

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the response-shape contract between Android and the
 * `request-call-session` edge function. Every documented code in
 * `supabase/functions/request-call-session/index.ts` must map onto a typed
 * variant of [VirtualCallRepository.CallSessionResult] — otherwise the UI
 * silently falls into the generic Error bucket and we lose the
 * "calls coming soon" / rate-limit / missing-phone UX affordances.
 */
class CallSessionResponseMapperTest {

    @Test fun `200 with full success body maps to ClickToCall`() {
        val result = CallSessionResponseMapper.map(
            httpStatus = 200,
            body = """{"ok":true,"mode":"click_to_call","message":"Connecting your call…","call_sid":"sid-123"}""",
        )

        assertTrue(result is VirtualCallRepository.CallSessionResult.ClickToCall)
        val click = result as VirtualCallRepository.CallSessionResult.ClickToCall
        assertEquals("Connecting your call…", click.message)
        assertEquals("sid-123", click.callSid)
    }

    @Test fun `200 with no message falls back to default copy`() {
        val result = CallSessionResponseMapper.map(
            httpStatus = 200,
            body = """{"ok":true,"mode":"click_to_call"}""",
        )

        val click = result as VirtualCallRepository.CallSessionResult.ClickToCall
        assertEquals("Connecting your call…", click.message)
        assertNull(click.callSid)
    }

    @Test fun `200 with unparseable body still emits ClickToCall default`() {
        // The function only writes a 200 after Exotel acknowledged the bridge,
        // so even a transport-level body corruption should not get bumped into
        // the Error bucket — show the connecting toast and let the user retry
        // if their phone doesn't ring.
        val result = CallSessionResponseMapper.map(httpStatus = 200, body = "<html>oops</html>")
        assertTrue(result is VirtualCallRepository.CallSessionResult.ClickToCall)
    }

    @Test fun `503 provider_not_configured surfaces as ProviderNotConfigured`() {
        val result = CallSessionResponseMapper.map(
            httpStatus = 503,
            body = """{"ok":false,"code":"provider_not_configured","message":"Calls coming soon"}""",
        )
        assertEquals(
            VirtualCallRepository.CallSessionResult.ProviderNotConfigured,
            result,
        )
    }

    @Test fun `429 rate_limited carries the server message`() {
        val result = CallSessionResponseMapper.map(
            httpStatus = 429,
            body = """{"ok":false,"code":"rate_limited","message":"Daily limit reached (5)."}""",
        )
        assertTrue(result is VirtualCallRepository.CallSessionResult.RateLimited)
        assertEquals(
            "Daily limit reached (5).",
            (result as VirtualCallRepository.CallSessionResult.RateLimited).message,
        )
    }

    @Test fun `429 rate_limited without a message uses default copy`() {
        val result = CallSessionResponseMapper.map(
            httpStatus = 429,
            body = """{"ok":false,"code":"rate_limited"}""",
        )
        assertEquals(
            "Too many call attempts today.",
            (result as VirtualCallRepository.CallSessionResult.RateLimited).message,
        )
    }

    @Test fun `422 missing_phone surfaces as MissingPhone`() {
        val result = CallSessionResponseMapper.map(
            httpStatus = 422,
            body = """{"ok":false,"code":"missing_phone","message":"Counterpart KYC incomplete"}""",
        )
        assertEquals(
            VirtualCallRepository.CallSessionResult.MissingPhone,
            result,
        )
    }

    @Test fun `403 not_participant surfaces as NotParticipant`() {
        val result = CallSessionResponseMapper.map(
            httpStatus = 403,
            body = """{"ok":false,"code":"not_participant","message":"Stop snooping"}""",
        )
        assertEquals(
            VirtualCallRepository.CallSessionResult.NotParticipant,
            result,
        )
    }

    @Test fun `404 job_not_found falls into the generic Error bucket`() {
        val result = CallSessionResponseMapper.map(
            httpStatus = 404,
            body = """{"ok":false,"code":"job_not_found","message":"No such job"}""",
        )
        assertTrue(result is VirtualCallRepository.CallSessionResult.Error)
        assertEquals(
            "No such job",
            (result as VirtualCallRepository.CallSessionResult.Error).message,
        )
    }

    @Test fun `502 exotel_error falls into the generic Error bucket`() {
        val result = CallSessionResponseMapper.map(
            httpStatus = 502,
            body = """{"ok":false,"code":"exotel_error","message":"Exotel 5xx"}""",
        )
        assertTrue(result is VirtualCallRepository.CallSessionResult.Error)
    }

    @Test fun `unparseable error body keeps the HTTP code in the fallback copy`() {
        val result = CallSessionResponseMapper.map(httpStatus = 500, body = "<nginx 500>")
        val err = result as VirtualCallRepository.CallSessionResult.Error
        assertTrue(err.message.contains("500"))
    }

    @Test fun `error code we don't recognise becomes Error with server message`() {
        // Forwards-compat — if the function ships a new code, the user still
        // sees a meaningful message instead of a no-op crash.
        val result = CallSessionResponseMapper.map(
            httpStatus = 418,
            body = """{"ok":false,"code":"teapot","message":"I'm a teapot"}""",
        )
        val err = result as VirtualCallRepository.CallSessionResult.Error
        assertEquals("I'm a teapot", err.message)
    }
}
