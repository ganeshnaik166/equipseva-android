package com.equipseva.app.core.observability

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class CrashDataScrubberTest {

    @Test fun `null and blank pass through`() {
        assertNull(CrashDataScrubber.scrub(null))
        assertEquals("", CrashDataScrubber.scrub(""))
    }

    @Test fun `emails are redacted`() {
        val out = CrashDataScrubber.scrub("failed for ganesh@example.com")
        assertEquals("failed for [redacted]", out)
    }

    @Test fun `jwts are redacted`() {
        val jwt = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjMifQ.signaturefoo"
        val out = CrashDataScrubber.scrub("Authorization: Bearer $jwt")
        assertTrue(out!!.contains("[redacted]"))
        assertTrue(!out.contains(jwt))
    }

    @Test fun `razorpay ids are redacted`() {
        val out = CrashDataScrubber.scrub("webhook failed for pay_ABC123XYZ order_DEF456UVW")
        assertEquals("webhook failed for [redacted] [redacted]", out)
    }

    @Test fun `authorization header is redacted`() {
        val out = CrashDataScrubber.scrub(
            "GET /rest/v1/orders\nAuthorization: Bearer eyJlongtoken.middle.sig",
        )
        assertTrue(out!!.contains("[redacted]"))
        assertTrue(!out.contains("Bearer eyJ"))
    }

    @Test fun `signed url tokens are redacted`() {
        val out = CrashDataScrubber.scrub(
            "GET https://xyz.supabase.co/storage/v1/object/sign/foo.png?token=abc.def-ghi",
        )
        assertTrue(out!!.contains("[redacted]"))
        assertTrue(!out.contains("abc.def-ghi"))
    }

    @Test fun `multiple substitutions in one string`() {
        val out = CrashDataScrubber.scrub(
            "user ganesh@example.com failed for order_abc123 with pay_xyz999",
        )
        assertEquals(
            "user [redacted] failed for [redacted] with [redacted]",
            out,
        )
    }

    @Test fun `non-matching content passes through unchanged`() {
        val out = CrashDataScrubber.scrub("network timeout after 30s")
        assertEquals("network timeout after 30s", out)
    }

    // Indian phone numbers in exception messages — chat mask (PR #688)
    // already strips them on the wire, but exception text from
    // validation / SMS dispatch / Exotel error paths can still carry
    // raw numbers into Crashlytics / Sentry. Mirror the chat-mask
    // regex behaviour: catches consecutive, separator-style, and
    // +91-prefixed forms.
    @Test fun `consecutive 10-digit phone is redacted`() {
        val out = CrashDataScrubber.scrub("validation failed for phone='9876543210'")
        assertTrue(out!!.contains("[redacted]"))
        assertTrue(!out.contains("9876543210"))
    }

    @Test fun `space-separated phone is redacted`() {
        val out = CrashDataScrubber.scrub("dispatch fail to 9876 543 210")
        assertTrue(out!!.contains("[redacted]"))
        assertTrue(!out.contains("9876"))
    }

    @Test fun `dash-separated phone is redacted`() {
        val out = CrashDataScrubber.scrub("Exotel rejected 98-7654-3210")
        assertTrue(out!!.contains("[redacted]"))
        assertTrue(!out.contains("3210"))
    }

    @Test fun `plus 91 prefixed phone is redacted`() {
        val out = CrashDataScrubber.scrub("SMS to +919812345699 failed")
        assertTrue(out!!.contains("[redacted]"))
        assertTrue(!out.contains("9812345699"))
    }

    @Test fun `phone with email and razorpay id all redacted in one message`() {
        val out = CrashDataScrubber.scrub(
            "user ravi@x.com phone +919876543210 order_abc123 failed",
        )
        assertTrue(out!!.contains("[redacted]"))
        assertTrue(!out.contains("ravi@"))
        assertTrue(!out.contains("9876"))
        assertTrue(!out.contains("order_abc"))
    }
}
