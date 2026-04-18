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

private fun String.toInstantOrNull(): Instant? = try {
    Instant.parse(this)
} catch (_: DateTimeParseException) {
    null
}
