package com.equipseva.app.core.payments

import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.TimeoutCancellationException
import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.IOException

/**
 * Pins the one distinction the money paths cannot get wrong: "our coroutine
 * is gone" versus "a bounded call gave up".
 *
 * Repositories wrap `withTimeout` inside `runCatching`, so a timeout comes
 * back as a `TimeoutCancellationException` in a failed Result — a
 * CancellationException by type. Treating that as cancellation skipped the
 * caller's error copy, its crash report and its retry, leaving a charged
 * hospital with no message at all.
 */
class IsScopeCancellationTest {

    private fun timeout(): TimeoutCancellationException = try {
        runBlocking { withTimeout(1L) { delay(500L) } }
        error("withTimeout did not time out")
    } catch (e: TimeoutCancellationException) {
        e
    }

    @Test fun `a plain cancellation is our scope going away`() {
        assertTrue(isScopeCancellation(CancellationException("job cancelled")))
    }

    @Test fun `a withTimeout expiry is NOT our scope going away`() {
        assertTrue("sanity: a timeout is a CancellationException", timeout() is CancellationException)
        assertFalse(isScopeCancellation(timeout()))
    }

    @Test fun `ordinary failures are not cancellation`() {
        assertFalse(isScopeCancellation(IOException("offline")))
        assertFalse(isScopeCancellation(IllegalStateException("boom")))
    }

    @Test fun `no error is not cancellation`() {
        assertFalse(isScopeCancellation(null))
    }
}
