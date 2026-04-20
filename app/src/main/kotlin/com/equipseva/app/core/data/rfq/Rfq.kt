package com.equipseva.app.core.data.rfq

data class Rfq(
    val id: String,
    val rfqNumber: String?,
    val requesterOrgId: String,
    val title: String,
    val description: String?,
    val equipmentCategory: String?,
    val quantity: Int,
    val budgetMinRupees: Double?,
    val budgetMaxRupees: Double?,
    val deliveryLocation: String?,
    val deliveryDeadlineIso: String?,
    val status: String,
    val bidsCount: Int,
    val deadlineIso: String,
    val createdAtIso: String?,
) {
    val isOpen: Boolean
        get() = status.equals("open", ignoreCase = true) || status.equals("published", ignoreCase = true)
}

internal fun RfqDto.toDomain(): Rfq = Rfq(
    id = id,
    rfqNumber = rfqNumber,
    requesterOrgId = requesterOrgId,
    title = title,
    description = description,
    equipmentCategory = equipmentCategory,
    quantity = quantity ?: 1,
    budgetMinRupees = budgetRangeMin,
    budgetMaxRupees = budgetRangeMax,
    deliveryLocation = deliveryLocation,
    deliveryDeadlineIso = deliveryDeadline,
    status = status ?: "draft",
    bidsCount = bidsCount ?: 0,
    deadlineIso = deadline,
    createdAtIso = createdAt,
)
