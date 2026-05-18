package com.equipseva.app.core.data.engineers

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.Transient
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject

/** Sort mode for [EngineerDirectoryRepository.search]. Mirrors the
 * `p_sort_mode` parameter on `engineers_directory_search`. */
enum class DirectorySortMode(val storageKey: String) {
    Nearest("nearest"),
    Rating("rating"),
    PriceAsc("price_asc"),
}

/**
 * Public-read access to the engineer directory. Backed by two SECURITY
 * DEFINER RPCs in `20260427010000_engineers_directory_rpcs.sql` that
 * filter to verified engineers and join the `profiles` table for the
 * display name + avatar + (in the public profile case) phone number.
 */
@Singleton
class EngineerDirectoryRepository @Inject constructor(
    private val client: SupabaseClient,
) {
    @Serializable
    data class DirectoryRow(
        @SerialName("engineer_id") val engineerId: String,
        @SerialName("user_id") val userId: String? = null,
        @SerialName("full_name") val fullName: String,
        @SerialName("avatar_url") val avatarUrl: String? = null,
        @SerialName("city") val city: String? = null,
        @SerialName("state") val state: String? = null,
        @SerialName("service_areas") val serviceAreas: List<String>? = null,
        @SerialName("specializations") val specializations: List<String>? = null,
        @SerialName("brands_serviced") val brandsServiced: List<String>? = null,
        @SerialName("experience_years") val experienceYears: Int = 0,
        @SerialName("rating_avg") val ratingAvg: Double = 0.0,
        @SerialName("total_jobs") val totalJobs: Int = 0,
        @SerialName("hourly_rate") val hourlyRate: Double? = null,
        @SerialName("bio") val bio: String? = null,
        @SerialName("is_available") val isAvailable: Boolean = false,
        // Server-populated when caller passes lat/lng to search(). Null
        // when caller didn't pass coords or engineer has no base coords.
        @SerialName("distance_km") val distanceKm: Double? = null,
        @Transient val completionPctOverride: Int? = null,
    )

    @Serializable
    data class EngineerReview(
        @SerialName("rating") val rating: Int,
        @SerialName("review") val review: String,
        @SerialName("completed_at") val completedAtIso: String? = null,
        // Hospital identity is NEVER returned — only city. The
        // engineer_recent_reviews RPC drops user_id and org name on
        // purpose so reviews stay anonymized when shown to other
        // hospitals browsing the directory.
        @SerialName("hospital_city") val hospitalCity: String? = null,
        // PR-B: equipment_category added to engineer_recent_reviews
        // return shape so review cards can render the category chip.
        // Default null keeps forward compat if the column is absent
        // (older RPC version → silently hides the chip).
        @SerialName("equipment_category") val equipmentCategory: String? = null,
    )

    /**
     * Row from `recommended_engineers_for_hospital`. Same shape as
     * [DirectoryRow] plus a server-side relevance score in 0..100.
     * Used to back the hospital-home carousel + the repeat-booking
     * nudge alternatives. Sort is already match_score DESC server-side.
     */
    @Serializable
    data class RecommendedRow(
        @SerialName("engineer_id") val engineerId: String,
        @SerialName("user_id") val userId: String? = null,
        @SerialName("full_name") val fullName: String,
        @SerialName("avatar_url") val avatarUrl: String? = null,
        @SerialName("city") val city: String? = null,
        @SerialName("state") val state: String? = null,
        @SerialName("service_areas") val serviceAreas: List<String>? = null,
        @SerialName("specializations") val specializations: List<String>? = null,
        @SerialName("brands_serviced") val brandsServiced: List<String>? = null,
        @SerialName("experience_years") val experienceYears: Int = 0,
        @SerialName("rating_avg") val ratingAvg: Double = 0.0,
        @SerialName("total_jobs") val totalJobs: Int = 0,
        @SerialName("hourly_rate") val hourlyRate: Double? = null,
        @SerialName("bio") val bio: String? = null,
        @SerialName("is_available") val isAvailable: Boolean = false,
        @SerialName("distance_km") val distanceKm: Double? = null,
        @SerialName("match_score") val matchScore: Double = 0.0,
    )

    /**
     * Per-category review aggregate for an engineer profile. Source:
     * `engineer_review_summary_by_category(p_engineer_id)`. One row per
     * `equipment_category` with non-zero reviews. Drives the pills
     * row above the Reviews section ("Patient Monitoring · 5 · 4.9★").
     */
    @Serializable
    data class CategoryReviewSummary(
        @SerialName("equipment_category") val equipmentCategory: String,
        @SerialName("review_count") val reviewCount: Int = 0,
        @SerialName("rating_avg") val ratingAvg: Double = 0.0,
    )

    @Serializable
    data class PublicProfile(
        @SerialName("engineer_id") val engineerId: String,
        @SerialName("user_id") val userId: String? = null,
        @SerialName("full_name") val fullName: String,
        @SerialName("avatar_url") val avatarUrl: String? = null,
        @SerialName("phone") val phone: String? = null,
        @SerialName("email") val email: String? = null,
        @SerialName("city") val city: String? = null,
        @SerialName("state") val state: String? = null,
        @SerialName("service_areas") val serviceAreas: List<String>? = null,
        @SerialName("specializations") val specializations: List<String>? = null,
        @SerialName("brands_serviced") val brandsServiced: List<String>? = null,
        @SerialName("oem_training_badges") val oemTrainingBadges: List<String>? = null,
        @SerialName("experience_years") val experienceYears: Int = 0,
        @SerialName("rating_avg") val ratingAvg: Double = 0.0,
        @SerialName("total_jobs") val totalJobs: Int = 0,
        @SerialName("completion_rate") val completionRate: Double = 0.0,
        @SerialName("hourly_rate") val hourlyRate: Double? = null,
        @SerialName("bio") val bio: String? = null,
        @SerialName("is_available") val isAvailable: Boolean = false,
        @SerialName("base_latitude") val baseLatitude: Double? = null,
        @SerialName("base_longitude") val baseLongitude: Double? = null,
        @SerialName("service_radius_km") val serviceRadiusKm: Int? = null,
    )

    suspend fun search(
        query: String? = null,
        district: String? = null,
        specialization: String? = null,
        brand: String? = null,
        limit: Int = 50,
        offset: Int = 0,
        hospitalLat: Double? = null,
        hospitalLng: Double? = null,
        sortMode: DirectorySortMode = DirectorySortMode.Rating,
        minRating: Double? = null,
    ): Result<List<DirectoryRow>> = runCatching {
        client.postgrest.rpc(
            function = "engineers_directory_search",
            parameters = buildJsonObject {
                put("p_query", query?.let { JsonPrimitive(it) } ?: JsonNull)
                put("p_district", district?.let { JsonPrimitive(it) } ?: JsonNull)
                put("p_specialization", specialization?.let { JsonPrimitive(it) } ?: JsonNull)
                put("p_brand", brand?.let { JsonPrimitive(it) } ?: JsonNull)
                put("p_limit", JsonPrimitive(limit))
                put("p_offset", JsonPrimitive(offset))
                put("p_hospital_lat", hospitalLat?.let { JsonPrimitive(it) } ?: JsonNull)
                put("p_hospital_lng", hospitalLng?.let { JsonPrimitive(it) } ?: JsonNull)
                put("p_sort_mode", JsonPrimitive(sortMode.storageKey))
                put("p_min_rating", minRating?.let { JsonPrimitive(it) } ?: JsonNull)
            },
        ).decodeList<DirectoryRow>()
    }

    suspend fun fetchPublicProfile(engineerId: String): Result<PublicProfile?> = runCatching {
        client.postgrest.rpc(
            function = "engineer_public_profile",
            parameters = buildJsonObject {
                put("p_engineer_id", JsonPrimitive(engineerId))
            },
        ).decodeList<PublicProfile>().firstOrNull()
    }

    /**
     * Number of completed repair_jobs (any kind) the caller-hospital has
     * had with this engineer's engineers.id. Drives the repeat-booking
     * nudge gate on EngineerPublicProfileScreen — count >= 3 AND
     * distance >= 50 km surfaces "try a local engineer" alternatives.
     * Backed by `count_completed_jobs_with_engineer` SECDEF RPC.
     */
    suspend fun countCompletedJobsWithEngineer(
        engineerId: String,
    ): Result<Int> = runCatching {
        val raw = client.postgrest.rpc(
            function = "count_completed_jobs_with_engineer",
            parameters = buildJsonObject {
                put("p_engineer_id", JsonPrimitive(engineerId))
            },
        ).data
        raw.trim().trim('"').toIntOrNull() ?: 0
    }

    /**
     * Latest non-empty hospital reviews for this engineer. Caps server-side
     * at 50; the [limit] argument is clamped on the SQL side too. Returns
     * empty list if the engineer has no rated-with-text completed jobs.
     */
    suspend fun fetchRecentReviews(
        engineerId: String,
        limit: Int = 10,
    ): Result<List<EngineerReview>> = runCatching {
        client.postgrest.rpc(
            function = "engineer_recent_reviews",
            parameters = buildJsonObject {
                put("p_engineer_id", JsonPrimitive(engineerId))
                put("p_limit", JsonPrimitive(limit))
            },
        ).decodeList<EngineerReview>()
    }

    /**
     * PR-B: top-N recommended engineers for a hospital, ranked by
     * server-side match_score (proximity + specialization overlap +
     * rating). [equipmentCategory] is optional — when provided, the
     * server biases the score toward engineers who have completed
     * jobs in that category. Used by the hospital-home carousel.
     */
    suspend fun recommendedEngineers(
        hospitalLat: Double,
        hospitalLng: Double,
        equipmentCategory: String? = null,
        limit: Int = 5,
    ): Result<List<RecommendedRow>> = runCatching {
        client.postgrest.rpc(
            function = "recommended_engineers_for_hospital",
            parameters = buildJsonObject {
                put("p_hospital_lat", JsonPrimitive(hospitalLat))
                put("p_hospital_lng", JsonPrimitive(hospitalLng))
                put(
                    "p_equipment_category",
                    equipmentCategory?.let { JsonPrimitive(it) } ?: JsonNull,
                )
                put("p_limit", JsonPrimitive(limit))
            },
        ).decodeList<RecommendedRow>()
    }

    /**
     * PR-B: per-category review aggregates for the engineer profile.
     * Returns one row per `equipment_category` the engineer has been
     * rated on. Caller renders these as pills above the Reviews
     * section so a hospital can scan trust by category at a glance.
     */
    suspend fun fetchReviewSummaryByCategory(
        engineerId: String,
    ): Result<List<CategoryReviewSummary>> = runCatching {
        client.postgrest.rpc(
            function = "engineer_review_summary_by_category",
            parameters = buildJsonObject {
                put("p_engineer_id", JsonPrimitive(engineerId))
            },
        ).decodeList<CategoryReviewSummary>()
    }
}
