package com.equipseva.app.core.push

import com.equipseva.app.core.data.dao.DeviceTokenDao
import com.equipseva.app.core.data.entities.DeviceTokenEntity
import com.google.firebase.messaging.FirebaseMessaging
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.auth.auth
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
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

    /**
     * Re-register the current FCM token under the signed-in user's id.
     * Called on every sign-in transition because [onNewToken] only fires on
     * actual FCM token rotation — a returning user signing in on the same
     * device would otherwise have no device_tokens row (revoke() on the
     * previous sign-out cleared it) and therefore receive no pushes. Best-
     * effort: if the token fetch or upsert fails we just log and move on,
     * the next [onNewToken] callback will recover.
     */
    suspend fun refresh() {
        val token = runCatching { fetchCurrentFcmToken() }.getOrNull()
        if (token.isNullOrBlank()) return
        register(token)
    }

    private suspend fun fetchCurrentFcmToken(): String? = suspendCancellableCoroutine { cont ->
        FirebaseMessaging.getInstance().token
            .addOnSuccessListener { token -> if (cont.isActive) cont.resume(token) }
            .addOnFailureListener { ex -> if (cont.isActive) cont.resumeWithException(ex) }
            .addOnCanceledListener { if (cont.isActive) cont.resume(null) }
    }

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
