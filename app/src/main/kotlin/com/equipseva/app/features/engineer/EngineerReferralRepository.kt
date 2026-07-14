package com.equipseva.app.features.engineer

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject

/**
 * Engineer-side read/write repo for the engineer-to-engineer referral
 * bounty (r564). Both RPCs are auth.uid()-scoped server-side; the
 * client-side calls are thin wrappers.
 *
 *  - my_referrals()               → the referrer's self-view (rows this
 *                                    engineer created by referring others)
 *  - register_engineer_referral() → the referee claims a referrer's code
 *                                    (the code IS the referrer's user_id)
 *
 * A concrete @Singleton with an @Inject constructor — Hilt provides it via
 * constructor injection, so no @Binds module is needed (mirrors
 * [EngineerGraduationRepository]).
 */
@Singleton
class EngineerReferralRepository @Inject constructor(
    private val client: SupabaseClient,
) {
    /**
     * One row of my_referrals(). [payoutStatus] / [payoutUtr] come from a
     * LEFT JOIN onto referral_bounty_payouts, so both are null until the
     * daily cron mints the bounty payout row (referee's first paid job).
     */
    @Serializable
    data class MyReferral(
        @SerialName("id") val id: String,
        @SerialName("referee_user_id") val refereeUserId: String,
        @SerialName("referee_first_completed_at") val refereeFirstCompletedAt: String? = null,
        @SerialName("bounty_eligible") val bountyEligible: Boolean = false,
        @SerialName("bounty_revoked") val bountyRevoked: Boolean = false,
        @SerialName("bounty_revoke_reason") val bountyRevokeReason: String? = null,
        @SerialName("bounty_amount_rupees") val bountyAmountRupees: Double = 0.0,
        @SerialName("payout_status") val payoutStatus: String? = null,
        @SerialName("payout_utr") val payoutUtr: String? = null,
        @SerialName("created_at") val createdAt: String,
    )

    suspend fun fetchMyReferrals(): Result<List<MyReferral>> = runCatching {
        client.postgrest
            .rpc(function = "my_referrals")
            .decodeList<MyReferral>()
    }

    /**
     * Register that the current engineer (the referee, via auth.uid()) was
     * referred by [referrerUserId]. Server rejects self-referral, an
     * already-registered referee, and a referrer that isn't an engineer —
     * those RAISE EXCEPTION literals are funnelled to friendly copy in
     * [com.equipseva.app.core.network.toUserMessage].
     */
    suspend fun registerReferral(referrerUserId: String): Result<Unit> = runCatching {
        client.postgrest.rpc(
            function = "register_engineer_referral",
            parameters = buildJsonObject {
                put("p_referrer_user_id", JsonPrimitive(referrerUserId.trim()))
            },
        )
        Unit
    }
}
