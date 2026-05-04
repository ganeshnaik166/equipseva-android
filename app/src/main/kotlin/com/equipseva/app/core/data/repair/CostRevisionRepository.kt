package com.equipseva.app.core.data.repair

import kotlinx.coroutines.flow.Flow

/**
 * Engineer ↔ Hospital scope-change negotiation. Drives the
 * propose_cost_revision / decide_cost_revision SECURITY DEFINER RPCs
 * server-side; observePending streams the table directly via
 * Postgrest realtime so the hospital banner / engineer "awaiting
 * approval" state are eventually-consistent without a manual refresh.
 */
interface CostRevisionRepository {

    /** Engineer-only. Server enforces side-identity + status gates. */
    suspend fun propose(
        repairJobId: String,
        revisedAmountRupees: Double,
        reason: String,
    ): Result<CostRevision>

    /** Hospital-only. Server enforces side-identity + status gate. */
    suspend fun decide(
        revisionId: String,
        approve: Boolean,
    ): Result<CostRevision>

    /** Latest pending revision for the job, or null if none in flight. */
    suspend fun fetchPending(repairJobId: String): Result<CostRevision?>

    /**
     * Realtime stream of the pending revision (if any) for a job. Emits
     * null when the row is absent / approved / rejected / expired so
     * the UI banner can hide automatically.
     */
    fun observePending(repairJobId: String): Flow<CostRevision?>
}
