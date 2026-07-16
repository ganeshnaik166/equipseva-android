package com.equipseva.app.core.data.catalog

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
 * Read-only equipment reference catalog (round r486 catalog seed):
 * catalog_devices_search(query, category, brand, limit, offset) + the
 * catalog_brands_list() filter source. Both are public reference data
 * (granted to authenticated + anon). Powers the equipment-catalog browse
 * screen.
 */
@Singleton
class CatalogRepository @Inject constructor(
    private val client: SupabaseClient,
) {
    @Serializable
    data class CatalogDevice(
        @SerialName("id") val id: String,
        @SerialName("generic_name") val genericName: String = "",
        @SerialName("brand_name") val brandName: String? = null,
        @SerialName("brand_id") val brandId: String? = null,
        @SerialName("manufacturer") val manufacturer: String? = null,
        @SerialName("category_key") val categoryKey: String? = null,
        @SerialName("image_url") val imageUrl: String? = null,
    )

    @Serializable
    data class CatalogBrand(
        @SerialName("id") val id: String,
        @SerialName("name") val name: String = "",
        @SerialName("slug") val slug: String? = null,
        @SerialName("country") val country: String? = null,
        @SerialName("logo_url") val logoUrl: String? = null,
        @SerialName("manufacturer_count") val manufacturerCount: Int = 0,
    )

    suspend fun search(query: String?, brandId: String?, limit: Int = 50): Result<List<CatalogDevice>> = runCatching {
        client.postgrest.rpc(
            function = "catalog_devices_search",
            parameters = buildJsonObject {
                put("p_query", query?.takeIf { it.isNotBlank() }?.let { JsonPrimitive(it) } ?: JsonNull)
                put("p_category_key", JsonNull)
                put("p_brand_id", brandId?.let { JsonPrimitive(it) } ?: JsonNull)
                put("p_limit", JsonPrimitive(limit))
                put("p_offset", JsonPrimitive(0))
            },
        ).decodeList<CatalogDevice>()
    }

    suspend fun brands(): Result<List<CatalogBrand>> = runCatching {
        client.postgrest
            .rpc(function = "catalog_brands_list")
            .decodeList<CatalogBrand>()
    }
}
