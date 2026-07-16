package com.equipseva.app.core.data.hospital

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Hospital self-view of the loyalty commission tier (v2.1 PR-D2): how many
 * jobs the hospital completed in the trailing 12 months, its current platform
 * commission rate, the next tier's rate, and how many more jobs unlock it.
 * get_my_commission_tier() is auth.uid()-scoped server-side. Read-only;
 * single row. NOTE: rates are fractions (0.07 == 7%).
 */
@Singleton
class CommissionTierRepository @Inject constructor(
    private val client: SupabaseClient,
) {
    @Serializable
    data class CommissionTier(
        @SerialName("completed_12m") val completed12m: Int = 0,
        @SerialName("current_rate") val currentRate: Double = 0.07,
        // null when already on the best (lowest) rate.
        @SerialName("next_tier_rate") val nextTierRate: Double? = null,
        @SerialName("jobs_to_next_tier") val jobsToNextTier: Int = 0,
    )

    suspend fun fetch(): Result<CommissionTier?> = runCatching {
        client.postgrest
            .rpc(function = "get_my_commission_tier")
            .decodeList<CommissionTier>()
            .firstOrNull()
    }
}
