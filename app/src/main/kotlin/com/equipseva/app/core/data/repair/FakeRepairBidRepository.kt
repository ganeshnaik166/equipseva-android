package com.equipseva.app.core.data.repair

import com.equipseva.app.core.data.demo.DemoSeed
import java.time.Instant
import javax.inject.Inject
import javax.inject.Singleton

/**
 * In-memory implementation backed by [DemoSeed]. Wired in by [RepairModule] when
 * `BuildConfig.DEMO_MODE` is true so the bid lists on the engineer + hospital
 * sides render rich sample data. Writes are no-ops.
 */
@Singleton
class FakeRepairBidRepository @Inject constructor() : RepairBidRepository {

    private val seed: List<RepairBid> get() = DemoSeed.repairBids

    override suspend fun fetchOwnBidForJob(jobId: String): Result<RepairBid?> =
        Result.success(
            seed.firstOrNull {
                it.repairJobId == jobId && it.engineerUserId == DemoSeed.DEMO_ENGINEER_USER
            },
        )

    override suspend fun fetchBidsForJob(jobId: String): Result<List<RepairBid>> =
        Result.success(
            seed
                .filter { it.repairJobId == jobId }
                .sortedBy { it.createdAtInstant ?: Instant.EPOCH },
        )

    override suspend fun placeBid(
        jobId: String,
        amountRupees: Double,
        etaHours: Int?,
        note: String?,
    ): Result<RepairBid> =
        Result.failure(UnsupportedOperationException("Demo mode: placing bids is disabled"))

    override suspend fun withdrawBid(bidId: String): Result<Unit> =
        Result.failure(UnsupportedOperationException("Demo mode: withdrawing bids is disabled"))

    override suspend fun acceptBid(bidId: String): Result<Unit> =
        Result.failure(UnsupportedOperationException("Demo mode: accepting bids is disabled"))

    override suspend fun fetchMyBids(): Result<List<RepairBid>> =
        Result.success(
            seed
                .filter { it.engineerUserId == DemoSeed.DEMO_ENGINEER_USER }
                .sortedByDescending { it.createdAtInstant ?: Instant.EPOCH },
        )
}
