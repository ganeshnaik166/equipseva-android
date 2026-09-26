package com.equipseva.app.core.payments

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The on-disk form of a Razorpay success the server has not confirmed yet.
 *
 * This payload is the ONLY proof of a captured payment the client holds
 * between `onPaymentSuccess` and a successful `verify-amc-payment`, so the
 * codec has to survive a process death and must never hand the reconciler a
 * half-readable record it would replay as if it were complete.
 */
class VerifiableAmcPaymentTest {

    private fun payment() = VerifiableAmcPayment(
        paymentOrderId = "po-1",
        razorpayOrderId = "order_QaZ12",
        razorpayPaymentId = "pay_QaZ34",
        razorpaySignature = "9f86d081884c7d659a2feaa0c55ad015",
    )

    @Test fun `round-trips through the encoded form`() {
        assertEquals(payment(), decodeVerifiableAmcPayment(encodeVerifiableAmcPayment(payment())))
    }

    @Test fun `separator cannot collide with razorpay ids or a hex signature`() {
        // Razorpay ids are [A-Za-z0-9_]-shaped and the signature is hex, so a
        // control character is the only separator that cannot appear inside a
        // field — a comma or pipe could.
        val encoded = encodeVerifiableAmcPayment(payment())
        assertEquals(3, encoded.count { it == '\u001F' })
        assertFalse(encoded.any { it == ',' || it == '|' })
    }

    @Test fun `a record from another schema decodes to null, not a partial payment`() {
        assertNull(decodeVerifiableAmcPayment("po-1"))
        assertNull(decodeVerifiableAmcPayment("po-1\u001Forder_1"))
        assertNull(decodeVerifiableAmcPayment("po-1\u001Fa\u001Fb\u001Fc\u001Fd"))
        assertNull(decodeVerifiableAmcPayment(""))
    }

    @Test fun `a payload missing any field is unusable`() {
        // verify-amc-payment requires all four; a blank one can only ever be
        // refused, and replaying it would burn retries on a lost cause.
        assertNull(decodeVerifiableAmcPayment("\u001Forder_1\u001Fpay_1\u001Fsig"))
        assertNull(decodeVerifiableAmcPayment("po-1\u001F\u001Fpay_1\u001Fsig"))
        assertNull(decodeVerifiableAmcPayment("po-1\u001Forder_1\u001F\u001Fsig"))
        assertNull(decodeVerifiableAmcPayment("po-1\u001Forder_1\u001Fpay_1\u001F"))
    }

    @Test fun `isVerifiable mirrors what the edge function needs`() {
        assertTrue(payment().isVerifiable)
        assertFalse(payment().copy(razorpaySignature = "").isVerifiable)
        assertFalse(payment().copy(razorpayPaymentId = "").isVerifiable)
    }
}
