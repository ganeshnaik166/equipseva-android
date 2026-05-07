package com.equipseva.app.core.data.commissiontier

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject

// PR-D15 — wraps PR-D2's `get_my_commission_tier` SECDEF RPC. Hospital-
// only read of the loyalty progress: how many completed jobs in the
// last 12 months, current rate, next tier rate, and how many more
// jobs to unlock the next tier. Surfaces as a home-screen pill.
@Singleton
class CommissionTierRepository @Inject constructor(
    private val supabase: SupabaseClient,
) {

    @Serializable
    data class TierInfo(
        @SerialName("completed_12m") val completed12m: Int,
        @SerialName("current_rate") val currentRate: Double,
        @SerialName("next_tier_rate") val nextTierRate: Double? = null,
        @SerialName("jobs_to_next_tier") val jobsToNextTier: Int = 0,
    ) {
        /** "7%" / "5%" / "3%" — display-friendly. */
        val currentRateLabel: String get() = "${(currentRate * 100).toInt()}%"
        val nextRateLabel: String? get() = nextTierRate?.let { "${(it * 100).toInt()}%" }
        val isTopTier: Boolean get() = nextTierRate == null
    }

    suspend fun fetchMyTier(): Result<TierInfo?> = runCatching {
        supabase.postgrest.rpc(
            function = "get_my_commission_tier",
        ).decodeList<TierInfo>().firstOrNull()
    }

    @Serializable
    data class HospitalTierPreview(
        @SerialName("commission_rate") val commissionRate: Double,
        @SerialName("contracted_amount_rupees") val contractedAmountRupees: Double = 0.0,
        @SerialName("effective_payout_rupees") val effectivePayoutRupees: Double = 0.0,
        @SerialName("is_warranty_covered") val isWarrantyCovered: Boolean = false,
    ) {
        val currentRateLabel: String get() = "${(commissionRate * 100).toInt()}%"
    }

    /**
     * v2.1 PR-D38 — engineer-side preview of the hospital's commission
     * tier on a job they're already assigned to. SECDEF gates pre-bid
     * tier-shopping out by checking caller is the assigned engineer.
     */
    suspend fun fetchHospitalTierPreview(repairJobId: String): Result<HospitalTierPreview?> = runCatching {
        supabase.postgrest.rpc(
            function = "engineer_view_hospital_tier",
            parameters = buildJsonObject {
                put("p_repair_job_id", JsonPrimitive(repairJobId))
            },
        ).decodeList<HospitalTierPreview>().firstOrNull()
    }
}
