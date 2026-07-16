package com.equipseva.app.core.data.referrals

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

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
}
