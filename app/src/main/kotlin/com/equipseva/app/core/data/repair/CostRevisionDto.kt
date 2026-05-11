package com.equipseva.app.core.data.repair

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Postgrest DTO mirroring rows from `public.repair_job_cost_revisions`
 * + the JSONB return shape of `propose_cost_revision` / `decide_cost_revision`.
 */
@Serializable
data class CostRevisionDto(
    @SerialName("id") val id: String,
    @SerialName("repair_job_id") val repairJobId: String,
    @SerialName("engineer_user_id") val engineerUserId: String,
    @SerialName("original_amount_rupees") val originalAmountRupees: Double,
    @SerialName("revised_amount_rupees") val revisedAmountRupees: Double,
    @SerialName("reason") val reason: String,
    @SerialName("status") val status: String,
    @SerialName("created_at") val createdAtIso: String? = null,
    // decided_at / decision_by serialized fields are accepted on the wire
    // (so the server can keep sending them) but ignored: the UI never
    // surfaces who/when the revision was decided.
) {
    fun toDomain(): CostRevision = CostRevision(
        id = id,
        repairJobId = repairJobId,
        engineerUserId = engineerUserId,
        originalAmountRupees = originalAmountRupees,
        revisedAmountRupees = revisedAmountRupees,
        reason = reason,
        status = CostRevisionStatus.fromKey(status),
        createdAt = createdAtIso?.let { runCatching { java.time.Instant.parse(it) }.getOrNull() },
    )
}
