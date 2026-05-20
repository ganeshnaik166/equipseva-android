package com.equipseva.app.core.observability

import org.junit.Assert.assertEquals
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.IOException

/**
 * Pins the throwable-wrapping side of the crash-scrubbing pipeline.
 * Crashlytics + Sentry both consume the exception via toString() /
 * message reads, so we must scrub the message *without* losing the
 * original class name or stack trace (otherwise dashboards lose every
 * grouping signal).
 */
class ScrubExceptionMessageTest {

    @Test fun `safe message returns the original throwable unchanged`() {
        // No wrapping cost when there's nothing to scrub — pin identity
        // so the stack-trace dedup keeps grouping.
        val original = RuntimeException("network timeout after 30s")
        val out = scrubExceptionMessage(original)
        assertSame(original, out)
    }

    @Test fun `email in message swaps into a ScrubbedException with redacted body`() {
        val original = IOException("connection to ganesh@example.com refused")
        val out = scrubExceptionMessage(original)
        assertTrue(out is CrashReporter.ScrubbedException)
        assertTrue(out.message!!.contains("[redacted]"))
        assertTrue(!out.message!!.contains("ganesh@example.com"))
    }

    @Test fun `wrapped exception keeps the original as cause`() {
        val original = IOException("ganesh@example.com refused")
        val out = scrubExceptionMessage(original)
        assertSame(original, out.cause)
    }

    @Test fun `wrapped exception toString preserves the original class name for grouping`() {
        // Crashlytics's signature-based grouping reads the toString() —
        // if we lose the class name in the wrap, every report lands in
        // a generic "RuntimeException" bucket.
        val original = IOException("Authorization: Bearer eyJ.ABC.def")
        val out = scrubExceptionMessage(original) as CrashReporter.ScrubbedException
        val str = out.toString()
        assertTrue("expected java.io.IOException in $str", str.contains("java.io.IOException"))
        assertTrue("expected [redacted] in $str", str.contains("[redacted]"))
        assertTrue("Bearer token leaked in $str", !str.contains("eyJ.ABC.def"))
    }

    @Test fun `null message returns the original throwable unchanged`() {
        val original = RuntimeException()
        val out = scrubExceptionMessage(original)
        assertSame(original, out)
    }

    @Test fun `Aadhaar in message is scrubbed too`() {
        val original = RuntimeException("Failed to verify aadhaar 234123412346")
        val out = scrubExceptionMessage(original)
        assertTrue(out is CrashReporter.ScrubbedException)
        assertTrue(out.message!!.contains("[redacted]"))
        assertTrue(!out.message!!.contains("234123412346"))
    }

    @Test fun `multiple PII tokens are all scrubbed in one pass`() {
        val original = IOException("user ganesh@example.com pan ABCDE1234F")
        val out = scrubExceptionMessage(original)
        val msg = out.message!!
        assertTrue(!msg.contains("ganesh@example.com"))
        assertTrue(!msg.contains("ABCDE1234F"))
        // Both swaps happened — at least two [redacted] markers.
        assertEquals(2, "\\[redacted]".toRegex().findAll(msg).count())
    }
}
