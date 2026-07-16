package com.equipseva.app.core.data.engineers

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Engineer self-view of certification-ladder status (round 554): the current
 * tier + its perks, live stats (jobs completed, dispute rate), and what the
 * next tier requires. Called with no arg → the RPC scopes to the caller
 * (auth.uid()). Read-only; single row (the server coalesces to a
 * 'none'/'New' default row for engineers not yet evaluated).
 */
@Singleton
class CertificationStatusRepository @Inject constructor(
    private val client: SupabaseClient,
) {
    @Serializable
    data class CertificationStatus(
        @SerialName("current_tier") val currentTier: String = "none",
        @SerialName("current_tier_label") val currentTierLabel: String = "New",
        @SerialName("jobs_completed") val jobsCompleted: Int = 0,
        @SerialName("dispute_rate_pct") val disputeRatePct: Double = 0.0,
        @SerialName("verified_tier_at_eval") val verifiedTierAtEval: String? = null,
        @SerialName("manual_override") val manualOverride: Boolean = false,
        @SerialName("last_computed_at") val lastComputedAt: String? = null,
        // Forward-looking: null when already at the top tier.
        @SerialName("next_tier") val nextTier: String? = null,
        @SerialName("next_tier_label") val nextTierLabel: String? = null,
        @SerialName("jobs_needed_for_next") val jobsNeededForNext: Int = 0,
        @SerialName("max_dispute_for_next") val maxDisputeForNext: Double? = null,
        @SerialName("min_verified_for_next") val minVerifiedForNext: String? = null,
        // Static perks of the current tier.
        @SerialName("current_platform_fee_pct") val currentPlatformFeePct: Double = 0.0,
        @SerialName("current_code_red_priority") val currentCodeRedPriority: Int = 0,
        @SerialName("current_pi_insurance_eligible") val currentPiInsuranceEligible: Boolean = false,
        @SerialName("current_featured_in_search") val currentFeaturedInSearch: Boolean = false,
    )

    suspend fun fetch(): Result<CertificationStatus?> = runCatching {
        client.postgrest
            .rpc(function = "my_certification_status")
            .decodeList<CertificationStatus>()
            .firstOrNull()
    }
}
