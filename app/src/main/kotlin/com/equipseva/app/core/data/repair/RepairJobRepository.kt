package com.equipseva.app.core.data.repair

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
}

data class RepairJobDraft(
    val hospitalUserId: String,
    val hospitalOrgId: String?,
    val issueDescription: String,
    val equipmentCategory: RepairEquipmentCategory,
    val equipmentBrand: String?,
    val equipmentModel: String?,
    val urgency: RepairJobUrgency,
)
