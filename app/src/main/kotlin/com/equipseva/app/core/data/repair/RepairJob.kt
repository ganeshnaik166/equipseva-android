package com.equipseva.app.core.data.repair

import java.time.Instant
import java.time.format.DateTimeParseException

/**
 * UI-facing repair job. Computed fields (title, createdAtInstant) live here so
 * the screen never has to care about wire formats. Anything server-side that
 * can be null is resolved to a safe default at the domain boundary.
 */
data class RepairJob(
    val id: String,
    val jobNumber: String?,
    val title: String,
    val issueDescription: String,
    val equipmentCategory: RepairEquipmentCategory,
    val equipmentBrand: String?,
    val equipmentModel: String?,
    val status: RepairJobStatus,
    val urgency: RepairJobUrgency,
    val estimatedCostRupees: Double?,
    val scheduledDate: String?,
    val scheduledTimeSlot: String?,
    val siteLocation: String?,
    val isAssignedToEngineer: Boolean,
    val engineerId: String?,
    val hospitalUserId: String?,
    val startedAtInstant: Instant?,
    val completedAtInstant: Instant?,
    val hospitalRating: Int?,
    val hospitalReview: String?,
    val engineerRating: Int?,
    val engineerReview: String?,
    val createdAtInstant: Instant?,
    val updatedAtInstant: Instant?,
    val issuePhotos: List<String> = emptyList(),
    val beforePhotos: List<String> = emptyList(),
    val afterPhotos: List<String> = emptyList(),
) {
    /** Short label for the equipment line, e.g. "GE Logiq P5" or "Imaging & radiology". */
    val equipmentLabel: String
        get() {
            val brandModel = listOfNotNull(
                equipmentBrand?.takeIf { it.isNotBlank() },
                equipmentModel?.takeIf { it.isNotBlank() },
            ).joinToString(" ")
            return brandModel.ifBlank { equipmentCategory.displayName }
        }
}

internal fun RepairJobDto.toDomain(): RepairJob {
    val category = RepairEquipmentCategory.fromKey(equipmentType)
    val title = buildTitle(
        jobNumber = jobNumber,
        category = category,
        issue = issueDescription,
    )
    return RepairJob(
        id = id,
        jobNumber = jobNumber,
        title = title,
        issueDescription = issueDescription,
        equipmentCategory = category,
        equipmentBrand = equipmentBrand?.takeIf { it.isNotBlank() },
        equipmentModel = equipmentModel?.takeIf { it.isNotBlank() },
        status = RepairJobStatus.fromKey(status),
        urgency = RepairJobUrgency.fromKey(urgency),
        estimatedCostRupees = estimatedCost?.takeIf { it > 0.0 },
        scheduledDate = scheduledDate?.takeIf { it.isNotBlank() },
        scheduledTimeSlot = scheduledTimeSlot?.takeIf { it.isNotBlank() },
        siteLocation = siteLocation?.takeIf { it.isNotBlank() },
        isAssignedToEngineer = !engineerId.isNullOrBlank(),
        engineerId = engineerId?.takeIf { it.isNotBlank() },
        hospitalUserId = hospitalUserId?.takeIf { it.isNotBlank() },
        startedAtInstant = startedAt?.toInstantOrNull(),
        completedAtInstant = completedAt?.toInstantOrNull(),
        hospitalRating = hospitalRating?.takeIf { it in 1..5 },
        hospitalReview = hospitalReview?.takeIf { it.isNotBlank() },
        engineerRating = engineerRating?.takeIf { it in 1..5 },
        engineerReview = engineerReview?.takeIf { it.isNotBlank() },
        createdAtInstant = createdAt?.toInstantOrNull(),
        updatedAtInstant = updatedAt?.toInstantOrNull(),
        issuePhotos = issuePhotos.orEmpty().filter { it.isNotBlank() },
        beforePhotos = beforePhotos.orEmpty().filter { it.isNotBlank() },
        afterPhotos = afterPhotos.orEmpty().filter { it.isNotBlank() },
    )
}

private fun buildTitle(
    jobNumber: String?,
    category: RepairEquipmentCategory,
    issue: String,
): String {
    val firstIssueLine = issue
        .lineSequence()
        .map { it.trim() }
        .firstOrNull { it.isNotBlank() }
        ?.take(80)
    return when {
        !firstIssueLine.isNullOrBlank() -> firstIssueLine
        !jobNumber.isNullOrBlank() -> "Job $jobNumber"
        else -> category.displayName
    }
}

private fun String.toInstantOrNull(): Instant? = try {
    Instant.parse(this)
} catch (_: DateTimeParseException) {
    null
} catch (_: IllegalArgumentException) {
    null
}
