package com.equipseva.app.core.observability

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotSame
import org.junit.Assert.assertNull
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
        assertEquals("original class preserved for dashboard grouping", "java.lang.IllegalStateException: login failed for [redacted]", ex.toString())
        assertArrayEquals("stack trace copied, not referenced", original.stackTrace, ex.stackTrace)
        assertNull("the original must not be reachable — both reporters serialise the cause chain", ex.cause)
    }

    @Test fun `every element of the rebuilt chain is a scrubbed copy`() {
        // Critical pin — the wrapper used to keep the ORIGINAL as its
        // cause, and Crashlytics serialises the whole chain, so the raw
        // message shipped anyway under a "redacted" top level.
        val root = IllegalStateException("contact user@hospital.in on 9876543210")
        val out = wrapScrubbedThrowable(RuntimeException("upload failed", root))

        val chain = generateSequence(out) { it.cause }.toList()
        assertEquals(2, chain.size)
        chain.forEach { link ->
            assertTrue("expected ScrubbedException, got ${link::class.java.name}", link is ScrubbedException)
            assertFalse("PII survived in: ${link.message}", link.message.orEmpty().contains("@hospital.in"))
            assertFalse("PII survived in: ${link.message}", link.message.orEmpty().contains("9876543210"))
        }
        assertEquals("java.lang.RuntimeException: upload failed", chain[0].toString())
        assertEquals("java.lang.IllegalStateException: contact [redacted] on [redacted]", chain[1].toString())
    }

    @Test fun `a clean top-level message does not exempt a PII-bearing cause`() {
        // The old gate returned early whenever the TOP message needed no
        // redaction, so a repository exception wrapping a RestException
        // (whose message embeds the request URL) was never scrubbed.
        val out = wrapScrubbedThrowable(
            IllegalStateException(
                "Could not load profile",
                RuntimeException("GET /rest/v1/users?token=abc123DEF failed"),
            ),
        )
        val leaked = generateSequence(out) { it.cause }.any { it.message.orEmpty().contains("abc123DEF") }
        assertFalse("signed-url token reached the reporter", leaked)
    }

    @Test fun `a self-referencing cause terminates instead of looping`() {
        // initCause rejects only a depth-1 self reference, so a two-element
        // cycle is legal on the JVM and a naive walk never returns.
        val a = RuntimeException("a user@hospital.in")
        val b = RuntimeException("b", a)
        a.initCause(b)

        val chain = generateSequence(wrapScrubbedThrowable(a)) { it.cause }.toList()
        assertEquals(2, chain.size)
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
