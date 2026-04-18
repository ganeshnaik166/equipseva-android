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
}
