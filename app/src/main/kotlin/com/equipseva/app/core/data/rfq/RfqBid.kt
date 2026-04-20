package com.equipseva.app.core.data.rfq

data class RfqBid(
    val id: String,
    val rfqId: String,
    val manufacturerId: String,
    val unitPriceRupees: Double,
    val totalPriceRupees: Double,
    val deliveryTimelineDays: Int?,
    val warrantyMonths: Int?,
    val includesInstallation: Boolean,
    val includesTraining: Boolean,
    val status: String,
    val notes: String?,
    val createdAtIso: String?,
)

internal fun RfqBidDto.toDomain(): RfqBid = RfqBid(
    id = id,
    rfqId = rfqId,
    manufacturerId = manufacturerId,
    unitPriceRupees = unitPrice,
    totalPriceRupees = totalPrice,
    deliveryTimelineDays = deliveryTimelineDays,
    warrantyMonths = warrantyMonths,
    includesInstallation = includesInstallation ?: false,
    includesTraining = includesTraining ?: false,
    status = status ?: "submitted",
    notes = notes,
    createdAtIso = createdAt,
)
