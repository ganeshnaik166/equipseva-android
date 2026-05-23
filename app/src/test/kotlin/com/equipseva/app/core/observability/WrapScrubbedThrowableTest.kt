package com.equipseva.app.core.observability

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotSame
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

class WrapScrubbedThrowableTest {

    @Test fun `message without PII returns the original Throwable identity (no wrap)`() {
        // Critical pin — preserving the original Throwable lets
        // Crashlytics / Sentry cluster the report with siblings of
        // the same class. A refactor that always wrapped (even when
        // nothing was redacted) would break that clustering.
        val original = IllegalStateException("simple state error, no PII")
        val out = wrapScrubbedThrowable(original)
        assertSame(original, out)
    }

    @Test fun `message with email is wrapped in ScrubbedException with scrubbed message`() {
        // Critical pin — without the wrap, Crashlytics' default
        // toString() would print the original (PII-bearing) message
        // even though the scrubber redacted it for the log line.
        val original = IllegalStateException("login failed for user@hospital.in")
        val out = wrapScrubbedThrowable(original)

        assertNotSame(original, out)
        assertTrue(out is ScrubbedException)
        val ex = out as ScrubbedException
        assertEquals("login failed for [redacted]", ex.message)
        assertSame("original kept as cause for stack trace", original, ex.cause)
    }

    @Test fun `ScrubbedException toString preserves originalType + scrubbed message`() {
        // Wire-frozen pin — both Crashlytics + Sentry display the
        // exception via toString. A refactor that dropped the
        // originalType prefix would surface "ScrubbedException:
        // [redacted]" in the dashboard, hiding which class actually
        // threw.
        val original = IllegalArgumentException("expected; sub-message has nothing to redact")
        val ex = ScrubbedException(
            originalType = "com.example.MyDomainException",
            message = "login failed for [redacted]",
            cause = original,
        )
        assertEquals(
            "com.example.MyDomainException: login failed for [redacted]",
            ex.toString(),
        )
    }

    @Test fun `ScrubbedException with null message renders prefix and empty body`() {
        // Defensive — message can be null on some Throwables; the
        // toString must NOT print "null" as that would muddy the
        // dashboard grouping.
        val ex = ScrubbedException(
            originalType = "kotlin.IllegalStateException",
            message = null,
            cause = RuntimeException(),
        )
        assertEquals("kotlin.IllegalStateException: ", ex.toString())
    }

    @Test fun `JWT in message triggers the wrap`() {
        // CrashDataScrubber redacts JWTs starting with "eyJ"; the
        // wrap must fire when the body is rewritten.
        val original = RuntimeException(
            "Auth header bearer eyJabcdefgh.eyJijklmnop.eyJqrstuvwx",
        )
        val out = wrapScrubbedThrowable(original)
        assertNotSame(original, out)
        assertTrue("expected ScrubbedException, got ${out::class.java.simpleName}", out is ScrubbedException)
    }

    @Test fun `Razorpay payment id in message triggers the wrap`() {
        val original = RuntimeException("Order pay_KBQyaQABCD1234 rejected")
        val out = wrapScrubbedThrowable(original)
        assertNotSame(original, out)
    }

    @Test fun `null original message preserves identity (nothing to scrub)`() {
        // RuntimeException() with no message → scrubber returns null
        // (unchanged) → wrap returns original.
        val original = RuntimeException()
        val out = wrapScrubbedThrowable(original)
        assertSame(original, out)
    }
}
