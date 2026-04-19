package com.equipseva.app.core.payments

import android.app.Activity
import com.equipseva.app.BuildConfig
import com.razorpay.Checkout
import kotlinx.coroutines.CompletableDeferred
import org.json.JSONObject
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Wraps Razorpay Standard Checkout behind a suspending API. The hosting [Activity] must
 * implement [com.razorpay.PaymentResultWithDataListener] and hand each callback to
 * [onPaymentSuccess] / [onPaymentError]. Only one checkout can be in flight at a time.
 *
 * Checkout is always launched with a server-minted `razorpay_order_id` so the success
 * callback returns a signed (order_id, payment_id, signature) triple that
 * `verify-razorpay-payment` HMAC-checks.
 */
@Singleton
class RazorpayLauncher @Inject constructor() {

    private var pending: CompletableDeferred<PaymentResult>? = null
    private var pendingOrderId: String? = null

    fun isConfigured(): Boolean = BuildConfig.RAZORPAY_KEY.isNotBlank()

    data class CheckoutRequest(
        val orderId: String,
        val razorpayOrderId: String,
        val orderNumber: String?,
        val amountInPaise: Long,
        val buyerName: String,
        val buyerEmail: String?,
        val buyerPhone: String?,
        val description: String,
    )

    suspend fun launch(activity: Activity, request: CheckoutRequest): PaymentResult {
        pending?.cancel()
        val deferred = CompletableDeferred<PaymentResult>()
        pending = deferred
        pendingOrderId = request.orderId

        val checkout = Checkout()
        checkout.setKeyID(BuildConfig.RAZORPAY_KEY)
        val payload = JSONObject().apply {
            put("name", "EquipSeva")
            put("description", request.description)
            put("currency", "INR")
            put("amount", request.amountInPaise)
            put("order_id", request.razorpayOrderId)
            put("prefill", JSONObject().apply {
                request.buyerEmail?.let { put("email", it) }
                request.buyerPhone?.let { put("contact", it) }
                put("name", request.buyerName)
            })
            put("notes", JSONObject().apply {
                put("supabase_order_id", request.orderId)
                request.orderNumber?.let { put("order_number", it) }
            })
            put("theme", JSONObject().put("color", "#0B6E4F"))
            put("retry", JSONObject().put("enabled", true).put("max_count", 2))
        }
        checkout.open(activity, payload)

        return deferred.await()
    }

    fun onPaymentSuccess(
        razorpayPaymentId: String,
        razorpayOrderId: String?,
        signature: String?,
    ) {
        val orderId = pendingOrderId ?: return
        if (razorpayOrderId.isNullOrBlank() || signature.isNullOrBlank()) {
            // Razorpay should always return these when checkout is launched with order_id.
            // Treat missing values as a hard failure so we don't attempt unverifiable marks.
            pending?.complete(
                PaymentResult.Failure(
                    orderId,
                    code = -1,
                    description = "Razorpay callback missing order_id/signature",
                ),
            )
            clear()
            return
        }
        pending?.complete(
            PaymentResult.Success(
                orderId = orderId,
                razorpayOrderId = razorpayOrderId,
                razorpayPaymentId = razorpayPaymentId,
                razorpaySignature = signature,
            ),
        )
        clear()
    }

    fun onPaymentError(code: Int, description: String) {
        val orderId = pendingOrderId ?: return
        pending?.complete(
            if (code == Checkout.PAYMENT_CANCELED) {
                PaymentResult.Cancelled(orderId)
            } else {
                PaymentResult.Failure(orderId, code, description)
            },
        )
        clear()
    }

    private fun clear() {
        pending = null
        pendingOrderId = null
    }
}
