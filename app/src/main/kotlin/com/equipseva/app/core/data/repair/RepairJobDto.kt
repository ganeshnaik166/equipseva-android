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
    // Photo arrays. Filled in by the engineer at "Mark done" (after_photos),
    // by the hospital when filing a request (issue_photos), and during a
    // pre-work walkthrough (before_photos, future). All store fully-qualified
    // public URLs from the repair-photos bucket.
    @SerialName("issue_photos") val issuePhotos: List<String>? = null,
    @SerialName("before_photos") val beforePhotos: List<String>? = null,
    @SerialName("after_photos") val afterPhotos: List<String>? = null,
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
    @SerialName("site_location") val siteLocation: String? = null,
    @SerialName("site_latitude") val siteLatitude: Double? = null,
    @SerialName("site_longitude") val siteLongitude: Double? = null,
    @SerialName("started_at") val startedAt: String? = null,
    @SerialName("completed_at") val completedAt: String? = null,
    @SerialName("hospital_rating") val hospitalRating: Int? = null,
    @SerialName("hospital_review") val hospitalReview: String? = null,
    @SerialName("engineer_rating") val engineerRating: Int? = null,
    @SerialName("engineer_review") val engineerReview: String? = null,
    @SerialName("created_at") val createdAt: String? = null,
    @SerialName("updated_at") val updatedAt: String? = null,
)

/**
 * Sparse-update payload for status transitions + timestamps. We only send the
 * columns that are actually changing so we don't race other writers over fields
 * we don't own.
 */
@Serializable
internal data class RepairJobStatusPatchDto(
    val status: String,
    @SerialName("started_at") val startedAt: String? = null,
    @SerialName("completed_at") val completedAt: String? = null,
)

/**
 * Sparse patch that writes exactly one side's rating + review. We rely on the
 * caller picking the correct column pair (hospital_* vs engineer_*) via
 * [RatingRole] — the DTO itself doesn't try to validate that.
 */
@Serializable
internal data class RepairJobRatingPatchDto(
    @SerialName("hospital_rating") val hospitalRating: Int? = null,
    @SerialName("hospital_review") val hospitalReview: String? = null,
    @SerialName("engineer_rating") val engineerRating: Int? = null,
    @SerialName("engineer_review") val engineerReview: String? = null,
)
