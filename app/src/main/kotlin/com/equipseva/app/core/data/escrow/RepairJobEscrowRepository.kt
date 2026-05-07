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
        @SerialName("engineer_response") val engineerResponse: String? = null,
        @SerialName("engineer_responded_at") val engineerRespondedAt: String? = null,
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

    @Serializable
    data class EngineerEscrowSummary(
        @SerialName("total_held_rupees") val totalHeldRupees: Double = 0.0,
        @SerialName("count_held") val countHeld: Int = 0,
        @SerialName("next_release_at") val nextReleaseAt: String? = null,
        @SerialName("total_released_rupees_30d") val totalReleased30d: Double = 0.0,
        @SerialName("count_in_dispute") val countInDispute: Int = 0,
        @SerialName("count_pending_payment") val countPendingPayment: Int = 0,
    )

    @Serializable
    data class ActiveEscrowRow(
        @SerialName("escrow_id") val escrowId: String,
        @SerialName("repair_job_id") val repairJobId: String,
        @SerialName("job_number") val jobNumber: String? = null,
        @SerialName("hospital_name") val hospitalName: String? = null,
        @SerialName("amount_rupees") val amountRupees: Double,
        @SerialName("status") val status: String,
        @SerialName("paid_at") val paidAt: String? = null,
        @SerialName("scheduled_release_at") val scheduledReleaseAt: String? = null,
        @SerialName("dispute_opened_at") val disputeOpenedAt: String? = null,
        @SerialName("dispute_reason") val disputeReason: String? = null,
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

    suspend fun fetchEngineerSummary(): Result<EngineerEscrowSummary> = runCatching {
        supabase.postgrest.rpc(function = "engineer_escrow_summary")
            .decodeList<EngineerEscrowSummary>()
            .firstOrNull() ?: EngineerEscrowSummary()
    }

    suspend fun fetchEngineerActiveEscrows(): Result<List<ActiveEscrowRow>> = runCatching {
        supabase.postgrest.rpc(function = "engineer_active_escrows")
            .decodeList<ActiveEscrowRow>()
    }

    @Serializable
    data class HospitalDisputeRow(
        @SerialName("escrow_id") val escrowId: String,
        @SerialName("repair_job_id") val repairJobId: String,
        @SerialName("job_number") val jobNumber: String? = null,
        @SerialName("engineer_user_id") val engineerUserId: String? = null,
        @SerialName("engineer_name") val engineerName: String? = null,
        @SerialName("amount_rupees") val amountRupees: Double,
        @SerialName("status") val status: String,
        @SerialName("outcome") val outcome: String? = null,
        @SerialName("dispute_opened_at") val disputeOpenedAt: String? = null,
        @SerialName("dispute_resolved_at") val disputeResolvedAt: String? = null,
        @SerialName("dispute_reason") val disputeReason: String? = null,
        @SerialName("resolution_note") val resolutionNote: String? = null,
    )

    /**
     * v2.1 PR-D41 — caller-scoped list of disputes the hospital has
     * filed in the trailing window. Default 365 days.
     */
    suspend fun fetchHospitalDisputeHistory(): Result<List<HospitalDisputeRow>> = runCatching {
        supabase.postgrest.rpc(function = "hospital_my_disputes")
            .decodeList<HospitalDisputeRow>()
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

    // PR-D29: engineer-side response to a hospital's dispute. One-shot
    // (the SQL rejects a second call) so the UI must hide the CTA after
    // the first successful submission.
    suspend fun submitEngineerResponse(
        repairJobId: String,
        response: String,
    ): Result<Unit> = runCatching {
        supabase.postgrest.rpc(
            function = "engineer_respond_to_escrow_dispute",
            parameters = buildJsonObject {
                put("p_repair_job_id", JsonPrimitive(repairJobId))
                put("p_response", JsonPrimitive(response))
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
