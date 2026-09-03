package com.equipseva.app.features.amc

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

/**
 * Round 3778 — Hospital Portal v2 self-service (round1395, unread by
 * any client until now — the migration's own header comment calls it
 * "v0.6 Phase 7 shipped early", but the app-side half never landed).
 * Two independent flows against the hospital's AMC relationship:
 * self-service account changes (tier change / pause / cancel / etc.)
 * and formal disputes (billing / service-quality / SLA breach / etc.)
 * — distinct from the existing per-repair-job dispute flow
 * (Routes.HOSPITAL_MY_DISPUTES), which is about a single job, not the
 * ongoing AMC account relationship.
 */
@Singleton
class HospitalPortalRepository @Inject constructor(
    private val client: SupabaseClient,
) {
    @Serializable
    data class SelfServiceRequest(
        val id: String,
        @SerialName("request_kind") val requestKind: String,
        @SerialName("desired_tier") val desiredTier: String? = null,
        val status: String,
        @SerialName("submitted_at") val submittedAt: String,
        @SerialName("expires_at") val expiresAt: String? = null,
        @SerialName("founder_response") val founderResponse: String? = null,
    )

    @Serializable
    data class DisputeRequest(
        val id: String,
        @SerialName("dispute_kind") val disputeKind: String,
        val status: String,
        @SerialName("amount_claimed_rupees") val amountClaimedRupees: Double? = null,
        @SerialName("resolved_amount_rupees") val resolvedAmountRupees: Double? = null,
        @SerialName("submitted_at") val submittedAt: String,
        @SerialName("resolved_at") val resolvedAt: String? = null,
    )

    suspend fun fetchMyRequests(): Result<List<SelfServiceRequest>> = runCatching {
        client.postgrest.rpc(function = "hospital_portal_my_requests").decodeList<SelfServiceRequest>()
    }

    suspend fun fetchMyDisputes(): Result<List<DisputeRequest>> = runCatching {
        client.postgrest.rpc(function = "hospital_portal_my_disputes").decodeList<DisputeRequest>()
    }

    suspend fun submitSelfServiceRequest(requestKind: String, desiredTier: String? = null): Result<String> = runCatching {
        val raw = client.postgrest.rpc(
            function = "hospital_portal_submit_self_service_request",
            parameters = buildJsonObject {
                put("p_request_kind", JsonPrimitive(requestKind))
                put("p_desired_tier", desiredTier?.let { JsonPrimitive(it) } ?: JsonNull)
            },
        ).data
        raw.trim().trim('"')
    }

    suspend fun submitDispute(
        disputeKind: String,
        description: String,
        amountClaimedRupees: Double? = null,
    ): Result<String> = runCatching {
        val raw = client.postgrest.rpc(
            function = "hospital_portal_submit_dispute",
            parameters = buildJsonObject {
                put("p_dispute_kind", JsonPrimitive(disputeKind))
                put("p_description", JsonPrimitive(description))
                put("p_amount_claimed_rupees", amountClaimedRupees?.let { JsonPrimitive(it) } ?: JsonNull)
            },
        ).data
        raw.trim().trim('"')
    }
}
