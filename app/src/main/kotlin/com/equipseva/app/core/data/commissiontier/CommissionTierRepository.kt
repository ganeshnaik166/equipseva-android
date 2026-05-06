package com.equipseva.app.core.data.commissiontier

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

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
}
