package com.equipseva.app.core.data.logistics

data class LogisticsJob(
    val id: String,
    val jobNumber: String?,
    val requesterOrgId: String,
    val logisticsPartnerId: String?,
    val jobType: String,
    val equipmentDescription: String?,
    val pickupCity: String?,
    val pickupState: String?,
    val deliveryCity: String?,
    val deliveryState: String?,
    val preferredDateIso: String?,
    val actualPickupAtIso: String?,
    val actualDeliveryAtIso: String?,
    val quotedPriceRupees: Double?,
    val finalPriceRupees: Double?,
    val status: String,
    val specialInstructions: String?,
    val createdAtIso: String?,
) {
    val pickupLocationLine: String?
        get() = listOfNotNull(pickupCity, pickupState)
            .filter { it.isNotBlank() }
            .joinToString(", ")
            .ifBlank { null }

    val deliveryLocationLine: String?
        get() = listOfNotNull(deliveryCity, deliveryState)
            .filter { it.isNotBlank() }
            .joinToString(", ")
            .ifBlank { null }
}

internal fun LogisticsJobDto.toDomain(): LogisticsJob = LogisticsJob(
    id = id,
    jobNumber = jobNumber,
    requesterOrgId = requesterOrgId,
    logisticsPartnerId = logisticsPartnerId,
    jobType = jobType ?: "delivery",
    equipmentDescription = equipmentDescription,
    pickupCity = pickupCity,
    pickupState = pickupState,
    deliveryCity = deliveryCity,
    deliveryState = deliveryState,
    preferredDateIso = preferredDate,
    actualPickupAtIso = actualPickupDate,
    actualDeliveryAtIso = actualDeliveryDate,
    quotedPriceRupees = quotedPrice,
    finalPriceRupees = finalPrice,
    status = status ?: "pending",
    specialInstructions = specialInstructions,
    createdAtIso = createdAt,
)
