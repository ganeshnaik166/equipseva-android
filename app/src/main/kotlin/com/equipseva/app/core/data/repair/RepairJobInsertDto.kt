package com.equipseva.app.core.data.repair

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Wire shape for inserting a new `repair_jobs` row. The server fills in id,
 * job_number, created_at, updated_at, and the job_type / urgency defaults if we
 * don't supply them. We pass the fields the hospital user captured on the
 * request-service form, plus [status] (see below).
 *
 * `status` MUST be sent and MUST be a required (no-default) field: the INSERT
 * RLS policy has `WITH CHECK (status = 'requested')`, and the Postgrest Json is
 * configured with `encodeDefaults = false`. A defaulted `status = "requested"`
 * would be dropped from the wire JSON, the column would fall to the (drifted)
 * DB default, and the RLS check would reject the insert with a 403 that the app
 * surfaces as a generic "Something went wrong". Keeping it non-default forces it
 * onto the wire. (r1400 — fixes hospital "Post new job" failing outright.)
 */
@Serializable
internal data class RepairJobInsertDto(
    @SerialName("hospital_user_id") val hospitalUserId: String,
    val status: String,
    @SerialName("hospital_org_id") val hospitalOrgId: String? = null,
    @SerialName("equipment_type") val equipmentType: String? = null,
    @SerialName("equipment_brand") val equipmentBrand: String? = null,
    @SerialName("equipment_model") val equipmentModel: String? = null,
    @SerialName("equipment_serial") val equipmentSerial: String? = null,
    @SerialName("site_location") val siteLocation: String? = null,
    @SerialName("site_latitude") val siteLatitude: Double? = null,
    @SerialName("site_longitude") val siteLongitude: Double? = null,
    val urgency: String? = null,
    @SerialName("issue_description") val issueDescription: String,
    @SerialName("issue_photos") val issuePhotos: List<String>? = null,
    @SerialName("scheduled_date") val scheduledDate: String? = null,
    @SerialName("scheduled_time_slot") val scheduledTimeSlot: String? = null,
    @SerialName("estimated_cost") val estimatedCost: Double? = null,
)
