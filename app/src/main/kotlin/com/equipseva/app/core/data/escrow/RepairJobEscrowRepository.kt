package com.equipseva.app.core.data.escrow

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.exceptions.RestException
import io.github.jan.supabase.functions.functions
import io.github.jan.supabase.postgrest.postgrest
import io.ktor.client.statement.bodyAsText
import io.ktor.http.isSuccess
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject

// v2.1 PR-D5 — wraps the per-job escrow surface from PR-D4 backend +
// the create-/verify-repair-job-payment edge fns. Mirrors the AMC
// repository pattern: postgrest.rpc for SECDEF reads, functions.invoke
// for Razorpay pay-in.
@Singleton
class RepairJobEscrowRepository @Inject constructor(
    private val supabase: SupabaseClient,
) {

    // ---- DTOs --------------------------------------------------------

    @Serializable
    data class EscrowRow(
        @SerialName("id") val id: String,
        @SerialName("status") val status: String,
        @SerialName("amount_rupees") val amountRupees: Double,
        @SerialName("paid_at") val paidAt: String? = null,
        @SerialName("scheduled_release_at") val scheduledReleaseAt: String? = null,
        @SerialName("released_at") val releasedAt: String? = null,
        @SerialName("refunded_at") val refundedAt: String? = null,
        @SerialName("dispute_opened_at") val disputeOpenedAt: String? = null,
        @SerialName("dispute_reason") val disputeReason: String? = null,
        @SerialName("dispute_resolution") val disputeResolution: String? = null,
        @SerialName("is_in_dispute_window") val isInDisputeWindow: Boolean = false,
    ) {
        val isPending: Boolean get() = status == "pending"
        val isHeld: Boolean get() = status == "held"
        val isReleased: Boolean get() = status == "released"
        val isInDispute: Boolean get() = status == "in_dispute"
        val isRefunded: Boolean get() = status == "refunded"
    }

    @Serializable
    data class CreatePaymentOrderResponse(
        @SerialName("ok") val ok: Boolean = true,
        @SerialName("payment_order_id") val escrowId: String,
        @SerialName("razorpay_order_id") val razorpayOrderId: String,
        @SerialName("amount_paise") val amountPaise: Long,
        @SerialName("currency") val currency: String,
        @SerialName("key_id") val keyId: String,
    )

    @Serializable
    data class VerifyPaymentResponse(
        @SerialName("ok") val ok: Boolean = true,
        @SerialName("escrow_id") val escrowId: String,
        @SerialName("status") val status: String,
        @SerialName("idempotent") val idempotent: Boolean = false,
    )

    @Serializable
    private data class EdgeError(
        @SerialName("ok") val ok: Boolean = false,
        @SerialName("code") val code: String? = null,
        @SerialName("message") val message: String? = null,
    )

    // ---- RPC reads ---------------------------------------------------

    suspend fun fetchByJob(repairJobId: String): Result<EscrowRow?> = runCatching {
        supabase.postgrest.rpc(
            function = "get_repair_job_escrow",
            parameters = buildJsonObject {
                put("p_repair_job_id", JsonPrimitive(repairJobId))
            },
        ).decodeList<EscrowRow>().firstOrNull()
    }

    // ---- Hospital actions -------------------------------------------

    suspend fun confirmRelease(repairJobId: String): Result<Unit> = runCatching {
        supabase.postgrest.rpc(
            function = "confirm_repair_job_escrow",
            parameters = buildJsonObject {
                put("p_repair_job_id", JsonPrimitive(repairJobId))
            },
        )
        Unit
    }

    suspend fun openDispute(repairJobId: String, reason: String): Result<Unit> = runCatching {
        supabase.postgrest.rpc(
            function = "dispute_repair_job_escrow",
            parameters = buildJsonObject {
                put("p_repair_job_id", JsonPrimitive(repairJobId))
                put("p_reason", JsonPrimitive(reason))
            },
        )
        Unit
    }

    // ---- Razorpay edge-fn calls -------------------------------------

    suspend fun createPaymentOrder(repairJobId: String): Result<CreatePaymentOrderResponse> = runCatching {
        val res = try {
            supabase.functions.invoke(
                function = "create-repair-job-payment-order",
                body = buildJsonObject {
                    put("repair_job_id", JsonPrimitive(repairJobId))
                },
            )
        } catch (rest: RestException) {
            val parsed = parseError(rest)
            error(parsed?.message ?: rest.description ?: "Couldn't create payment order")
        }
        val text = res.bodyAsText()
        if (!res.status.isSuccess()) {
            val parsed = runCatching { JSON.decodeFromString(EdgeError.serializer(), text) }.getOrNull()
            error(parsed?.message ?: "Couldn't create payment order (HTTP ${res.status.value})")
        }
        JSON.decodeFromString(CreatePaymentOrderResponse.serializer(), text)
    }

    suspend fun verifyPayment(
        escrowId: String,
        razorpayOrderId: String,
        razorpayPaymentId: String,
        razorpaySignature: String,
    ): Result<VerifyPaymentResponse> = runCatching {
        val res = try {
            supabase.functions.invoke(
                function = "verify-repair-job-payment",
                body = buildJsonObject {
                    put("escrow_id", JsonPrimitive(escrowId))
                    put("razorpay_order_id", JsonPrimitive(razorpayOrderId))
                    put("razorpay_payment_id", JsonPrimitive(razorpayPaymentId))
                    put("razorpay_signature", JsonPrimitive(razorpaySignature))
                },
            )
        } catch (rest: RestException) {
            val parsed = parseError(rest)
            error(parsed?.message ?: rest.description ?: "Couldn't verify payment")
        }
        val text = res.bodyAsText()
        if (!res.status.isSuccess()) {
            val parsed = runCatching { JSON.decodeFromString(EdgeError.serializer(), text) }.getOrNull()
            error(parsed?.message ?: "Couldn't verify payment (HTTP ${res.status.value})")
        }
        JSON.decodeFromString(VerifyPaymentResponse.serializer(), text)
    }

    private fun parseError(rest: RestException): EdgeError? {
        val description = rest.description ?: return null
        return runCatching { JSON.decodeFromString(EdgeError.serializer(), description) }.getOrNull()
    }

    private companion object {
        val JSON = Json { ignoreUnknownKeys = true }
    }
}
