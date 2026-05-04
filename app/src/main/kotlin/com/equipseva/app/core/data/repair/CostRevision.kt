package com.equipseva.app.core.data.repair

import java.time.Instant

/**
 * In-flight or settled scope-change quote on a repair job. Engineers
 * propose; hospitals decide. Approval overwrites
 * `repair_jobs.contracted_amount_rupees` server-side via the
 * `decide_cost_revision` RPC.
 */
data class CostRevision(
    val id: String,
    val repairJobId: String,
    val engineerUserId: String,
    val originalAmountRupees: Double,
    val revisedAmountRupees: Double,
    val reason: String,
    val status: CostRevisionStatus,
    val createdAt: Instant?,
    val decidedAt: Instant?,
    val decisionBy: String?,
)

enum class CostRevisionStatus(val key: String) {
    Proposed("proposed"),
    Approved("approved"),
    Rejected("rejected"),
    Expired("expired");

    companion object {
        fun fromKey(key: String?): CostRevisionStatus =
            entries.firstOrNull { it.key.equals(key, ignoreCase = true) } ?: Proposed
    }
}
