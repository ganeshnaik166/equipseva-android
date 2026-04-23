package com.equipseva.app.core.data.rfq

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class RfqBidInsertDto(
    @SerialName("rfq_id") val rfqId: String,
    @SerialName("manufacturer_id") val manufacturerId: String,
    @SerialName("unit_price") val unitPrice: Double,
    @SerialName("total_price") val totalPrice: Double,
    @SerialName("delivery_timeline_days") val deliveryTimelineDays: Int? = null,
    @SerialName("warranty_months") val warrantyMonths: Int? = null,
    @SerialName("includes_installation") val includesInstallation: Boolean = false,
    @SerialName("includes_training") val includesTraining: Boolean = false,
    val notes: String? = null,
)
