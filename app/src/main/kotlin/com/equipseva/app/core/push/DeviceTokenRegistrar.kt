package com.equipseva.app.core.push

import com.equipseva.app.core.data.dao.DeviceTokenDao
import com.equipseva.app.core.data.entities.DeviceTokenEntity
import com.google.firebase.messaging.FirebaseMessaging
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.auth.auth
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class DeviceTokenRegistrar @Inject constructor(
    private val dao: DeviceTokenDao,
    private val supabase: SupabaseClient,
) {

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

        if (supabase.auth.currentUserOrNull()?.id == null) return
        runCatching {
            // SECURITY DEFINER RPC (migration 20260506110000) handles both
            // "strip prior claim from another user" and "bind to me" atomically.
            // The previous client-side delete + upsert pair started failing
            // silently after migration 20260428320000 revoked DELETE on
            // device_tokens for the authenticated role; the RPC restores the
            // shared-device behaviour without re-opening that grant.
            supabase.postgrest.rpc(
                function = "register_device_token",
                parameters = buildJsonObject {
                    put("p_token", JsonPrimitive(token))
                    put("p_platform", JsonPrimitive("android"))
                },
            )
        }
    }

    /**
     * Sign-out cleanup. Drops the server-side device_tokens row so the
     * outgoing user stops receiving FCM messages on this device, and
     * wipes the local cached token so the next sign-in re-registers
     * cleanly. Must be called BEFORE [SupabaseAuthRepository.signOut]
     * so the RPC still has a valid auth session; runCatching on the
     * network call so a flaky connection doesn't block sign-out.
     */
    suspend fun revoke() {
        val cachedToken = runCatching { dao.current()?.token }.getOrNull()
        if (supabase.auth.currentUserOrNull()?.id != null && !cachedToken.isNullOrBlank()) {
            runCatching {
                supabase.postgrest.rpc(
                    function = "revoke_device_token",
                    parameters = buildJsonObject {
                        put("p_token", JsonPrimitive(cachedToken))
                    },
                )
            }
        }
        runCatching { dao.clear() }
    }
}
