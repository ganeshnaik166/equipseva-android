package com.equipseva.app.core.data.userprefs

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.query.Columns
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject

/**
 * Generic per-user (key → JSON value) settings store. Each Profile sub-screen
 * (Bank details, Addresses, Storefront, GST, etc.) reads/writes one key.
 * Forms that later graduate to first-class tables can migrate without
 * disturbing the rest.
 */
@Singleton
class UserSettingsRepository @Inject constructor(
    private val client: SupabaseClient,
) {
    @Serializable
    private data class Row(
        @SerialName("user_id") val userId: String,
        @SerialName("key") val key: String,
        @SerialName("value") val value: JsonObject,
    )

    private val json = Json { ignoreUnknownKeys = true }

    suspend fun get(key: String): Result<JsonObject?> = runCatching {
        val userId = requireNotNull(client.auth.currentUserOrNull()?.id) { "not signed in" }
        client.from("user_profile_settings")
            .select(columns = Columns.list("user_id", "key", "value")) {
                filter {
                    eq("user_id", userId)
                    eq("key", key)
                }
                limit(1)
            }
            .decodeList<Row>()
            .firstOrNull()
            ?.value
    }

    suspend fun put(key: String, value: JsonObject): Result<Unit> = runCatching {
        val userId = requireNotNull(client.auth.currentUserOrNull()?.id) { "not signed in" }
        client.from("user_profile_settings").upsert(
            Row(userId = userId, key = key, value = value),
        )
        Unit
    }
}
