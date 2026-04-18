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
 * [complete]. Only one checkout can be in flight at a time.
 *
 * For production, server-side order creation + signature verification via a Supabase edge
 * function is recommended. This launcher intentionally keeps the client path minimal so
 * the buyer loop closes end-to-end with the Razorpay test key.
 */
@Singleton
class RazorpayLauncher @Inject constructor() {

    private var pending: CompletableDeferred<PaymentResult>? = null
    private var pendingOrderId: String? = null

    fun isConfigured(): Boolean = BuildConfig.RAZORPAY_KEY.isNotBlank()

    data class CheckoutRequest(
        val orderId: String,
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

    fun onPaymentSuccess(razorpayPaymentId: String, signature: String?) {
        val orderId = pendingOrderId ?: return
        pending?.complete(PaymentResult.Success(orderId, razorpayPaymentId, signature))
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
