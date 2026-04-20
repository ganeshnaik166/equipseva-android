package com.equipseva.app.core.data.repair

interface RepairBidRepository {
    suspend fun fetchOwnBidForJob(jobId: String): Result<RepairBid?>

    /**
     * Pull every bid the caller is allowed to see for [jobId]. RLS decides
     * the scope: engineers get their own row, hospitals get every bid on
     * jobs they own. Used by the hospital-side detail screen to pick a
     * winner.
     */
    suspend fun fetchBidsForJob(jobId: String): Result<List<RepairBid>>

    suspend fun placeBid(
        jobId: String,
        amountRupees: Double,
        etaHours: Int? = null,
        note: String? = null,
    ): Result<RepairBid>
    suspend fun withdrawBid(bidId: String): Result<Unit>

    /**
     * Hospital accepts one pending bid. Delegates to an RPC that atomically
     * flips this bid to accepted, rejects the rest, and moves the parent
     * job to `assigned` with the engineer set. Returns unit — the caller
     * refreshes job + bids from source to get the new state.
     */
    suspend fun acceptBid(bidId: String): Result<Unit>

    /** All bids placed by the signed-in engineer, newest first. RLS restricts to own rows. */
    suspend fun fetchMyBids(): Result<List<RepairBid>>
}
