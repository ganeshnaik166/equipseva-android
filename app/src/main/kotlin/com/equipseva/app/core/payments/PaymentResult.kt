package com.equipseva.app.core.payments

/** Result of launching Razorpay Standard Checkout for a given Supabase order row. */
sealed interface PaymentResult {
    val orderId: String

    data class Success(
        override val orderId: String,
        val razorpayPaymentId: String,
        val razorpaySignature: String?,
    ) : PaymentResult

    data class Failure(
        override val orderId: String,
        val code: Int,
        val description: String,
    ) : PaymentResult

    data class Cancelled(override val orderId: String) : PaymentResult
}
