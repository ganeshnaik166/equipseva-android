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
 * Round 3779 — engineer periodic re-KYC self-service (round497,
 * unread by any client until now). A daily cron opens a renewal row
 * ~30 days before an engineer's 1-year KYC anniversary; a separate
 * daily reaper auto-reverts verification_status back to 'pending'
 * (delisting from the hospital directory) if the engineer never acts
 * within the 14-day grace window — so this screen is a real, ongoing
 * trust-signal-preservation nudge, not a cosmetic add-on.
 */
@Singleton
class KycRenewalRepository @Inject constructor(
    private val client: SupabaseClient,
) {
    @Serializable
    data class KycRenewal(
        val id: String,
        @SerialName("due_at") val dueAt: String,
        @SerialName("grace_until") val graceUntil: String,
        val status: String,
        @SerialName("required_items") val requiredItems: List<String> = emptyList(),
        @SerialName("refreshed_items") val refreshedItems: List<String> = emptyList(),
        @SerialName("remaining_items") val remainingItems: List<String>? = null,
        @SerialName("days_until_due") val daysUntilDue: Double,
    )

    suspend fun fetchMyRenewal(): Result<KycRenewal?> = runCatching {
        client.postgrest.rpc(function = "my_kyc_renewal").decodeSingleOrNull<KycRenewal>()
    }

    suspend fun startRenewal(renewalId: String): Result<Unit> = runCatching {
        client.postgrest.rpc(
            function = "start_kyc_renewal",
            parameters = buildJsonObject { put("p_renewal_id", JsonPrimitive(renewalId)) },
        )
        Unit
    }

    suspend fun markItemRefreshed(renewalId: String, item: String): Result<Unit> = runCatching {
        client.postgrest.rpc(
            function = "mark_renewal_item_refreshed",
            parameters = buildJsonObject {
                put("p_renewal_id", JsonPrimitive(renewalId))
                put("p_item", JsonPrimitive(item))
            },
        )
        Unit
    }
}
