package com.equipseva.app.core.data.repair

import java.time.Instant

interface RepairJobRepository {
    /**
     * Server-filtered query against `public.repair_jobs` restricted to jobs an
     * engineer can pick up. RLS on the table narrows this further: the
     * authenticated caller only sees rows the backend deems visible to them.
     *
     * @param query free-text search against issue description / equipment model (ILIKE).
     * @param page zero-based page index.
     * @param pageSize how many rows per page.
     */
    suspend fun fetchOpenJobs(
        page: Int = 0,
        pageSize: Int = 20,
        query: String? = null,
    ): Result<List<RepairJob>>

    /**
     * Engineer feed filtered by distance from the engineer's registered base
     * coords. Returns each open job with its computed haversine distance to
     * the engineer's home location. Uses the `list_nearby_repair_jobs` RPC
     * which joins repair_jobs → organizations on hospital_org_id.
     */
    suspend fun fetchNearbyJobs(
        radiusKm: Double = 50.0,
        limit: Int = 100,
    ): Result<List<RepairJobWithDistance>>

    /** Fetch a single job by id. Returns `null` if not found / not visible to caller. */
    suspend fun fetchById(jobId: String): Result<RepairJob?>

    /** Jobs where the signed-in engineer is the assignee. RLS narrows to caller. */
    suspend fun fetchAssignedToMe(): Result<List<RepairJob>>

    /** Bulk-load jobs by id. Used to decorate bids with parent-job context. */
    suspend fun fetchByIds(jobIds: Collection<String>): Result<List<RepairJob>>

    /** Jobs created by the signed-in hospital user — hospital "active jobs" view. */
    suspend fun fetchByHospitalUser(hospitalUserId: String): Result<List<RepairJob>>

    /**
     * Create a new repair job on behalf of the signed-in hospital user.
     * Caller supplies just the free-text + enum fields; server mints id/job_number.
     */
    suspend fun create(draft: RepairJobDraft): Result<RepairJob>

    /**
     * Sparse status transition. Callers supply `startedAt`/`completedAt` only
     * when the transition is the one that records that timestamp (check-in →
     * sets started_at; mark-done → sets completed_at). RLS restricts who can
     * update which rows.
     */
    suspend fun updateStatus(
        jobId: String,
        newStatus: RepairJobStatus,
        startedAt: Instant? = null,
        completedAt: Instant? = null,
    ): Result<RepairJob>

    /**
     * Submit a post-completion rating from one side of the job. [role] decides
     * which pair of columns (hospital_* vs engineer_*) is written so each side
     * can only score the other.
     */
    suspend fun submitRating(
        jobId: String,
        role: RatingRole,
        stars: Int,
        review: String?,
    ): Result<RepairJob>
}

enum class RatingRole {
    /** Hospital requester scoring the engineer who completed the job. */
    HospitalRatesEngineer,

    /** Engineer scoring the hospital requester after completion. */
    EngineerRatesHospital,
}

data class RepairJobDraft(
    val hospitalUserId: String,
    val hospitalOrgId: String?,
    val issueDescription: String,
    val equipmentCategory: RepairEquipmentCategory,
    val equipmentBrand: String?,
    val equipmentModel: String?,
    val urgency: RepairJobUrgency,
    val scheduledDate: String? = null,
    val scheduledTimeSlot: String? = null,
    val estimatedCostRupees: Double? = null,
)
