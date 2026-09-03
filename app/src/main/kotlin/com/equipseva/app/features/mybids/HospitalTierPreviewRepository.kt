package com.equipseva.app.features.mybids

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

/**
 * Round 3774 — engineer-side "preview your take-home BEFORE the job
 * completes" (v21 PR-D38 `engineer_view_hospital_tier`, unread by any
 * client until now). Only callable by the engineer actually assigned
 * to the job (server blocks pre-bid tier-shopping) — see the
 * migration's own header comment.
 */
@Singleton
class HospitalTierPreviewRepository @Inject constructor(
    private val client: SupabaseClient,
) {
    @Serializable
    data class TierPreview(
        @SerialName("commission_rate") val commissionRate: Double,
        @SerialName("contracted_amount_rupees") val contractedAmountRupees: Double,
        @SerialName("effective_payout_rupees") val effectivePayoutRupees: Double,
        @SerialName("is_warranty_covered") val isWarrantyCovered: Boolean,
    )

    suspend fun fetchTierPreview(repairJobId: String): Result<TierPreview?> = runCatching {
        client.postgrest.rpc(
            function = "engineer_view_hospital_tier",
            parameters = buildJsonObject { put("p_repair_job_id", JsonPrimitive(repairJobId)) },
        ).decodeSingleOrNull<TierPreview>()
    }
}
