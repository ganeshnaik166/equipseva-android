package com.equipseva.app.core.data.logistics

interface LogisticsJobRepository {
    /** Jobs not yet assigned — the open pool of work a partner can pick up. */
    suspend fun fetchPending(): Result<List<LogisticsJob>>

    /** Jobs assigned to the given logistics partner, optionally narrowed by status list. */
    suspend fun fetchByPartnerAndStatuses(
        logisticsPartnerId: String,
        statuses: List<String>,
    ): Result<List<LogisticsJob>>

    /** All jobs for the given partner, regardless of status. */
    suspend fun fetchAllByPartner(logisticsPartnerId: String): Result<List<LogisticsJob>>

    /** Claim a pending job — sets logistics_partner_id and flips status to assigned. */
    suspend fun acceptJob(jobId: String, logisticsPartnerId: String): Result<LogisticsJob>
}
