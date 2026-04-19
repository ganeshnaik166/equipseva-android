package com.equipseva.app.core.data.logistics

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class LogisticsJobDto(
    val id: String,
    @SerialName("job_number") val jobNumber: String? = null,
    @SerialName("requester_org_id") val requesterOrgId: String,
    @SerialName("logistics_partner_id") val logisticsPartnerId: String? = null,
    @SerialName("job_type") val jobType: String? = "delivery",
    @SerialName("equipment_description") val equipmentDescription: String? = null,
    @SerialName("pickup_city") val pickupCity: String? = null,
    @SerialName("pickup_state") val pickupState: String? = null,
    @SerialName("delivery_city") val deliveryCity: String? = null,
    @SerialName("delivery_state") val deliveryState: String? = null,
    @SerialName("preferred_date") val preferredDate: String? = null,
    @SerialName("actual_pickup_date") val actualPickupDate: String? = null,
    @SerialName("actual_delivery_date") val actualDeliveryDate: String? = null,
    @SerialName("quoted_price") val quotedPrice: Double? = null,
    @SerialName("final_price") val finalPrice: Double? = null,
    val status: String? = "pending",
    @SerialName("special_instructions") val specialInstructions: String? = null,
    @SerialName("created_at") val createdAt: String? = null,
)
