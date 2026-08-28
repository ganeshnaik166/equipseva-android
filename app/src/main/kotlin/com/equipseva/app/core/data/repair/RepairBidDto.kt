package com.equipseva.app.core.data.repair

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class RepairBidDto(
    val id: String,
    @SerialName("repair_job_id") val repairJobId: String,
    @SerialName("engineer_user_id") val engineerUserId: String,
    // Nullable: repair_job_bids.amount_rupees has no NOT NULL constraint —
    // round479's audit8 migration explicitly guards `WHERE amount_rupees
    // IS NOT NULL` in its own pre-flight check, and its added precision
    // CHECK (`round(amount_rupees,2)=amount_rupees`) is written so a NULL
    // row still passes (3-valued CHECK logic). Every INSERT path in this
    // app (buildRepairBidInsert) always supplies a real value, so this
    // only bites on legacy/anomalous rows read back.
    @SerialName("amount_rupees") val amountRupees: Double? = null,
    @SerialName("eta_hours") val etaHours: Int? = null,
    val note: String? = null,
    val status: String? = null,
    @SerialName("created_at") val createdAt: String? = null,
    @SerialName("updated_at") val updatedAt: String? = null,
)

@Serializable
internal data class RepairBidInsertDto(
    @SerialName("repair_job_id") val repairJobId: String,
    @SerialName("engineer_user_id") val engineerUserId: String,
    @SerialName("amount_rupees") val amountRupees: Double,
    @SerialName("eta_hours") val etaHours: Int? = null,
    val note: String? = null,
    val status: String = "pending",
)

/**
 * PR-B: shape returned by `list_repair_job_bids_with_distance`. Same
 * core columns as [RepairBidDto] plus engineer denormalization +
 * Haversine distance. We keep this distinct from [RepairBidDto] so
 * the direct-table SELECT path (own-bid refresh, outbox handler) still
 * compiles without a full schema migration of every caller.
 */
@Serializable
internal data class RepairBidWithDistanceDto(
    val id: String,
    @SerialName("repair_job_id") val repairJobId: String,
    @SerialName("engineer_user_id") val engineerUserId: String,
    // Nullable — same repair_job_bids.amount_rupees column as
    // RepairBidDto (see its comment); list_repair_job_bids_with_distance
    // selects b.amount_rupees raw with no coalesce, unlike every other
    // enriched column in the same SELECT.
    @SerialName("amount_rupees") val amountRupees: Double? = null,
    @SerialName("eta_hours") val etaHours: Int? = null,
    val note: String? = null,
    val status: String? = null,
    @SerialName("created_at") val createdAt: String? = null,
    @SerialName("updated_at") val updatedAt: String? = null,
    @SerialName("engineer_full_name") val engineerFullName: String? = null,
    @SerialName("engineer_avatar_url") val engineerAvatarUrl: String? = null,
    @SerialName("engineer_rating_avg") val engineerRatingAvg: Double? = null,
    @SerialName("engineer_total_jobs") val engineerTotalJobs: Int? = null,
    @SerialName("engineer_city") val engineerCity: String? = null,
    @SerialName("distance_km") val distanceKm: Double? = null,
)
