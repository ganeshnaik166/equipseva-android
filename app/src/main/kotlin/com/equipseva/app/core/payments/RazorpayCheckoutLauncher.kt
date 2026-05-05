package com.equipseva.app.core.payments

import android.app.Activity
import com.razorpay.Checkout
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.coroutines.CompletableDeferred
import org.json.JSONObject

/**
 * v2.1 PR-C6 — wrapper around the Razorpay Standard Checkout SDK.
 *
 * **Activity coupling — IMPORTANT**:
 *
 *   The Razorpay Android SDK posts the Checkout result back to the
 *   *calling Activity* via a callback method named
 *   `onPaymentSuccess(paymentId, paymentData)` /
 *   `onPaymentError(code, response, paymentData)`. The Activity must
 *   either implement [com.razorpay.PaymentResultWithDataListener] OR
 *   the SDK falls back to looking up `onPaymentSuccess` via reflection.
 *
 *   In our app, [com.equipseva.app.MainActivity] is the only Activity
 *   that hosts the AMC flow (we're a single-activity Compose app). To
 *   avoid leaking Razorpay imports into MainActivity, this launcher
 *   uses a coroutine [CompletableDeferred] held in a process-wide
 *   slot. When the Razorpay SDK fires its result, it dispatches into
 *   the Activity; the Activity (or this object's static bridge —
 *   wired via [PaymentBridge]) completes the deferred with the
 *   correct sealed result.
 *
 *   The bridge lives as a top-level singleton ([PaymentBridge]) so
 *   the result hand-off is independent of who owns the Activity. Any
 *   Activity that calls [startPayment] and implements
 *   [PaymentResultWithDataListener] should forward both callback
 *   methods straight through to [PaymentBridge.completeSuccess] /
 *   [PaymentBridge.completeFailure]. See `MainActivity` for the
 *   minimal three-line wiring.
 */
@Singleton
class RazorpayCheckoutLauncher @Inject constructor() {

    sealed interface RazorpayPaymentResult {
        data class Success(
            val razorpayPaymentId: String,
            val razorpayOrderId: String,
            val razorpaySignature: String,
        ) : RazorpayPaymentResult

        data class Failed(val code: Int, val message: String?) : RazorpayPaymentResult
        data object Cancelled : RazorpayPaymentResult
    }

    /**
     * Launches Razorpay Standard Checkout with the supplied order. The
     * coroutine suspends until the user taps the SDK's success/cancel
     * button or the SDK reports a failure code. **Must** be called
     * from a UI thread bound to [activity].
     *
     * Razorpay SDK requires `Checkout.preload(applicationContext)` to
     * be invoked once before the first checkout; we do it here lazily
     * (a no-op if already preloaded).
     */
    suspend fun startPayment(
        activity: Activity,
        amountPaise: Long,
        currency: String,
        name: String,
        description: String,
        prefillEmail: String?,
        prefillContact: String?,
        razorpayOrderId: String,
        keyId: String,
    ): RazorpayPaymentResult {
        Checkout.preload(activity.applicationContext)

        val checkout = Checkout()
        checkout.setKeyID(keyId)

        val options = JSONObject().apply {
            put("name", name)
            put("description", description)
            put("currency", currency)
            put("amount", amountPaise)
            put("order_id", razorpayOrderId)
            // Closing the SDK should map to a Cancelled — without this
            // the SDK fires `onPaymentError(0, "BACK_PRESSED", ...)`,
            // which we'd interpret as Failed. Setting `prefill.method`
            // is unrelated; Razorpay takes the user-chosen method.
            put("prefill", JSONObject().apply {
                if (!prefillEmail.isNullOrBlank()) put("email", prefillEmail)
                if (!prefillContact.isNullOrBlank()) put("contact", prefillContact)
            })
            put("theme", JSONObject().apply {
                // EquipSeva green-700; matches the primary CTA on the
                // sticky bar so the SDK sheet reads as native.
                put("color", "#0D7B45")
            })
        }

        // Spin up the deferred + register it with the bridge before
        // calling open(). The bridge is the single source of truth for
        // "next checkout result". A deferred that's already registered
        // is a programming error — we cancel it to fail fast.
        val deferred = CompletableDeferred<RazorpayPaymentResult>()
        PaymentBridge.register(deferred)
        return try {
            checkout.open(activity, options)
            deferred.await()
        } finally {
            PaymentBridge.clearIfMatches(deferred)
        }
    }
}

/**
 * Process-wide slot that the calling Activity (MainActivity) routes
 * Razorpay callbacks into. See [RazorpayCheckoutLauncher] header for
 * the full coupling rationale.
 */
object PaymentBridge {
    @Volatile
    private var pending: CompletableDeferred<RazorpayCheckoutLauncher.RazorpayPaymentResult>? = null

    fun register(deferred: CompletableDeferred<RazorpayCheckoutLauncher.RazorpayPaymentResult>) {
        pending?.cancel()
        pending = deferred
    }

    fun clearIfMatches(deferred: CompletableDeferred<RazorpayCheckoutLauncher.RazorpayPaymentResult>) {
        if (pending === deferred) pending = null
    }

    /**
     * Forward Razorpay's success callback. Razorpay 1.6.x's
     * [PaymentResultWithDataListener] hands us the JSON `paymentData`
     * which carries `razorpay_order_id` + `razorpay_signature` — both
     * required by the verify-amc-payment edge fn.
     */
    fun completeSuccess(razorpayPaymentId: String?, paymentDataJson: String?) {
        val pending = pending ?: return
        val orderId = paymentDataJson?.let {
            runCatching { JSONObject(it).optString("razorpay_order_id") }.getOrNull()
        }.orEmpty()
        val signature = paymentDataJson?.let {
            runCatching { JSONObject(it).optString("razorpay_signature") }.getOrNull()
        }.orEmpty()
        pending.complete(
            RazorpayCheckoutLauncher.RazorpayPaymentResult.Success(
                razorpayPaymentId = razorpayPaymentId.orEmpty(),
                razorpayOrderId = orderId,
                razorpaySignature = signature,
            ),
        )
    }

    /**
     * Forward Razorpay's failure callback. Razorpay surfaces user-
     * cancellation as code 2 ("Payment Cancelled") OR as a generic
     * `BACK_PRESSED` string in the response — we map both to
     * [RazorpayCheckoutLauncher.RazorpayPaymentResult.Cancelled] so
     * the UI can show a neutral "Payment cancelled" toast instead of
     * a scary red error.
     */
    fun completeFailure(code: Int, response: String?) {
        val pending = pending ?: return
        val isCancel = code == Checkout.PAYMENT_CANCELED ||
            response?.contains("BACK_PRESSED", ignoreCase = true) == true ||
            response?.contains("cancel", ignoreCase = true) == true
        pending.complete(
            if (isCancel) RazorpayCheckoutLauncher.RazorpayPaymentResult.Cancelled
            else RazorpayCheckoutLauncher.RazorpayPaymentResult.Failed(code, response),
        )
    }
}
