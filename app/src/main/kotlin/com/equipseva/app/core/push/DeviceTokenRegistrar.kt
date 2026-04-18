package com.equipseva.app.core.push

import com.equipseva.app.core.data.dao.DeviceTokenDao
import com.equipseva.app.core.data.entities.DeviceTokenEntity
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.auth.auth
import kotlinx.serialization.Serializable
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class DeviceTokenRegistrar @Inject constructor(
    private val dao: DeviceTokenDao,
    private val supabase: SupabaseClient,
) {

    @Serializable
    private data class DeviceTokenRow(
        val user_id: String,
        val platform: String,
        val token: String,
    )

    suspend fun register(token: String) {
        val now = System.currentTimeMillis()
        dao.upsert(DeviceTokenEntity(token = token, registeredAt = now))

        val userId = supabase.auth.currentUserOrNull()?.id ?: return
        runCatching {
            supabase.from("device_tokens").upsert(
                DeviceTokenRow(user_id = userId, platform = "android", token = token),
            )
        }
    }
}
