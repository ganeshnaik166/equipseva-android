package com.equipseva.app.core.data.repair

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.query.Columns
import io.github.jan.supabase.postgrest.query.Order
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import java.time.Instant
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class SupabaseRepairJobRepository @Inject constructor(
    private val client: SupabaseClient,
) : RepairJobRepository {

    @Serializable
    private data class EngineerIdRow(val id: String)

    override suspend fun fetchOpenJobs(
        page: Int,
        pageSize: Int,
        query: String?,
    ): Result<List<RepairJob>> = runCatching {
        val from = (page.coerceAtLeast(0)).toLong() * pageSize
        val to = from + pageSize - 1

        client.from(TABLE).select {
            filter {
                // Engineer feed shows jobs that are still actionable from the outside
                // — i.e. not yet wrapped up or killed. RLS decides which of these
                // rows this engineer is actually allowed to see.
                isIn("status", RepairJobStatus.OpenForEngineers.map { it.storageKey })
                if (!query.isNullOrBlank()) {
                    val needle = query.trim().sanitizeForIlike()
                    or {
                        ilike("issue_description", "%$needle%")
                        ilike("equipment_brand", "%$needle%")
                        ilike("equipment_model", "%$needle%")
                    }
                }
            }
            // Most recent first — the feed is a worklist, not an archive.
            order("created_at", order = Order.DESCENDING)
            range(from, to)
        }.decodeList<RepairJobDto>().map(RepairJobDto::toDomain)
    }

    override suspend fun fetchNearbyJobs(
        radiusKm: Double,
        limit: Int,
    ): Result<List<RepairJobWithDistance>> = runCatching {
        val response = client.postgrest.rpc(
            function = "list_nearby_repair_jobs",
            parameters = buildJsonObject {
                put("p_radius_km", JsonPrimitive(radiusKm))
                put("p_limit", JsonPrimitive(limit))
            },
        )
        response.decodeList<NearbyRepairJobDto>().map { it.toDomainWithDistance() }
    }

    override suspend fun fetchById(jobId: String): Result<RepairJob?> = runCatching {
        // Deep links share the human-readable job code (RPR-NNNNN), so
        // callers that hand off straight from a path segment may pass
        // either a UUID (in-app navigation) or the RPR code (App Link /
        // push payload). Route to the matching column rather than
        // returning null because the literal string doesn't parse as a
        // UUID server-side.
        val isJobCode = JOB_CODE_PATTERN.matches(jobId)
        client.from(TABLE).select {
            filter {
                if (isJobCode) eq("job_number", jobId) else eq("id", jobId)
            }
            limit(count = 1)
        }.decodeList<RepairJobDto>().firstOrNull()?.toDomain()
    }

    override suspend fun fetchAssignedToMe(): Result<List<RepairJob>> = runCatching {
        val userId = requireNotNull(client.auth.currentUserOrNull()?.id) {
            "No authenticated user"
        }
        // repair_jobs.engineer_id FKs to engineers.id (not auth.uid). Resolve the
        // engineer row for this user first; an engineer who hasn't onboarded yet
        // (no row in `engineers`) simply has nothing assigned.
        val engineerId = client.from("engineers")
            .select(columns = Columns.raw("id")) {
                filter { eq("user_id", userId) }
                limit(count = 1)
            }
            .decodeList<EngineerIdRow>().firstOrNull()?.id
            ?: return@runCatching emptyList()
        client.from(TABLE).select {
            filter { eq("engineer_id", engineerId) }
            order("updated_at", order = Order.DESCENDING)
        }.decodeList<RepairJobDto>().map(RepairJobDto::toDomain)
    }

    override suspend fun fetchByIds(jobIds: Collection<String>): Result<List<RepairJob>> = runCatching {
        if (jobIds.isEmpty()) return@runCatching emptyList<RepairJob>()
        client.from(TABLE).select {
            filter { isIn("id", jobIds.toList()) }
        }.decodeList<RepairJobDto>().map(RepairJobDto::toDomain)
    }

    override suspend fun fetchByHospitalUser(hospitalUserId: String): Result<List<RepairJob>> = runCatching {
        client.from(TABLE).select {
            filter { eq("hospital_user_id", hospitalUserId) }
            order("created_at", order = Order.DESCENDING)
        }.decodeList<RepairJobDto>().map(RepairJobDto::toDomain)
    }

    @Serializable
    private data class CheckInWithGeoRow(
        @SerialName("status") val status: String,
        @SerialName("distance_meters") val distanceMeters: Double? = null,
        @SerialName("geofence_passed") val geofencePassed: Boolean = true,
        @SerialName("geofence_skipped") val geofenceSkipped: Boolean = false,
    )

    override suspend fun engineerCheckInWithGeo(
        jobId: String,
        latitude: Double,
        longitude: Double,
    ): Result<CheckInResult> = runCatching {
        val response = client.postgrest.rpc(
            function = "engineer_check_in_with_geo",
            parameters = buildJsonObject {
                put("p_repair_job_id", JsonPrimitive(jobId))
                put("p_lat", JsonPrimitive(latitude))
                put("p_lng", JsonPrimitive(longitude))
            },
        )
        val row = response.decodeList<CheckInWithGeoRow>().firstOrNull()
            ?: error("check-in returned no row")
        CheckInResult(
            distanceMeters = row.distanceMeters,
            geofencePassed = row.geofencePassed,
            geofenceSkipped = row.geofenceSkipped,
        )
    }

    override suspend fun updateStatus(
        jobId: String,
        newStatus: RepairJobStatus,
        startedAt: Instant?,
        completedAt: Instant?,
        cancellationReason: String?,
    ): Result<RepairJob> = runCatching {
        // PR-D45: the in_progress/en_route → completed transitions were
        // removed from the non-admin status-transition allow-list in
        // 20260620100000 because raw PATCH let an engineer mark a job
        // done without going on-site (and start the 48h escrow auto-
        // release timer). Route through the SECDEF complete_repair_job
        // RPC, which verifies caller is the assigned engineer and the
        // row is in a transitional state, then flips status as postgres.
        if (newStatus == RepairJobStatus.Completed) {
            val response = client.postgrest.rpc(
                function = "complete_repair_job",
                parameters = buildJsonObject {
                    put("p_repair_job_id", JsonPrimitive(jobId))
                },
            )
            response.decodeList<RepairJobDto>().firstOrNull()?.toDomain()
                ?: error("complete_repair_job returned no row")
        } else {
            val patch = RepairJobStatusPatchDto(
                status = newStatus.storageKey,
                startedAt = startedAt?.toString(),
                completedAt = completedAt?.toString(),
                // Only cancellation transitions carry a reason; trim +
                // cap to match the DB's 500-char CHECK constraint added
                // in 20260626170000.
                cancellationReason = if (newStatus == RepairJobStatus.Cancelled) {
                    cancellationReason?.trim()?.take(500)?.takeIf { it.isNotBlank() }
                } else {
                    null
                },
            )
            client.from(TABLE).update(patch) {
                filter { eq("id", jobId) }
                select()
            }.decodeSingle<RepairJobDto>().toDomain()
        }
    }

    override suspend fun submitRating(
        jobId: String,
        role: RatingRole,
        stars: Int,
        review: String?,
    ): Result<RepairJob> = runCatching {
        require(stars in 1..5) { "Rating must be 1..5" }
        val uid = requireNotNull(client.auth.currentUserOrNull()?.id) { "not signed in" }
        // Cap review text at 1000 chars before sending. Unbounded text
        // let a pasted blob bloat the engineers directory card's review
        // preview and wedge the layout; 1000 is generous for a real
        // free-form review.
        val trimmedReview = review?.trim()?.take(1000)?.takeIf { it.isNotBlank() }
        val patch = when (role) {
            RatingRole.HospitalRatesEngineer -> RepairJobRatingPatchDto(
                hospitalRating = stars,
                hospitalReview = trimmedReview,
            )
            RatingRole.EngineerRatesHospital -> RepairJobRatingPatchDto(
                engineerRating = stars,
                engineerReview = trimmedReview,
            )
        }
        // repair_jobs.engineer_id FKs to engineers.id (not auth.uid). Resolve the
        // engineer row for this user when the caller claims to be the engineer.
        val engineerRowId = if (role == RatingRole.EngineerRatesHospital) {
            client.from("engineers")
                .select(columns = Columns.raw("id")) {
                    filter { eq("user_id", uid) }
                    limit(count = 1)
                }
                .decodeList<EngineerIdRow>().firstOrNull()?.id
                ?: error("No engineer profile for caller")
        } else null
        // Round 338 — .decodeSingle() raises NoSuchElementException
        // when 0 rows match the UPDATE filter (stale job id, mis-roled
        // caller, job deleted, RLS rejection). Surface a clear error
        // instead of a cryptic NoSuchElementException leaking through.
        client.from(TABLE).update(patch) {
            filter {
                eq("id", jobId)
                // Defense-in-depth: ensure caller is the actual rater for this job. RLS would also reject, but failing here makes a mis-role'd call throw locally.
                when (role) {
                    RatingRole.HospitalRatesEngineer -> eq("hospital_user_id", uid)
                    RatingRole.EngineerRatesHospital -> eq("engineer_id", engineerRowId!!)
                }
            }
            select()
        }.decodeSingleOrNull<RepairJobDto>()?.toDomain()
            ?: error("Repair job not found or no permission to rate")
    }

    override suspend fun create(draft: RepairJobDraft): Result<RepairJob> = runCatching {
        val payload = RepairJobInsertDto(
            hospitalUserId = draft.hospitalUserId,
            hospitalOrgId = draft.hospitalOrgId?.takeIf { it.isNotBlank() },
            equipmentType = draft.equipmentCategory.storageKey,
            equipmentBrand = draft.equipmentBrand?.takeIf { it.isNotBlank() },
            equipmentModel = draft.equipmentModel?.takeIf { it.isNotBlank() },
            equipmentSerial = draft.equipmentSerial?.takeIf { it.isNotBlank() },
            siteLocation = draft.siteLocation?.takeIf { it.isNotBlank() },
            siteLatitude = draft.siteLatitude,
            siteLongitude = draft.siteLongitude,
            urgency = draft.urgency.storageKey.takeIf { it.isNotBlank() },
            issueDescription = draft.issueDescription,
            issuePhotos = draft.issuePhotos.takeIf { it.isNotEmpty() },
            scheduledDate = draft.scheduledDate?.takeIf { it.isNotBlank() },
            scheduledTimeSlot = draft.scheduledTimeSlot?.takeIf { it.isNotBlank() },
            estimatedCost = draft.estimatedCostRupees?.takeIf { it > 0.0 },
        )
        client.from(TABLE).insert(payload) {
            select()
        }.decodeSingle<RepairJobDto>().toDomain()
    }

    private fun String.sanitizeForIlike(): String =
        replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")

    private companion object {
        const val TABLE = "repair_jobs"
        val JOB_CODE_PATTERN = Regex("^RPR-\\d+$")
    }
}
