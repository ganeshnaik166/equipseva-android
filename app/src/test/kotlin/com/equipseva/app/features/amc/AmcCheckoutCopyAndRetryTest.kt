package com.equipseva.app.features.amc

import com.equipseva.app.core.data.amc.AmcRepository
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.TimeoutCancellationException
import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.IOException

/**
 * Retry policy + user-facing copy for the AMC checkout path.
 *
 * The subtle case both helpers exist for: the repositories bound their edge
 * function calls with `withTimeout` INSIDE `runCatching`, so "the gateway was
 * slow" arrives as a `TimeoutCancellationException` — a CancellationException
 * by type. Treating it as cancellation abandoned a possibly-captured payment
 * and showed the hospital nothing at all.
 */
class AmcCheckoutCopyAndRetryTest {

    /** A real TimeoutCancellationException; its constructor is internal to kotlinx. */
    private fun timeout(): TimeoutCancellationException = try {
        runBlocking { withTimeout(1L) { delay(500L) } }
        error("withTimeout did not time out")
    } catch (e: TimeoutCancellationException) {
        e
    }

    // ---- shouldRetryAmcVerify -----------------------------------------

    @Test fun `transient failures are replayed`() {
        assertTrue(shouldRetryAmcVerify(IOException("connection reset")))
        assertTrue(shouldRetryAmcVerify(verifyRefusal(502, "bad gateway")))
        assertTrue(shouldRetryAmcVerify(IllegalStateException("no message match")))
    }

    @Test fun `a timeout is replayed (verify is idempotent)`() {
        assertTrue(shouldRetryAmcVerify(timeout()))
    }

    @Test fun `a 4xx refusal is not replayed`() {
        // The server has decided: a bad signature or an already-resolved order
        // answers the same way every time, and looping delays the honest copy.
        assertFalse(shouldRetryAmcVerify(verifyRefusal(400, "bad signature")))
        assertFalse(shouldRetryAmcVerify(verifyRefusal(403, "order not yours")))
        assertFalse(shouldRetryAmcVerify(verifyRefusal(410, "gone")))
    }

    @Test fun `the refusal copy the function really sends still stops the replay`() {
        // Regression pin. The rule used to look for "HTTP 4xx" inside the
        // message, and verify-amc-payment answers refusals with a parseable
        // { ok, code, message } body — so the parsed copy replaced the status
        // and the rule never fired on a real response. Any message, status
        // 400: it must still refuse to replay.
        assertFalse(
            shouldRetryAmcVerify(
                verifyRefusal(400, "Signature verification failed for this order"),
            ),
        )
    }

    @Test fun `our own cancellation stops the replay loop`() {
        assertFalse(shouldRetryAmcVerify(CancellationException("scope gone")))
    }

    // ---- checkoutFailureMessage ---------------------------------------

    @Test fun `a cancelled charge has no message`() {
        assertNull(checkoutFailureMessage(null))
        assertNull(checkoutFailureMessage(CancellationException("sheet dismissed")))
    }

    @Test fun `a timeout gets copy instead of re-throwing`() {
        // toUserMessage() would re-throw this, which is how the spinner used
        // to stop with nothing shown.
        assertEquals(
            "That took too long. Check your connection and try again.",
            checkoutFailureMessage(timeout()),
        )
    }

    @Test fun `other failures use the shared user-facing mapping`() {
        assertEquals(
            "Network problem. Check your connection and retry.",
            checkoutFailureMessage(IOException("offline")),
        )
    }

    // ---- amcPayButtonLabel --------------------------------------------

    @Test fun `pay label is paise-exact so it matches the razorpay sheet`() {
        // The server charges round(fee * months * 100) paise; a whole-rupee
        // label promised ₹3,000 and Razorpay then asked for ₹2,999.99.
        assertEquals("Pay ₹2,999.99", amcPayButtonLabel(busy = false, totalRupees = 2999.99))
        assertEquals("Pay ₹1,00,000.00", amcPayButtonLabel(busy = false, totalRupees = 100_000.0))
    }

    @Test fun `busy label replaces the amount`() {
        assertEquals("Processing…", amcPayButtonLabel(busy = true, totalRupees = 2999.99))
    }

    /** The shape `AmcRepository.verifyPayment` actually throws on a refusal. */
    private fun verifyRefusal(status: Int, message: String) =
        AmcRepository.EdgeFnHttpException(status = status, message = message)
}
