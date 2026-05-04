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

    @Test fun `aadhaar numbers are redacted`() {
        assertEquals("aadhaar [redacted] failed", CrashDataScrubber.scrub("aadhaar 1234 5678 9012 failed"))
        assertEquals("aadhaar [redacted] failed", CrashDataScrubber.scrub("aadhaar 1234-5678-9012 failed"))
        assertEquals("aadhaar [redacted] failed", CrashDataScrubber.scrub("aadhaar 123456789012 failed"))
    }

    @Test fun `pan numbers are redacted`() {
        assertEquals("pan [redacted] rejected", CrashDataScrubber.scrub("pan ABCDE1234F rejected"))
    }

    @Test fun `gstin numbers are redacted`() {
        assertEquals(
            "gst [redacted] for invoice",
            CrashDataScrubber.scrub("gst 27ABCDE1234F1Z5 for invoice"),
        )
    }

    @Test fun `indian mobile numbers are redacted`() {
        assertEquals("ring [redacted]", CrashDataScrubber.scrub("ring +919876543210"))
        assertEquals("ring [redacted]", CrashDataScrubber.scrub("ring 9876543210"))
        assertEquals("ring [redacted]", CrashDataScrubber.scrub("ring 09876543210"))
    }
}
