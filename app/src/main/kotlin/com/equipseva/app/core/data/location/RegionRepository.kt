package com.equipseva.app.core.data.location

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import javax.inject.Inject
import javax.inject.Singleton
import kotlin.coroutines.cancellation.CancellationException
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject

/**
 * Server side of the region catalogue (round3830 RPCs). Every write sends codes plus the
 * catalogue version they were chosen from; the server validates the pair and the version and
 * keeps the legacy label columns (`profiles.state/district`, `engineers.service_areas`) in sync.
 */
interface RegionRepository {
    suspend fun catalogStatus(): Result<RegionCatalogStatus>
    suspend fun setMyHomeRegion(stateCode: String, districtCode: String, catalogVersion: String): Result<HomeRegionSaved>
    suspend fun setMyServiceDistricts(districtCodes: List<String>, catalogVersion: String): Result<ServiceDistrictsSaved>
    suspend fun myRegionProfile(): Result<MyRegionProfile>
}

@Serializable
data class RegionCatalogStatus(
    @SerialName("current_version") val currentVersion: String? = null,
    @SerialName("supported_versions") val supportedVersions: List<String> = emptyList(),
    @SerialName("is_synthetic") val isSynthetic: Boolean = false,
    @SerialName("state_count") val stateCount: Int = 0,
    @SerialName("district_count") val districtCount: Int = 0,
) {
    /** Whether the server accepts new selections made from catalogue [version]. */
    fun acceptsWritesFrom(version: String): Boolean = version in supportedVersions
}

@Serializable
data class HomeRegionSaved(
    @SerialName("state_code") val stateCode: String,
    @SerialName("state_name") val stateName: String,
    @SerialName("district_code") val districtCode: String,
    @SerialName("district_name") val districtName: String,
    @SerialName("catalog_version") val catalogVersion: String,
    val status: String,
)

@Serializable
data class ServiceDistrictsSaved(
    @SerialName("catalog_version") val catalogVersion: String,
    @SerialName("district_codes") val districtCodes: List<String>,
    val count: Int,
)

@Serializable
data class MyRegionProfile(
    val home: HomeRegion? = null,
    @SerialName("home_stale") val homeStale: Boolean = false,
    @SerialName("legacy_state_label") val legacyStateLabel: String? = null,
    @SerialName("legacy_district_label") val legacyDistrictLabel: String? = null,
    @SerialName("legacy_preview") val legacyPreview: LegacyPreview? = null,
    @SerialName("is_engineer") val isEngineer: Boolean = false,
    @SerialName("service_districts") val serviceDistricts: List<ServiceDistrict> = emptyList(),
    /** `engineer` (chosen in the app), `legacy_backfill` (derived from old text) or `none`. */
    @SerialName("service_source") val serviceSource: String = "none",
    /** An engineer-chosen set whose service-area text was later edited by an older app version. */
    @SerialName("service_stale") val serviceStale: Boolean = false,
    @SerialName("current_catalog_version") val currentCatalogVersion: String? = null,
) {
    @Serializable
    data class HomeRegion(
        @SerialName("state_code") val stateCode: String? = null,
        @SerialName("district_code") val districtCode: String? = null,
        @SerialName("catalog_version") val catalogVersion: String,
        /** `resolved` or `needs_confirmation`. */
        val status: String,
        /** `user` or `legacy_backfill`. */
        val source: String,
        @SerialName("legacy_state_label") val legacyStateLabel: String? = null,
        @SerialName("legacy_district_label") val legacyDistrictLabel: String? = null,
    ) {
        val isResolved: Boolean get() = status == "resolved" && stateCode != null && districtCode != null
    }

    /** Exact-only resolution of the current label text; present when it has no or a stale coded row. */
    @Serializable
    data class LegacyPreview(
        /** `resolved`, `needs_confirmation` or `empty`. */
        val status: String,
        @SerialName("state_code") val stateCode: String? = null,
        @SerialName("district_code") val districtCode: String? = null,
        /** `state_unknown`, `no_match` or `ambiguous` when not resolved. */
        val reason: String? = null,
        @SerialName("candidate_codes") val candidateCodes: List<String> = emptyList(),
        @SerialName("catalog_version") val catalogVersion: String? = null,
    )

    @Serializable
    data class ServiceDistrict(
        @SerialName("district_code") val districtCode: String,
        @SerialName("catalog_version") val catalogVersion: String,
        val source: String,
    )
}

/** Refusals the region RPCs raise (SQL `RAISE EXCEPTION '<code>'`), recognised in error text. */
enum class RegionWriteError(val raiseCode: String) {
    CatalogVersionUnsupported("region_catalog_version_unsupported"),
    CodeUnknown("region_code_unknown"),
    PairInvalid("region_pair_invalid"),
    DistrictRetired("region_district_retired"),
    ServiceDistrictsEmpty("region_service_districts_empty"),
    ServiceDistrictsTooMany("region_service_districts_too_many"),
    ServiceDistrictsDuplicate("region_service_districts_duplicate"),
    NotAnEngineer("not_an_engineer"),
    NotAuthenticated("not_authenticated"),
    ProfileNotFound("profile_not_found"),
    ;

    companion object {
        /** The refusal carried by [error] or any of its causes, or null for other failures. */
        fun from(error: Throwable?): RegionWriteError? {
            val messages = generateSequence(error) { it.cause }.take(8).mapNotNull { it.message }.toList()
            return entries.firstOrNull { e -> messages.any { m -> CODE_TOKEN.findAll(m).any { it.value == e.raiseCode } } }
        }

        private val CODE_TOKEN = Regex("[a-z_]+")
    }
}

@Singleton
class SupabaseRegionRepository @Inject constructor(
    private val supabase: SupabaseClient,
) : RegionRepository {

    override suspend fun catalogStatus(): Result<RegionCatalogStatus> = call {
        supabase.postgrest.rpc(function = "region_catalog_current")
            .decodeList<RegionCatalogStatus>().single()
    }

    override suspend fun setMyHomeRegion(
        stateCode: String,
        districtCode: String,
        catalogVersion: String,
    ): Result<HomeRegionSaved> = call {
        supabase.postgrest.rpc(
            function = "set_my_home_region",
            parameters = buildJsonObject {
                put("p_state_code", JsonPrimitive(stateCode))
                put("p_district_code", JsonPrimitive(districtCode))
                put("p_catalog_version", JsonPrimitive(catalogVersion))
            },
        ).decodeAs<HomeRegionSaved>()
    }

    override suspend fun setMyServiceDistricts(
        districtCodes: List<String>,
        catalogVersion: String,
    ): Result<ServiceDistrictsSaved> = call {
        supabase.postgrest.rpc(
            function = "set_my_service_districts",
            parameters = buildJsonObject {
                put("p_district_codes", JsonArray(districtCodes.map(::JsonPrimitive)))
                put("p_catalog_version", JsonPrimitive(catalogVersion))
            },
        ).decodeAs<ServiceDistrictsSaved>()
    }

    override suspend fun myRegionProfile(): Result<MyRegionProfile> = call {
        supabase.postgrest.rpc(function = "my_region_profile").decodeAs<MyRegionProfile>()
    }

    /** Like runCatching, but a cancelled caller stays cancelled instead of becoming a failure. */
    private inline fun <T> call(block: () -> T): Result<T> = try {
        Result.success(block())
    } catch (e: CancellationException) {
        throw e
    } catch (e: Exception) {
        Result.failure(e)
    }
}
