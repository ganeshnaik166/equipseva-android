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
 * Read-side repo for the engineer's tier-graduation cockpit.
 * Calls my_supervision_graduation_status() (r578) which is auth.uid()-
 * scoped server-side; client-side auth checks are defense-in-depth.
 */
@Singleton
class EngineerGraduationRepository @Inject constructor(
    private val client: SupabaseClient,
) {
    @Serializable
    data class GraduationStatus(
        @SerialName("current_tier") val currentTier: String,
        @SerialName("next_tier") val nextTier: String? = null,
        @SerialName("jobs_completed") val jobsCompleted: Int = 0,
        @SerialName("jobs_required_for_next") val jobsRequiredForNext: Int? = null,
        @SerialName("dispute_rate_pct") val disputeRatePct: Double = 0.0,
        @SerialName("max_dispute_rate_for_next") val maxDisputeRateForNext: Double? = null,
        @SerialName("verified_tier_at_eval") val verifiedTierAtEval: String = "none",
        @SerialName("min_verified_tier_for_next") val minVerifiedTierForNext: String? = null,
        @SerialName("supervised_completed") val supervisedCompleted: Int = 0,
        @SerialName("supervised_required_for_next") val supervisedRequiredForNext: Int? = null,
    )

    suspend fun fetchGraduationStatus(): Result<GraduationStatus?> = runCatching {
        client.postgrest
            .rpc(function = "my_supervision_graduation_status")
            .decodeList<GraduationStatus>()
            .firstOrNull()
    }

    @Serializable
    data class SupervisionRow(
        @SerialName("role") val role: String,           // "trainee" or "supervisor"
        @SerialName("assignment_id") val assignmentId: String,
        @SerialName("counterpart_user_id") val counterpartUserId: String,
        @SerialName("repair_job_id") val repairJobId: String,
        @SerialName("status") val status: String,
        @SerialName("trainee_tier_at_assignment") val traineeTier: String,
        @SerialName("supervisor_tier_at_assignment") val supervisorTier: String,
        @SerialName("requested_at") val requestedAt: String,
        @SerialName("signoff_outcome") val signoffOutcome: String? = null,
        @SerialName("signoff_at") val signoffAt: String? = null,
    )

    suspend fun fetchSupervisionProgress(): Result<List<SupervisionRow>> = runCatching {
        client.postgrest
            .rpc(function = "my_supervision_progress")
            .decodeList<SupervisionRow>()
    }

    suspend fun acceptSupervision(assignmentId: String): Result<Unit> = runCatching {
        client.postgrest.rpc(
            function = "accept_supervision",
            parameters = buildJsonObject {
                put("p_assignment_id", JsonPrimitive(assignmentId))
            },
        )
        Unit
    }

    suspend fun declineSupervision(assignmentId: String, reason: String): Result<Unit> = runCatching {
        client.postgrest.rpc(
            function = "decline_supervision",
            parameters = buildJsonObject {
                put("p_assignment_id", JsonPrimitive(assignmentId))
                put("p_reason", JsonPrimitive(reason))
            },
        )
        Unit
    }
}
