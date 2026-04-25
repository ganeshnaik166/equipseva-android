package com.equipseva.app.core.data.repair

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Wire shape for rows returned by the `list_nearby_repair_jobs` RPC. Same
 * core columns as repair_jobs plus the computed `distance_km` and the
 * hospital coords resolved from the joined `organizations` row.
 *
 * The RPC narrows the column set to what the engineer feed actually renders;
 * detail-page-only fields (diagnosis, payouts, etc.) are intentionally
 * absent. We map into the regular [RepairJobDto] for reuse of the existing
 * domain converter, then pair with distance.
 */
@Serializable
internal data class NearbyRepairJobDto(
    val id: String,
    @SerialName("job_number") val jobNumber: String? = null,
    @SerialName("hospital_user_id") val hospitalUserId: String? = null,
    @SerialName("hospital_org_id") val hospitalOrgId: String? = null,
    @SerialName("equipment_brand") val equipmentBrand: String? = null,
    @SerialName("equipment_model") val equipmentModel: String? = null,
    @SerialName("equipment_type") val equipmentType: String? = null,
    val urgency: String? = null,
    val status: String? = null,
    @SerialName("issue_description") val issueDescription: String = "",
    @SerialName("scheduled_date") val scheduledDate: String? = null,
    @SerialName("scheduled_time_slot") val scheduledTimeSlot: String? = null,
    @SerialName("estimated_cost") val estimatedCost: Double? = null,
    @SerialName("hospital_latitude") val hospitalLatitude: Double? = null,
    @SerialName("hospital_longitude") val hospitalLongitude: Double? = null,
    @SerialName("distance_km") val distanceKm: Double = 0.0,
    @SerialName("created_at") val createdAt: String? = null,
)

internal fun NearbyRepairJobDto.toDomainWithDistance(): RepairJobWithDistance {
    val baseDto = RepairJobDto(
        id = id,
        jobNumber = jobNumber,
        hospitalOrgId = hospitalOrgId,
        hospitalUserId = hospitalUserId,
        equipmentType = equipmentType,
        equipmentBrand = equipmentBrand,
        equipmentModel = equipmentModel,
        urgency = urgency,
        status = status,
        issueDescription = issueDescription,
        estimatedCost = estimatedCost,
        scheduledDate = scheduledDate,
        scheduledTimeSlot = scheduledTimeSlot,
        createdAt = createdAt,
    )
    return RepairJobWithDistance(
        job = baseDto.toDomain(),
        distanceKm = distanceKm,
        hospitalLatitude = hospitalLatitude,
        hospitalLongitude = hospitalLongitude,
    )
}
