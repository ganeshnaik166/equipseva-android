package com.equipseva.app.core.data.logistics

import com.equipseva.app.core.data.demo.DemoSeed
import javax.inject.Inject
import javax.inject.Singleton

/**
 * In-memory implementation backed by [DemoSeed]. Wired in by [LogisticsModule] when
 * `BuildConfig.DEMO_MODE` is true so the partner-side dashboards render rich sample
 * jobs. Acceptance / status flips are no-ops.
 */
@Singleton
class FakeLogisticsJobRepository @Inject constructor() : LogisticsJobRepository {

    private val seed: List<LogisticsJob> get() = DemoSeed.logisticsJobs

    override suspend fun fetchPending(): Result<List<LogisticsJob>> =
        Result.success(seed.filter { it.status == "pending" })

    override suspend fun fetchByPartnerAndStatuses(
        logisticsPartnerId: String,
        statuses: List<String>,
    ): Result<List<LogisticsJob>> {
        val statusSet = statuses.toSet()
        return Result.success(
            seed.filter {
                it.logisticsPartnerId == logisticsPartnerId &&
                    (statusSet.isEmpty() || it.status in statusSet)
            },
        )
    }

    override suspend fun fetchAllByPartner(logisticsPartnerId: String): Result<List<LogisticsJob>> =
        Result.success(seed.filter { it.logisticsPartnerId == logisticsPartnerId })

    override suspend fun acceptJob(jobId: String, logisticsPartnerId: String): Result<LogisticsJob> =
        Result.failure(UnsupportedOperationException("Demo mode: logistics acceptJob is disabled"))

    override suspend fun markInTransit(jobId: String): Result<LogisticsJob> =
        Result.failure(UnsupportedOperationException("Demo mode: markInTransit is disabled"))

    override suspend fun markDelivered(jobId: String): Result<LogisticsJob> =
        Result.failure(UnsupportedOperationException("Demo mode: markDelivered is disabled"))
}
