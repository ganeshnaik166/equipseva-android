package com.equipseva.app.core.data.repair

import com.equipseva.app.core.util.parseInstantOrNull
import java.time.Instant

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
    createdAtInstant = createdAt?.parseInstantOrNull(),
    updatedAtInstant = updatedAt?.parseInstantOrNull(),
)

internal fun RepairBidWithDistanceDto.toDomain(): RepairBid = RepairBid(
    id = id,
    repairJobId = repairJobId,
    engineerUserId = engineerUserId,
    amountRupees = amountRupees,
    etaHours = etaHours,
    note = note?.takeIf { it.isNotBlank() },
    status = RepairBidStatus.fromKey(status),
    createdAtInstant = createdAt?.parseInstantOrNull(),
    updatedAtInstant = updatedAt?.parseInstantOrNull(),
    engineerName = engineerFullName?.takeIf { it.isNotBlank() },
    engineerAvatarUrl = engineerAvatarUrl?.takeIf { it.isNotBlank() },
    engineerRatingAvg = engineerRatingAvg,
    engineerTotalJobs = engineerTotalJobs,
    engineerCity = engineerCity?.takeIf { it.isNotBlank() },
    distanceKm = distanceKm,
)
