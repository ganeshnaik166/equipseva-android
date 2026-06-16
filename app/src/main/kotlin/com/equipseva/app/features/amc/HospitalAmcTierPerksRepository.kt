package com.equipseva.app.features.amc

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Read-side repo for the hospital's active AMC tier perks (r587).
 * Calls my_active_amc_tier_perks() which is auth.uid()-scoped server-
 * side; client-side auth checks are defense-in-depth.
 */
@Singleton
class HospitalAmcTierPerksRepository @Inject constructor(
    private val client: SupabaseClient,
) {
    @Serializable
    data class TierPerks(
        @SerialName("contract_id") val contractId: String,
        @SerialName("amc_tier") val amcTier: String,
        @SerialName("display_label") val displayLabel: String,
        @SerialName("visits_per_year_ceiling") val visitsPerYearCeiling: Int? = null,
        @SerialName("code_red_sla_minutes") val codeRedSlaMinutes: Int? = null,
        @SerialName("parts_discount_pct") val partsDiscountPct: Double? = null,
        @SerialName("trusted_partner_badge") val trustedPartnerBadge: Boolean = false,
        @SerialName("end_date") val endDate: String,
    )

    suspend fun fetchActiveTierPerks(): Result<List<TierPerks>> = runCatching {
        client.postgrest
            .rpc(function = "my_active_amc_tier_perks")
            .decodeList<TierPerks>()
    }
}
