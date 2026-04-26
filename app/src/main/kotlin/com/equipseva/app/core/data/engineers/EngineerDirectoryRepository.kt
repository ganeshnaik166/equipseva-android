package com.equipseva.app.core.data.engineers

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject

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
    )

    @Serializable
    data class PublicProfile(
        @SerialName("engineer_id") val engineerId: String,
        @SerialName("user_id") val userId: String? = null,
        @SerialName("full_name") val fullName: String,
        @SerialName("avatar_url") val avatarUrl: String? = null,
        @SerialName("phone") val phone: String? = null,
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
    )

    suspend fun search(
        query: String? = null,
        district: String? = null,
        specialization: String? = null,
        brand: String? = null,
        limit: Int = 50,
        offset: Int = 0,
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
}
