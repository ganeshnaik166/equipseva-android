package com.equipseva.app.core.network

import com.equipseva.app.core.sync.OutboxKindHandler
import com.equipseva.app.core.sync.classifyOutboxError
import com.equipseva.app.testing.FakeRest
import io.github.jan.supabase.exceptions.HttpRequestException
import io.ktor.client.request.HttpRequestBuilder
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.TimeoutCancellationException
import kotlinx.coroutines.delay
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.withTimeout
import kotlinx.serialization.SerializationException
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.IOException
import java.net.SocketTimeoutException
import java.net.UnknownHostException

/**
 * Pins which failures may take the "queued — will send when back
 * online" path.
 *
 * The stakes are asymmetric, which is why this predicate is narrow
 * rather than generous:
 *
 *   * A network failure wrongly treated as permanent costs the user a
 *     retry tap.
 *   * A PERMANENT failure wrongly treated as a network failure is
 *     silent data loss with a false promise on top — the row is
 *     enqueued, the outbox drops it on the 4xx, and the UI has already
 *     told the user it will send and (for a status flip) already shows
 *     the change as applied.
 *
 * So every non-network case below is a pin against re-widening.
 */
class NetworkFailuresTest {

    @Test fun `plain IOException is network`() {
        assertTrue(isNetworkFailure(IOException("connection reset")))
    }

    @Test fun `DNS and socket timeout subclasses are network`() {
        // Airplane mode and a dead cell produce these, not the SDK wrapper.
        assertTrue(isNetworkFailure(UnknownHostException("api.supabase.co")))
        assertTrue(isNetworkFailure(SocketTimeoutException("read timed out")))
    }

    @Test fun `the SDK engine-level wrapper is network`() {
        // supabase-kt wraps an engine failure (socket death, DNS,
        // airplane mode) in this before the caller ever sees a status
        // code. It currently extends IOException, but the predicate
        // names it so a future re-parenting cannot narrow this silently.
        val wrapped = HttpRequestException("engine failed", HttpRequestBuilder())
        assertTrue(isNetworkFailure(wrapped))
    }

    @Test fun `an expired withTimeout is network, not a cancelled caller`() = runTest {
        val error: Throwable? = try {
            withTimeout(10) { delay(1_000) }
            null
        } catch (e: TimeoutCancellationException) {
            e
        }
        assertNotNull("withTimeout must have expired for this pin to mean anything", error)
        // Critical pin: TimeoutCancellationException IS a
        // CancellationException, so a caller that rethrows cancellation
        // first would classify an unreachable server as "user walked
        // away" and drop the write with no message at all.
        assertTrue(error is CancellationException)
        assertTrue(isNetworkFailure(error!!))
    }

    @Test fun `a 4xx server refusal is NOT network`() {
        // The outbox gives up permanently on a refusal, so queueing this
        // is silent loss. 403 is the RLS-denial shape the audit found on
        // status flips, bids and chat sends alike.
        assertFalse(isNetworkFailure(FakeRest.rest(403, "permission denied for table repair_jobs")))
    }

    @Test fun `a validation 422 is NOT network`() {
        assertFalse(
            isNetworkFailure(
                FakeRest.rest(422, "invalid status transition in_progress -> cancelled"),
            ),
        )
    }

    @Test fun `a 5xx queues, because the drain retries it`() {
        // The app reached the server, so this is not "you are offline" —
        // but the queue does carry it, and the case is not hypothetical:
        // a PostgREST schema-cache reload answers every call with 503 for
        // about 19 seconds, and those writes used to be discarded.
        assertTrue(isNetworkFailure(FakeRest.rest(503, "service unavailable")))
        assertTrue(isNetworkFailure(FakeRest.rest(500, "internal error")))
    }

    @Test fun `the transient 4xx statuses queue too`() {
        // An expired JWT is exactly the state a background drain recovers
        // from; a rate-limited or timed-out write succeeds on a backoff.
        assertTrue(isNetworkFailure(FakeRest.rest(401, "JWT expired")))
        assertTrue(isNetworkFailure(FakeRest.rest(408, "request timeout")))
        assertTrue(isNetworkFailure(FakeRest.rest(429, "too many requests")))
    }

    @Test fun `every status this accepts is one the drain retries`() {
        // Two lists, one policy. If the classifier stops retrying one of
        // these, queueing on it becomes silent loss — so compare them
        // rather than trusting the comments in both files to stay true.
        val accepted = QUEUEABLE_HTTP_STATUSES + setOf(500, 502, 503, 504)
        val notRetried = accepted.filterNot { status ->
            classifyOutboxError(FakeRest.rest(status, "x")) is OutboxKindHandler.Outcome.Retry
        }
        assertEquals("statuses queued here but dropped by the drain", emptyList<Int>(), notRetried)
    }

    @Test fun `a bare cancellation is NOT network`() {
        // The caller went away (screen closed, user switched). There is
        // nobody to promise anything to, and nothing to queue.
        assertFalse(isNetworkFailure(CancellationException("scope cancelled")))
    }

    @Test fun `malformed payload and programming errors are NOT network`() {
        assertFalse(isNetworkFailure(SerializationException("bad json")))
        assertFalse(isNetworkFailure(IllegalArgumentException("photo too large")))
        assertFalse(isNetworkFailure(IllegalStateException("no session")))
        assertFalse(isNetworkFailure(RuntimeException("boom")))
    }
}
