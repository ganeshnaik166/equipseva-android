package com.equipseva.app.core.data.repair

interface RepairBidRepository {
    suspend fun fetchOwnBidForJob(jobId: String): Result<RepairBid?>
    suspend fun placeBid(
        jobId: String,
        amountRupees: Double,
        etaHours: Int? = null,
        note: String? = null,
    ): Result<RepairBid>
    suspend fun withdrawBid(bidId: String): Result<Unit>
}
