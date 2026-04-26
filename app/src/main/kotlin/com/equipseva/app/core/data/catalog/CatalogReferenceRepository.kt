package com.equipseva.app.core.data.catalog

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.query.Order
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Read-only access to public.catalog_reference_items — the 548-row India
 * hospital catalogue (536 curated + 12 GUDID). Public-read RLS, no writes
 * from the client. Used by the marketplace browse + RFQ-prefill flow.
 */
@Singleton
class CatalogReferenceRepository @Inject constructor(
    private val client: SupabaseClient,
) {
    @Serializable
    data class Item(
        val id: Int,
        val source: String = "curated",
        val udi: String? = null,
        val category: String,
        @SerialName("sub_category") val subCategory: String? = null,
        @SerialName("item_name") val itemName: String,
        val brand: String? = null,
        val model: String? = null,
        val type: String? = null,
        @SerialName("key_specifications") val keySpecifications: String? = null,
        @SerialName("price_inr_low") val priceInrLow: Long? = null,
        @SerialName("price_inr_high") val priceInrHigh: Long? = null,
        val market: String = "India",
        @SerialName("image_search_url") val imageSearchUrl: String? = null,
        val notes: String? = null,
    )

    suspend fun search(
        query: String? = null,
        category: String? = null,
        limit: Int = 50,
        offset: Int = 0,
    ): Result<List<Item>> = runCatching {
        client.from(TABLE).select {
            filter {
                category?.takeIf { it.isNotBlank() }?.let { eq("category", it) }
                query?.trim()?.takeIf { it.isNotBlank() }?.let { q ->
                    // Plain ilike across the searchable text columns. 548
                    // rows total so the gin tsvector index isn't worth the
                    // tsquery escaping; PostgREST `or` keeps it simple.
                    val safe = q.replace("%", "").replace(",", " ").trim()
                    val pattern = "%$safe%"
                    or {
                        ilike("item_name", pattern)
                        ilike("brand", pattern)
                        ilike("model", pattern)
                        ilike("sub_category", pattern)
                        ilike("key_specifications", pattern)
                    }
                }
            }
            order("category", order = Order.ASCENDING)
            order("id", order = Order.ASCENDING)
            range(offset.toLong(), (offset + limit - 1).toLong())
        }.decodeList<Item>()
    }

    suspend fun fetchById(id: Int): Result<Item?> = runCatching {
        client.from(TABLE).select {
            filter { eq("id", id) }
            limit(1)
        }.decodeList<Item>().firstOrNull()
    }

    /** Hard-coded — this catalogue has exactly these 6 categories. */
    fun categories(): List<String> = listOf(
        "Imaging",
        "ICU & Critical Care",
        "Surgical & OR",
        "Laboratory",
        "Ward & Allied",
        "Spare Parts & Consumables",
    )

    private companion object {
        const val TABLE = "catalog_reference_items"
    }
}
