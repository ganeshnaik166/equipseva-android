package com.equipseva.app.core.data.repair

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class RepairBidDto(
    val id: String,
    @SerialName("repair_job_id") val repairJobId: String,
    @SerialName("engineer_user_id") val engineerUserId: String,
    @SerialName("amount_rupees") val amountRupees: Double,
    @SerialName("eta_hours") val etaHours: Int? = null,
    val note: String? = null,
    val status: String? = null,
    @SerialName("created_at") val createdAt: String? = null,
    @SerialName("updated_at") val updatedAt: String? = null,
)

@Serializable
internal data class RepairBidInsertDto(
    @SerialName("repair_job_id") val repairJobId: String,
    @SerialName("engineer_user_id") val engineerUserId: String,
    @SerialName("amount_rupees") val amountRupees: Double,
    @SerialName("eta_hours") val etaHours: Int? = null,
    val note: String? = null,
    val status: String = "pending",
)
