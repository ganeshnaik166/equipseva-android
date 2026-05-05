package com.equipseva.app.core.data.repair

import java.time.Instant
import java.time.format.DateTimeParseException

data class RepairBid(
    val id: String,
    val repairJobId: String,
    val engineerUserId: String,
    val amountRupees: Double,
    val etaHours: Int?,
    val note: String?,
    val status: RepairBidStatus,
    val createdAtInstant: Instant?,
    val updatedAtInstant: Instant?,
    // PR-B: optional enrichment from list_repair_job_bids_with_distance.
    // Null when the row was loaded via a direct table SELECT (eg. own bid
    // refresh or outbox path) — UI should treat each as best-effort.
    val engineerName: String? = null,
    val engineerAvatarUrl: String? = null,
    val engineerRatingAvg: Double? = null,
    val engineerTotalJobs: Int? = null,
    val engineerCity: String? = null,
    val distanceKm: Double? = null,
)

internal fun RepairBidDto.toDomain(): RepairBid = RepairBid(
    id = id,
    repairJobId = repairJobId,
    engineerUserId = engineerUserId,
    amountRupees = amountRupees,
    etaHours = etaHours,
    note = note?.takeIf { it.isNotBlank() },
    status = RepairBidStatus.fromKey(status),
    createdAtInstant = createdAt?.toInstantOrNull(),
    updatedAtInstant = updatedAt?.toInstantOrNull(),
)

internal fun RepairBidWithDistanceDto.toDomain(): RepairBid = RepairBid(
    id = id,
    repairJobId = repairJobId,
    engineerUserId = engineerUserId,
    amountRupees = amountRupees,
    etaHours = etaHours,
    note = note?.takeIf { it.isNotBlank() },
    status = RepairBidStatus.fromKey(status),
    createdAtInstant = createdAt?.toInstantOrNull(),
    updatedAtInstant = updatedAt?.toInstantOrNull(),
    engineerName = engineerFullName?.takeIf { it.isNotBlank() },
    engineerAvatarUrl = engineerAvatarUrl?.takeIf { it.isNotBlank() },
    engineerRatingAvg = engineerRatingAvg,
    engineerTotalJobs = engineerTotalJobs,
    engineerCity = engineerCity?.takeIf { it.isNotBlank() },
    distanceKm = distanceKm,
)

private fun String.toInstantOrNull(): Instant? = try {
    Instant.parse(this)
} catch (_: DateTimeParseException) {
    null
}
