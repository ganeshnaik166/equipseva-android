package com.equipseva.app.core.data.repair

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject

/**
 * Engineer earnings/tier preview for an assigned repair job (v2.1):
 * engineer_view_hospital_tier(p_repair_job_id) — the hospital's loyalty
 * commission rate applied to this job, the contracted amount, the engineer's
 * effective payout after commission, and whether the job is warranty-covered
 * (warranty ⇒ 0% commission, full payout). Engineer-only: the RPC resolves the
 * caller's engineers.id and requires it to match the job's assigned engineer.
 * Single row.
 */
@Singleton
class PayoutPreviewRepository @Inject constructor(
    private val client: SupabaseClient,
) {
    @Serializable
    data class PayoutPreview(
        // Fraction (0.07 == 7%); 0 when warranty-covered.
        @SerialName("commission_rate") val commissionRate: Double = 0.0,
        @SerialName("contracted_amount_rupees") val contractedAmountRupees: Double = 0.0,
        @SerialName("effective_payout_rupees") val effectivePayoutRupees: Double = 0.0,
        @SerialName("is_warranty_covered") val isWarrantyCovered: Boolean = false,
    )

    suspend fun fetch(repairJobId: String): Result<PayoutPreview?> = runCatching {
        client.postgrest.rpc(
            function = "engineer_view_hospital_tier",
            parameters = buildJsonObject { put("p_repair_job_id", JsonPrimitive(repairJobId)) },
        ).decodeList<PayoutPreview>().firstOrNull()
    }
}
