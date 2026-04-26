package com.equipseva.app.core.data.categories

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject

/**
 * Server-managed equipment categories. Public RPC `equipment_categories_for_scope`
 * returns active rows; this repo caches them in-memory per session so the
 * Marketplace + Parts surfaces don't pay a round-trip for every chip render.
 *
 * Scope keys mirror the table CHECK constraint: 'spare_part' | 'repair' | 'both'.
 * Passing null returns every active row across both scopes.
 */
@Singleton
class EquipmentCategoryRepository @Inject constructor(
    private val client: SupabaseClient,
) {
    @Serializable
    data class Category(
        @SerialName("key") val key: String,
        @SerialName("display_name") val displayName: String,
        @SerialName("scope") val scope: String,
        @SerialName("sort_order") val sortOrder: Int = 100,
        @SerialName("image_url") val imageUrl: String? = null,
    )

    private val cache = MutableStateFlow<Map<String, List<Category>>>(emptyMap())
    private val lock = Mutex()

    /** Hot flow of cached categories grouped by scope key (`spare_part`/`repair`/`null` for all). */
    fun observeCache(): StateFlow<Map<String, List<Category>>> = cache.asStateFlow()

    suspend fun fetch(scope: String? = null): Result<List<Category>> = runCatching {
        lock.withLock {
            val key = scope ?: "all"
            cache.value[key]?.let { return@runCatching it }
            val rows: List<Category> = client.postgrest.rpc(
                function = "equipment_categories_for_scope",
                parameters = buildJsonObject {
                    put("p_scope", scope?.let { JsonPrimitive(it) } ?: JsonNull)
                },
            ).decodeList<Category>()
            cache.update { it + (key to rows) }
            rows
        }
    }

    /** Drop cache so next fetch re-reads from server. Call after curator edits. */
    fun invalidate() {
        cache.update { emptyMap() }
    }
}
