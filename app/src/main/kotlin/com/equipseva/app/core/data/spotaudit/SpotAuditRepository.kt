package com.equipseva.app.core.data.spotaudit

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject

/**
 * v2.1 PR-D43 — random spot-audit sampling. Strategy memo T2.10:
 * 1-in-20 of completed jobs surface a quality questionnaire to the
 * hospital. Complementary to the cash-flag survey (PR-D1) which is
 * targeted at every job; spot-audits catch nuance the targeted
 * question misses.
 */
@Singleton
class SpotAuditRepository @Inject constructor(
    private val supabase: SupabaseClient,
) {
    @Serializable
    data class PendingInvitation(
        @SerialName("invitation_id") val invitationId: String,
        @SerialName("repair_job_id") val repairJobId: String,
        @SerialName("job_number") val jobNumber: String? = null,
        @SerialName("engineer_id") val engineerId: String? = null,
        @SerialName("engineer_name") val engineerName: String? = null,
        @SerialName("expires_at") val expiresAt: String? = null,
    )

    suspend fun fetchPending(): Result<PendingInvitation?> = runCatching {
        supabase.postgrest.rpc(function = "get_pending_spot_audit")
            .decodeList<PendingInvitation>()
            .firstOrNull()
    }

    suspend fun submit(
        invitationId: String,
        rating: Int,
        feedback: String?,
    ): Result<Unit> = runCatching {
        supabase.postgrest.rpc(
            function = "submit_spot_audit",
            parameters = buildJsonObject {
                put("p_invitation_id", JsonPrimitive(invitationId))
                put("p_rating", JsonPrimitive(rating))
                put("p_feedback", feedback?.let { JsonPrimitive(it) } ?: JsonNull)
            },
        )
        Unit
    }
}
