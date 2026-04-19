package com.equipseva.app.core.data.repair

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Wire shape returned by Supabase Postgrest for a `public.repair_jobs` row.
 *
 * Anything non-nullable in the schema that can still arrive null for old rows
 * (estimated_cost, scheduled_date, equipment_type on legacy jobs) is kept
 * nullable here. We decode defensively and map into the domain layer.
 *
 * Only columns the engineer feed actually renders are pulled. The full table
 * has many more fields (diagnosis, payouts, photos); those live on the
 * detail/bidding screens in a later phase.
 */
@Serializable
data class RepairJobDto(
    val id: String,
    @SerialName("job_number") val jobNumber: String? = null,
    @SerialName("hospital_org_id") val hospitalOrgId: String? = null,
    @SerialName("hospital_user_id") val hospitalUserId: String? = null,
    @SerialName("engineer_id") val engineerId: String? = null,
    @SerialName("equipment_type") val equipmentType: String? = null,
    @SerialName("equipment_brand") val equipmentBrand: String? = null,
    @SerialName("equipment_model") val equipmentModel: String? = null,
    @SerialName("job_type") val jobType: String? = null,
    val urgency: String? = null,
    val status: String? = null,
    @SerialName("issue_description") val issueDescription: String = "",
    @SerialName("estimated_cost") val estimatedCost: Double? = null,
    @SerialName("scheduled_date") val scheduledDate: String? = null,
    @SerialName("scheduled_time_slot") val scheduledTimeSlot: String? = null,
    @SerialName("created_at") val createdAt: String? = null,
    @SerialName("updated_at") val updatedAt: String? = null,
)
