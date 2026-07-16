package com.equipseva.app.core.data.engineers

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject

/**
 * The calling engineer's current periodic re-KYC cycle via my_kyc_renewal()
 * (round 497) — auth.uid()-scoped. Verified engineers are re-verified roughly
 * yearly; when a cycle is open this returns the single pending/in-progress
 * record with the items still to refresh and days until due. Returns null when
 * nothing is due (the common case). Read-only; drives the "KYC renewal" nudge.
 */
@Singleton
class KycRenewalRepository @Inject constructor(
    private val client: SupabaseClient,
) {
    @Serializable
    data class KycRenewal(
        @SerialName("id") val id: String,
        @SerialName("due_at") val dueAt: String? = null,
        @SerialName("grace_until") val graceUntil: String? = null,
        // pending | in_progress
        @SerialName("status") val status: String = "pending",
        @SerialName("required_items") val requiredItems: List<String> = emptyList(),
        @SerialName("refreshed_items") val refreshedItems: List<String> = emptyList(),
        @SerialName("remaining_items") val remainingItems: List<String> = emptyList(),
        // Fractional days remaining; negative when past due (into grace).
        @SerialName("days_until_due") val daysUntilDue: Double = 0.0,
    )

    suspend fun fetch(): Result<KycRenewal?> = runCatching {
        client.postgrest
            .rpc(function = "my_kyc_renewal")
            .decodeList<KycRenewal>()
            .firstOrNull()
    }

    /**
     * Move a still-pending renewal to in_progress (r1431). Backed by
     * start_kyc_renewal, which re-checks the caller owns it and it's pending.
     */
    suspend fun start(renewalId: String): Result<Unit> = runCatching {
        client.postgrest.rpc(
            function = "start_kyc_renewal",
            parameters = buildJsonObject { put("p_renewal_id", JsonPrimitive(renewalId)) },
        )
        Unit
    }

    /**
     * Flag one required item as refreshed. Backed by mark_renewal_item_refreshed
     * ([item] must be aadhaar / degree_digilocker / police_verification / photo).
     * The founder still verifies + closes the renewal, so this is a safe
     * self-attestation, not auto-approval.
     */
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
