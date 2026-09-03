package com.equipseva.app.features.profile

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
 * Round 3777 — engineer-to-engineer referral bounty self-service
 * (round564 + round568's audit-19 security patch, unread by any
 * client until now). ₹2,000 bounty when a referred engineer completes
 * + gets paid on their first job — but ONLY after the referrer
 * explicitly confirms (round568 closed a CRITICAL self-attribution
 * griefing bug where anyone could claim any engineer's user_id as
 * their "referrer" without consent; this app is the first client to
 * exist since that fix, so it must implement the confirm step, not
 * just registration).
 */
@Singleton
class EngineerReferralRepository @Inject constructor(
    private val client: SupabaseClient,
) {
    @Serializable
    data class Referral(
        val id: String,
        @SerialName("referee_user_id") val refereeUserId: String,
        @SerialName("referee_first_completed_at") val refereeFirstCompletedAt: String? = null,
        @SerialName("bounty_eligible") val bountyEligible: Boolean,
        @SerialName("bounty_revoked") val bountyRevoked: Boolean,
        @SerialName("bounty_revoke_reason") val bountyRevokeReason: String? = null,
        @SerialName("bounty_amount_rupees") val bountyAmountRupees: Double,
        @SerialName("payout_status") val payoutStatus: String? = null,
        @SerialName("payout_utr") val payoutUtr: String? = null,
        @SerialName("created_at") val createdAt: String,
    )

    @Serializable
    data class PendingConfirmation(
        val id: String,
        @SerialName("referee_user_id") val refereeUserId: String,
        @SerialName("referral_confirmation_code") val referralConfirmationCode: String? = null,
        @SerialName("created_at") val createdAt: String,
    )

    suspend fun fetchMyReferrals(): Result<List<Referral>> = runCatching {
        client.postgrest.rpc(function = "my_referrals").decodeList<Referral>()
    }

    suspend fun fetchPendingConfirmations(): Result<List<PendingConfirmation>> = runCatching {
        client.postgrest.rpc(function = "my_pending_referral_confirmations").decodeList<PendingConfirmation>()
    }

    suspend fun registerReferral(referrerUserId: String): Result<String> = runCatching {
        val raw = client.postgrest.rpc(
            function = "register_engineer_referral",
            parameters = buildJsonObject { put("p_referrer_user_id", JsonPrimitive(referrerUserId)) },
        ).data
        raw.trim().trim('"')
    }

    suspend fun confirmReferral(referralId: String): Result<Unit> = runCatching {
        client.postgrest.rpc(
            function = "confirm_engineer_referral",
            parameters = buildJsonObject { put("p_referral_id", JsonPrimitive(referralId)) },
        )
        Unit
    }
}
