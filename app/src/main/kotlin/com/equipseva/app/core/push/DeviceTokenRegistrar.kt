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

    /**
     * Sign-out cleanup. Drops the server-side device_tokens row so the
     * outgoing user stops receiving FCM messages on this device, and
     * wipes the local cached token so the next sign-in re-registers
     * cleanly. Must be called BEFORE [SupabaseAuthRepository.signOut]
     * so the DELETE still has a valid auth session; runCatching on the
     * network call so a flaky connection doesn't block sign-out.
     */
    suspend fun revoke() {
        val userId = supabase.auth.currentUserOrNull()?.id
        val cachedToken = runCatching { dao.current()?.token }.getOrNull()
        if (userId != null && !cachedToken.isNullOrBlank()) {
            runCatching {
                supabase.from("device_tokens")
                    .delete {
                        filter {
                            eq("user_id", userId)
                            eq("token", cachedToken)
                        }
                    }
            }
        }
        runCatching { dao.clear() }
    }
}
