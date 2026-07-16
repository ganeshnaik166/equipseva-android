package com.equipseva.app.core.data.referrals

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject

/**
 * Engineer self-view of referrals they made that are still awaiting their own
 * confirmation (round 568): my_pending_referral_confirmations() —
 * auth.uid()/referrer-scoped, excludes bounty-revoked rows. Read-only list.
 * The referee's raw user id is decoded but never displayed (PII); the UI shows
 * only the confirmation code + date.
 */
@Singleton
class PendingReferralRepository @Inject constructor(
    private val client: SupabaseClient,
) {
    @Serializable
    data class PendingReferral(
        @SerialName("id") val id: String,
        @SerialName("referee_user_id") val refereeUserId: String? = null,
        @SerialName("referral_confirmation_code") val confirmationCode: String = "",
        @SerialName("created_at") val createdAt: String? = null,
    )

    suspend fun fetch(): Result<List<PendingReferral>> = runCatching {
        client.postgrest
            .rpc(function = "my_pending_referral_confirmations")
            .decodeList<PendingReferral>()
    }

    /**
     * Confirms one pending referral via confirm_engineer_referral (round 568) —
     * caller-scoped (must be the referrer), idempotent (sets referrer_confirmed_at
     * once). Marks the referral confirmed; the bounty itself pays out later via a
     * separate anti-collusion-gated trigger, so this write releases no money.
     */
    suspend fun confirm(referralId: String): Result<Unit> = runCatching {
        client.postgrest.rpc(
            function = "confirm_engineer_referral",
            parameters = buildJsonObject { put("p_referral_id", JsonPrimitive(referralId)) },
        )
        Unit
    }
}
