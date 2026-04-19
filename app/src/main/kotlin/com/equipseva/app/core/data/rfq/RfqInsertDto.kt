package com.equipseva.app.core.data.rfq

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Wire shape for inserting into `rfqs`. Excludes server-generated fields
 * (id, rfq_number, bids_count, created_at) and lets the DB supply defaults
 * for status. The `deadline` column is NOT NULL so the client must supply it
 * (kept in lockstep with delivery_deadline).
 */
@Serializable
data class RfqInsertDto(
    @SerialName("requester_org_id") val requesterOrgId: String,
    @SerialName("requester_user_id") val requesterUserId: String,
    val title: String,
    val description: String? = null,
    @SerialName("equipment_category") val equipmentCategory: String? = null,
    val quantity: Int = 1,
    @SerialName("budget_range_min") val budgetRangeMin: Double? = null,
    @SerialName("budget_range_max") val budgetRangeMax: Double? = null,
    @SerialName("delivery_location") val deliveryLocation: String? = null,
    @SerialName("delivery_deadline") val deliveryDeadline: String? = null,
    val deadline: String,
    val status: String = "open",
)
