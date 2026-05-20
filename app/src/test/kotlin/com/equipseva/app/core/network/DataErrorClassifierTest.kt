package com.equipseva.app.core.network

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.IOException

/**
 * The Postgrest error funnel: ViewModels read `Throwable.toUserMessage()`
 * straight into their snackbar. A regression in [classifyRestMessage] either
 * surfaces raw "permission denied for table organizations / URL: ..." to
 * users (schema leak + reads as gibberish) or swallows a legitimate error
 * into the generic fallback.
 *
 * The IOException → "Network problem..." path is tested separately on
 * `toUserMessage` itself; the SQLSTATE / PGRST-code branches are tested
 * here against the pure classifier, which doesn't need RestException
 * construction.
 */
class DataErrorClassifierTest {

    @Test fun `PGRST301 jwt-expired surfaces friendly retry copy`() {
        val out = classifyRestMessage("PGRST301: JWT expired / URL: https://x.supabase.co/...")
        assertEquals(
            "Your session expired. Tap retry — if this keeps happening, sign in again.",
            out,
        )
    }

    @Test fun `PGRST302 missing-jwt surfaces the same retry copy`() {
        val out = classifyRestMessage("PGRST302: JWT is invalid")
        assertEquals(
            "Your session expired. Tap retry — if this keeps happening, sign in again.",
            out,
        )
    }

    @Test fun `bare jwt expired phrase is matched too`() {
        val out = classifyRestMessage("Authorization failed: jwt expired")
        assertEquals(
            "Your session expired. Tap retry — if this keeps happening, sign in again.",
            out,
        )
    }

    @Test fun `42501 SQLSTATE surfaces the KYC-gated copy`() {
        val out = classifyRestMessage("ERROR: 42501 permission denied for table engineers")
        assertEquals(
            "You don't have access to this yet. Try again after KYC is verified.",
            out,
        )
    }

    @Test fun `literal permission denied phrase surfaces the same copy`() {
        val out = classifyRestMessage("permission denied for relation profiles")
        assertEquals(
            "You don't have access to this yet. Try again after KYC is verified.",
            out,
        )
    }

    @Test fun `PGRST116 not-found surfaces the missing-record copy`() {
        assertEquals(
            "We couldn't find that record.",
            classifyRestMessage("PGRST116 ... not found"),
        )
        assertEquals(
            "We couldn't find that record.",
            classifyRestMessage("the requested row was not found"),
        )
    }

    @Test fun `unique-violation 23505 surfaces the duplicate copy`() {
        assertEquals(
            "That looks like a duplicate. Please try a different value.",
            classifyRestMessage("ERROR 23505: duplicate key value violates unique constraint"),
        )
    }

    @Test fun `fk-violation 23503 surfaces the linked-record copy`() {
        assertEquals(
            "Linked record is missing — refresh and try again.",
            classifyRestMessage("23503: foreign key constraint fails"),
        )
    }

    @Test fun `safe-looking message is passed through verbatim`() {
        // Backend-provided friendly messages (e.g. server's "Aadhaar already
        // registered to another account") should land in front of the user
        // unchanged — no SQLSTATE keywords, no URL, no SQLSTATE marker.
        val msg = "Aadhaar already registered to another account."
        assertEquals(msg, classifyRestMessage(msg))
    }

    @Test fun `raw DB error with URL leakage falls through to null`() {
        // Don't surface anything that looks like a Postgrest dump.
        assertNull(
            classifyRestMessage("could not connect / URL: https://x.supabase.co/rest/v1/orders"),
        )
    }

    @Test fun `raw DB error with SQLSTATE marker falls through to null`() {
        assertNull(
            classifyRestMessage("ERROR SQLSTATE 12345: relation does not exist"),
        )
    }

    @Test fun `blank input returns null`() {
        assertNull(classifyRestMessage(""))
        assertNull(classifyRestMessage("   "))
    }

    @Test fun `looksLikeRawDbError flags the documented patterns`() {
        assertTrue(looksLikeRawDbError("foo / URL: bar"))
        assertTrue(looksLikeRawDbError("permission denied"))
        assertTrue(looksLikeRawDbError("SQLSTATE 42P01"))
        assertTrue(looksLikeRawDbError("error 12345 relation does not exist"))

        assertFalse(looksLikeRawDbError("Aadhaar already registered"))
        assertFalse(looksLikeRawDbError("Job not found"))
        // 5-digit sequence alone is fine — only flagged when paired with
        // a "relation" keyword (catches Postgres-style dumps).
        assertFalse(looksLikeRawDbError("Order 12345 placed"))
    }

    @Test fun `toUserMessage maps IOException to the network copy`() {
        // The IO + cancellation funnels are testable on the public surface
        // since they don't need a Supabase exception.
        val out = IOException("offline").toUserMessage()
        assertEquals(
            "Network problem. Check your connection and retry.",
            out,
        )
    }

    @Test fun `toUserMessage uses the fallback when the message is a raw db error`() {
        val out = RuntimeException("ERROR: permission denied for table foo / URL: https://x.supabase.co/rest/v1/foo")
            .toUserMessage(fallback = "Couldn't load.")
        assertEquals("Couldn't load.", out)
    }

    @Test fun `toUserMessage passes through a safe-looking generic message`() {
        val out = RuntimeException("Aadhaar already in use").toUserMessage()
        assertEquals("Aadhaar already in use", out)
    }

    @Test fun `toUserMessage uses fallback on blank or null messages`() {
        val out1 = RuntimeException().toUserMessage(fallback = "Default")
        assertEquals("Default", out1)
        val out2 = RuntimeException("   ").toUserMessage(fallback = "Default")
        assertEquals("Default", out2)
    }
}
