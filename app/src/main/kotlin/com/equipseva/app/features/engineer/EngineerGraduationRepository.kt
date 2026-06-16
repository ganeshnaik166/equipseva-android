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

    @Serializable
    data class SupervisableJob(
        @SerialName("repair_job_id") val repairJobId: String,
        @SerialName("job_number") val jobNumber: String? = null,
        @SerialName("equipment_brand") val equipmentBrand: String? = null,
        @SerialName("equipment_model") val equipmentModel: String? = null,
        @SerialName("status") val status: String,
    )

    suspend fun fetchSupervisableJobs(): Result<List<SupervisableJob>> = runCatching {
        client.postgrest
            .rpc(function = "my_supervisable_jobs")
            .decodeList<SupervisableJob>()
    }

    @Serializable
    data class EligibleSupervisor(
        @SerialName("user_id") val userId: String,
        @SerialName("current_tier") val currentTier: String,
        @SerialName("jobs_completed") val jobsCompleted: Int = 0,
        @SerialName("display_name") val displayName: String,
    )

    suspend fun fetchEligibleSupervisors(): Result<List<EligibleSupervisor>> = runCatching {
        client.postgrest
            .rpc(function = "my_eligible_supervisors")
            .decodeList<EligibleSupervisor>()
    }

    suspend fun requestSupervision(jobId: String, supervisorUserId: String): Result<Unit> = runCatching {
        client.postgrest.rpc(
            function = "request_supervision",
            parameters = buildJsonObject {
                put("p_job_id", JsonPrimitive(jobId))
                put("p_supervisor_user_id", JsonPrimitive(supervisorUserId))
            },
        )
        Unit
    }

    suspend fun signoffSupervision(
        assignmentId: String,
        outcome: String,
        notes: String,
    ): Result<Unit> = runCatching {
        client.postgrest.rpc(
            function = "signoff_supervision",
            parameters = buildJsonObject {
                put("p_assignment_id", JsonPrimitive(assignmentId))
                put("p_outcome", JsonPrimitive(outcome))
                put("p_notes", JsonPrimitive(notes))
            },
        )
        Unit
    }

    // ---- r584 demand signals ----------------------------------------

    @Serializable
    data class MyDemandSignal(
        @SerialName("id") val id: String,
        @SerialName("occurred_at") val occurredAt: String,
        @SerialName("equipment_brand") val equipmentBrand: String? = null,
        @SerialName("equipment_model") val equipmentModel: String? = null,
        @SerialName("part_number") val partNumber: String? = null,
        @SerialName("urgency") val urgency: String = "standard",
        @SerialName("founder_priority") val founderPriority: String? = null,
        @SerialName("resolved_at") val resolvedAt: String? = null,
        @SerialName("resolved_via") val resolvedVia: String? = null,
        @SerialName("days_open") val daysOpen: Int = 0,
    )

    suspend fun fetchMyDemandSignals(): Result<List<MyDemandSignal>> = runCatching {
        client.postgrest
            .rpc(function = "my_reported_demand_signals")
            .decodeList<MyDemandSignal>()
    }

    // ---- r587 tier earnings projection -----------------------------

    @Serializable
    data class TierEarningsProjection(
        @SerialName("current_tier") val currentTier: String,
        @SerialName("current_platform_fee_pct") val currentPlatformFeePct: Double,
        @SerialName("next_tier") val nextTier: String? = null,
        @SerialName("next_platform_fee_pct") val nextPlatformFeePct: Double? = null,
        @SerialName("avg_monthly_gross_rupees") val avgMonthlyGrossRupees: Double,
        @SerialName("projected_monthly_uplift_rupees") val projectedMonthlyUpliftRupees: Double,
        @SerialName("completed_jobs_90d") val completedJobs90d: Int,
        @SerialName("supervised_completions_at_eval") val supervisedCompletionsAtEval: Int,
    )

    suspend fun fetchTierEarningsProjection(): Result<TierEarningsProjection?> = runCatching {
        client.postgrest
            .rpc(function = "my_tier_earnings_projection")
            .decodeList<TierEarningsProjection>()
            .firstOrNull()
    }

    // ---- r593 tier history ------------------------------------------

    @Serializable
    data class TierHistoryEntry(
        @SerialName("id") val id: String,
        @SerialName("prev_tier") val prevTier: String,
        @SerialName("new_tier") val newTier: String,
        @SerialName("change_kind") val changeKind: String,
        @SerialName("reason") val reason: String? = null,
        @SerialName("changed_at") val changedAt: String,
    )

    suspend fun fetchTierHistory(): Result<List<TierHistoryEntry>> = runCatching {
        client.postgrest
            .rpc(function = "my_tier_history")
            .decodeList<TierHistoryEntry>()
    }

    suspend fun reportDemandSignal(
        partNumber: String?,
        brand: String?,
        model: String?,
        query: String?,
        urgency: String,
    ): Result<Unit> = runCatching {
        client.postgrest.rpc(
            function = "record_spare_part_demand_signal",
            parameters = buildJsonObject {
                put("p_part_number", partNumber?.let { JsonPrimitive(it) } ?: JsonPrimitive(""))
                put("p_brand", brand?.let { JsonPrimitive(it) } ?: JsonPrimitive(""))
                put("p_model", model?.let { JsonPrimitive(it) } ?: JsonPrimitive(""))
                put("p_query", query?.let { JsonPrimitive(it) } ?: JsonPrimitive(""))
                put("p_source", JsonPrimitive("engineer_report"))
                put("p_urgency", JsonPrimitive(urgency))
            },
        )
        Unit
    }
}
