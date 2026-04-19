package com.equipseva.app.core.payments

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.functions.functions
import io.ktor.client.statement.bodyAsText
import io.ktor.http.HttpStatusCode
import io.ktor.http.isSuccess
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Thin client for the two Razorpay edge functions:
 *   - `create-razorpay-order` mints a Razorpay order so Checkout can return a signed pair
 *   - `verify-razorpay-payment` HMAC-verifies the pair and flips payment_status server-side
 *
 * The Supabase migration 20260419000000_razorpay_verification_rls.sql refuses the terminal
 * transition from anon-role writes, so the client can never self-mark an order as paid.
 */
@Singleton
class PaymentVerificationRepository @Inject constructor(
    private val supabase: SupabaseClient,
) {
    private val json = Json { ignoreUnknownKeys = true }

    suspend fun createRazorpayOrder(request: CreateRequest): Result<CreateResponse> = runCatching {
        val res = supabase.functions.invoke(
            function = "create-razorpay-order",
            body = request,
        )
        val text = res.bodyAsText()
        if (res.status.isSuccess()) {
            json.decodeFromString(CreateResponse.serializer(), text)
        } else throw decodeError(res.status, text)
    }

    suspend fun verify(request: VerifyRequest): Result<VerifyResponse> = runCatching {
        val res = supabase.functions.invoke(
            function = "verify-razorpay-payment",
            body = request,
        )
        val text = res.bodyAsText()
        if (res.status.isSuccess()) {
            json.decodeFromString(VerifyResponse.serializer(), text)
        } else throw decodeError(res.status, text)
    }

    private fun decodeError(status: HttpStatusCode, text: String): VerificationException {
        val err = runCatching { json.decodeFromString(VerifyError.serializer(), text) }.getOrNull()
        return VerificationException(status, err?.code ?: "unknown", err?.message ?: text)
    }

    @Serializable
    data class CreateRequest(
        @SerialName("order_id") val orderId: String,
    )

    @Serializable
    data class CreateResponse(
        val ok: Boolean,
        @SerialName("razorpay_order_id") val razorpayOrderId: String,
        val amount: Long,
        val currency: String,
    )

    @Serializable
    data class VerifyRequest(
        @SerialName("order_id") val orderId: String,
        @SerialName("razorpay_order_id") val razorpayOrderId: String,
        @SerialName("razorpay_payment_id") val razorpayPaymentId: String,
        @SerialName("razorpay_signature") val razorpaySignature: String,
    )

    @Serializable
    data class VerifyResponse(
        val ok: Boolean,
        @SerialName("order_id") val orderId: String,
        @SerialName("payment_id") val paymentId: String,
        @SerialName("payment_status") val paymentStatus: String,
        @SerialName("order_status") val orderStatus: String,
        val idempotent: Boolean = false,
    )

    @Serializable
    private data class VerifyError(
        val ok: Boolean = false,
        val code: String,
        val message: String? = null,
    )

    class VerificationException(
        val status: HttpStatusCode,
        val code: String,
        override val message: String,
    ) : RuntimeException("$code: $message (status=${status.value})")
}
