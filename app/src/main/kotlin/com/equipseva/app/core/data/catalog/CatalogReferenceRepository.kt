package com.equipseva.app.core.data.catalog

import com.equipseva.app.core.data.openfda.OpenFdaApi
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.query.Order
import java.net.URLEncoder
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
    private val openFda: OpenFdaApi,
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
        @SerialName("image_url") val imageUrl: String? = null,
        @SerialName("image_url_confidence") val imageUrlConfidence: Double? = null,
        val notes: String? = null,
    )

    suspend fun search(
        query: String? = null,
        category: String? = null,
        type: String? = null,
        limit: Int = 50,
        offset: Int = 0,
    ): Result<List<Item>> = runCatching {
        client.from(TABLE).select {
            filter {
                category?.takeIf { it.isNotBlank() }?.let { eq("category", it) }
                type?.takeIf { it.isNotBlank() }?.let { eq("type", it) }
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

    /**
     * Long-tail fallback for catalogue search. When the local Supabase table
     * returns few hits for a user's query, the ViewModel can fire this to
     * pull supplementary results live from FDA's free OpenFDA Device-UDI API
     * (~5M devices, daily-refreshed). No auth needed, 1k req/day per IP.
     *
     * Returned [Item]s carry `source = "openfda"` and a synthetic negative
     * id derived from the OpenFDA record-key hash, so they can never collide
     * with real Supabase rows. They have no INR price (FDA doesn't track
     * prices) and `market = "Global"`.
     */
    suspend fun searchOpenFda(query: String, limit: Int = 25): Result<List<Item>> = runCatching {
        val q = query.trim()
        if (q.isBlank()) return@runCatching emptyList()
        // OpenFDA full-text searches across the typed fields with `+OR+`. We
        // also wrap the query in quotes so multi-word brand/model strings
        // stay together rather than being split into ANDs.
        val safe = q.replace("\"", " ").replace("+", " ").trim()
        val searchExpr = listOf(
            "brand_name:\"$safe\"",
            "device_description:\"$safe\"",
            "company_name:\"$safe\"",
            "version_or_model_number:\"$safe\"",
        ).joinToString("+OR+")
        val resp = openFda.searchUdi(search = searchExpr, limit = limit, skip = 0)
        resp.results.mapNotNull { mapOpenFdaToItem(it) }
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

    /** Top 4 types by row count — covers >99% of the catalog. */
    fun types(): List<String> = listOf(
        "Capital Equipment",
        "Implant",
        "Consumable",
        "Spare/Accessory",
    )

    /**
     * Map a raw [com.equipseva.app.core.data.openfda.UdiResult] to our
     * [Item] shape so the UI doesn't need to know there are two backends.
     * Returns null when the FDA row lacks the minimum text we need to
     * render a card.
     */
    private fun mapOpenFdaToItem(
        r: com.equipseva.app.core.data.openfda.UdiResult,
    ): Item? {
        val name = r.brandName?.takeIf { it.isNotBlank() }
            ?: r.deviceDescription?.take(80)?.takeIf { it.isNotBlank() }
            ?: return null
        val brand = r.companyName
        val model = r.versionOrModelNumber ?: r.catalogNumber
        val udi = r.identifiers.firstOrNull()?.id ?: r.recordKey
        // Map gmdn term → category bucket. Coarse keyword rules; coverage
        // is a best-effort, leans into "Spare Parts & Consumables" when
        // we can't classify (matches the bulk-import fallback).
        val gmdnName = r.gmdnTerms.firstOrNull()?.name.orEmpty().lowercase()
        val category = when {
            "imag" in gmdnName || "ultrasound" in gmdnName ||
                "x-ray" in gmdnName || "ct scan" in gmdnName ||
                "mri" in gmdnName || "tomograph" in gmdnName -> "Imaging"
            "ventilat" in gmdnName || "monitor" in gmdnName ||
                "defibril" in gmdnName || "infusion" in gmdnName ||
                "icu" in gmdnName || "anaesth" in gmdnName ||
                "anesth" in gmdnName || "respirat" in gmdnName -> "ICU & Critical Care"
            "surg" in gmdnName || "scalpel" in gmdnName ||
                "endoscop" in gmdnName || "laparosc" in gmdnName -> "Surgical & OR"
            "lab" in gmdnName || "analy" in gmdnName ||
                "hematolog" in gmdnName || "centrifuge" in gmdnName -> "Laboratory"
            "ward" in gmdnName || "bed" in gmdnName ||
                "wheelchair" in gmdnName || "stetho" in gmdnName ||
                "thermometer" in gmdnName -> "Ward & Allied"
            else -> "Spare Parts & Consumables"
        }
        // Type bucket from is_rx / is_otc flags; everything else into the
        // catch-all "Consumable" so the chip filters still apply.
        val type = when {
            r.isRx == true -> "Capital Equipment"
            r.isOtc == true -> "Consumable"
            else -> "Consumable"
        }
        // Synthetic negative id so OpenFDA rows can't collide with real
        // Supabase ids (which are positive).
        val syntheticId = -1 * (udi?.hashCode()?.takeIf { it > 0 } ?: name.hashCode().let { if (it > 0) it else -it })
        // Build a Google Images URL on the fly so the existing "Open
        // Images" button still works.
        val q = listOfNotNull(brand, model, name).joinToString(" ").take(180)
        val imageSearchUrl =
            "https://www.google.com/search?tbm=isch&q=" + URLEncoder.encode(q, "UTF-8")
        return Item(
            id = syntheticId,
            source = "openfda",
            udi = udi,
            category = category,
            subCategory = r.gmdnTerms.firstOrNull()?.name,
            itemName = name,
            brand = brand,
            model = model,
            type = type,
            keySpecifications = r.deviceDescription,
            priceInrLow = null,
            priceInrHigh = null,
            market = "Global",
            imageSearchUrl = imageSearchUrl,
            imageUrl = null,
            imageUrlConfidence = null,
            notes = listOfNotNull(
                r.mriSafety?.let { "MRI: $it" },
                r.devicePublishDate?.let { "Pub $it" },
            ).joinToString(" · ").takeIf { it.isNotBlank() },
        )
    }

    private companion object {
        const val TABLE = "catalog_reference_items"
    }
}
