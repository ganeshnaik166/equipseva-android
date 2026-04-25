package com.equipseva.app.core.data.repair

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Wire shape for inserting a new `repair_jobs` row. The server fills in id,
 * job_number, created_at, updated_at, and the job_type / urgency / status defaults
 * if we don't supply them. We pass only the fields the hospital user actually
 * captured on the request-service form.
 */
@Serializable
internal data class RepairJobInsertDto(
    @SerialName("hospital_user_id") val hospitalUserId: String,
    @SerialName("hospital_org_id") val hospitalOrgId: String? = null,
    @SerialName("equipment_type") val equipmentType: String? = null,
    @SerialName("equipment_brand") val equipmentBrand: String? = null,
    @SerialName("equipment_model") val equipmentModel: String? = null,
    @SerialName("equipment_serial") val equipmentSerial: String? = null,
    @SerialName("site_location") val siteLocation: String? = null,
    val urgency: String? = null,
    @SerialName("issue_description") val issueDescription: String,
    @SerialName("issue_photos") val issuePhotos: List<String>? = null,
    @SerialName("scheduled_date") val scheduledDate: String? = null,
    @SerialName("scheduled_time_slot") val scheduledTimeSlot: String? = null,
    @SerialName("estimated_cost") val estimatedCost: Double? = null,
)
