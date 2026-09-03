package com.equipseva.app.features.profile

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Round 3772 — hospital's loyalty commission tier self-view
 * (v21 PR-D2 `get_my_commission_tier`, unread by any client until
 * now). Tier is 7% default / 5% after 10 completed jobs in the
 * trailing 12 months / 3% after 50 — see the migration's own header
 * comment for the full anti-disintermediation rationale.
 */
@Singleton
class CommissionTierRepository @Inject constructor(
    private val client: SupabaseClient,
) {
    @Serializable
    data class CommissionTier(
        @SerialName("completed_12m") val completed12m: Int,
        @SerialName("current_rate") val currentRate: Double,
        @SerialName("next_tier_rate") val nextTierRate: Double? = null,
        @SerialName("jobs_to_next_tier") val jobsToNextTier: Int,
    )

    suspend fun fetchMyCommissionTier(): Result<CommissionTier> = runCatching {
        client.postgrest.rpc(function = "get_my_commission_tier").decodeSingle<CommissionTier>()
    }
}
