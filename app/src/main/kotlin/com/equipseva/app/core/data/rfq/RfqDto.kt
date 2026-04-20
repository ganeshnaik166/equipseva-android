package com.equipseva.app.core.data.rfq

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class RfqDto(
    val id: String,
    @SerialName("rfq_number") val rfqNumber: String? = null,
    @SerialName("requester_org_id") val requesterOrgId: String,
    @SerialName("requester_user_id") val requesterUserId: String,
    val title: String,
    val description: String? = null,
    @SerialName("equipment_category") val equipmentCategory: String? = null,
    val quantity: Int? = 1,
    @SerialName("budget_range_min") val budgetRangeMin: Double? = null,
    @SerialName("budget_range_max") val budgetRangeMax: Double? = null,
    @SerialName("delivery_location") val deliveryLocation: String? = null,
    @SerialName("delivery_deadline") val deliveryDeadline: String? = null,
    val status: String? = "draft",
    @SerialName("bids_count") val bidsCount: Int? = 0,
    @SerialName("awarded_to_manufacturer_id") val awardedToManufacturerId: String? = null,
    val deadline: String,
    @SerialName("created_at") val createdAt: String? = null,
)
