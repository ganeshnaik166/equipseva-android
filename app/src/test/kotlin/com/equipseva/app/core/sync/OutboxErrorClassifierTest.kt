package com.equipseva.app.core.sync

import com.equipseva.app.core.storage.UploadError
import io.github.jan.supabase.exceptions.RestException
import kotlinx.serialization.SerializationException
import org.junit.Assert.assertEquals
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.IOException

/**
 * Pins the Retry vs GiveUp routing for outbox handler failures. This
 * is the contract that keeps the worker honest: transient failures
 * stay in the queue, permanent failures get poison-dropped instead
 * of consuming the MAX_ATTEMPTS budget.
 *
 * Two boundary cases that have bitten us in the past:
 *   * 408 / 429 are technically 4xx but are transient by definition;
 *     they must Retry, not GiveUp.
 *   * UploadError and Serialization failures are permanent — re-running
 *     would re-encode the same bad payload / re-validate the same bad
 *     file. Must GiveUp.
 */
class OutboxErrorClassifierTest {

    private fun rest(statusCode: Int, message: String = "boom"): RestException =
        RestException(
            error = "PostgrestError",
            description = message,
            statusCode = statusCode,
            message = message,
        )

    @Test fun `IOException routes to Retry`() {
        val err = IOException("offline")
        val out = classifyOutboxError(err)
        assertTrue(out is OutboxKindHandler.Outcome.Retry)
        assertSame(err, (out as OutboxKindHandler.Outcome.Retry).reason)
    }

    @Test fun `RestException 4xx routes to GiveUp with a permanent reason string`() {
        val out = classifyOutboxError(rest(403, "forbidden"))
        assertTrue(out is OutboxKindHandler.Outcome.GiveUp)
        val reason = (out as OutboxKindHandler.Outcome.GiveUp).reason
        assertTrue("got: $reason", reason.contains("403"))
    }

    @Test fun `RestException 5xx routes to Retry (server temporarily off)`() {
        val out = classifyOutboxError(rest(500))
        assertTrue(out is OutboxKindHandler.Outcome.Retry)
    }

    @Test fun `408 Request Timeout retries even though it's 4xx`() {
        // Specifically pinned — a rate-limited or timed-out write
        // succeeds on backoff, so 408 must NOT be poison-dropped.
        val out = classifyOutboxError(rest(408, "timeout"))
        assertTrue("got $out", out is OutboxKindHandler.Outcome.Retry)
    }

    @Test fun `429 Too Many Requests retries even though it's 4xx`() {
        val out = classifyOutboxError(rest(429, "rate limited"))
        assertTrue("got $out", out is OutboxKindHandler.Outcome.Retry)
    }

    @Test fun `SerializationException routes to GiveUp`() {
        val err = SerializationException("missing required field")
        val out = classifyOutboxError(err)
        assertTrue(out is OutboxKindHandler.Outcome.GiveUp)
        val reason = (out as OutboxKindHandler.Outcome.GiveUp).reason
        assertTrue("got: $reason", reason.contains("Malformed"))
    }

    @Test fun `UploadError MimeNotAllowed routes to GiveUp`() {
        val err = UploadError.MimeNotAllowed(
            bucket = "repair-photos",
            received = "application/pdf",
            allowed = setOf("image/jpeg", "image/png"),
        )
        val out = classifyOutboxError(err)
        assertTrue(out is OutboxKindHandler.Outcome.GiveUp)
        val reason = (out as OutboxKindHandler.Outcome.GiveUp).reason
        assertTrue("got: $reason", reason.contains("Upload rejected"))
    }

    @Test fun `UploadError TooLarge routes to GiveUp`() {
        val err = UploadError.TooLarge(bucket = "kyc-docs", size = 10_000_000L, max = 5_000_000L)
        val out = classifyOutboxError(err)
        assertTrue(out is OutboxKindHandler.Outcome.GiveUp)
    }

    @Test fun `IllegalArgumentException routes to GiveUp`() {
        // Payload-shape failures (null required field, mismatched
        // engineerUserId) must not retry — the row will never change.
        val out = classifyOutboxError(IllegalArgumentException("bad arg"))
        assertTrue(out is OutboxKindHandler.Outcome.GiveUp)
        assertTrue(
            (out as OutboxKindHandler.Outcome.GiveUp).reason.contains("Bad outbox payload"),
        )
    }

    @Test fun `IllegalStateException routes to GiveUp`() {
        val out = classifyOutboxError(IllegalStateException("bad state"))
        assertTrue(out is OutboxKindHandler.Outcome.GiveUp)
    }

    @Test fun `unknown error type defaults to Retry so MAX_ATTEMPTS eventually drops it`() {
        // Conservative — an unrecognised exception is treated as
        // transient. The worker will poison-drop after MAX_ATTEMPTS
        // if it really is permanent.
        val err = RuntimeException("mystery")
        val out = classifyOutboxError(err)
        assertTrue(out is OutboxKindHandler.Outcome.Retry)
        assertSame(err, (out as OutboxKindHandler.Outcome.Retry).reason)
    }

    @Test fun `4xx GiveUp reason includes the exception type when message is null`() {
        // If supabase-kt returned a 4xx with a null message, we still
        // want to log SOMETHING so the poison-drop notification carries
        // a hint of what went wrong.
        val rest = RestException(
            error = "PostgrestError",
            description = "",
            statusCode = 400,
            message = "",
        )
        val out = classifyOutboxError(rest)
        assertTrue(out is OutboxKindHandler.Outcome.GiveUp)
        val reason = (out as OutboxKindHandler.Outcome.GiveUp).reason
        assertEquals("Permanent 400: ", reason)
    }
}
