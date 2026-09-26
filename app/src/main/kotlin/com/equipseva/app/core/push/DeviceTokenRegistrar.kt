package com.equipseva.app.core.push

import com.equipseva.app.core.auth.LocalSessionOwnership
import com.equipseva.app.core.data.dao.DeviceTokenDao
import com.equipseva.app.core.data.entities.DeviceTokenEntity
import com.google.firebase.messaging.FirebaseMessaging
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.auth.auth
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive
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
    private val ownership: LocalSessionOwnership,
) {

    @Serializable
    private data class DeviceTokenRow(
        val user_id: String,
        val platform: String,
        val token: String,
    )

    /**
     * The (user, token) pair a sign-out must revoke — captured at the moment the
     * sign-out STARTS, while the departing user is still the signed-in one
     * (A4-02). Passing this into [revoke] instead of re-reading live auth means a
     * revoke that stalls on the network until the NEXT user has signed in and
     * registered the same FCM token can only ever delete the departing user's
     * row, never the new user's.
     */
    data class Revocation(val userId: String, val token: String)

    /**
     * Re-register the current FCM token under the signed-in user's id.
     * Called on every sign-in transition because [onNewToken] only fires on
     * actual FCM token rotation — a returning user signing in on the same
     * device would otherwise have no server device_tokens row (revoke() on the
     * previous sign-out removed it) and therefore receive no pushes. Best-
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
            // Shared-device hardening: when user A signs out and B signs in,
            // A's revoke() may have failed silently (network glitch). Strip
            // any other user's claim on this same FCM token before binding
            // it to the current user — otherwise pushes meant for A would
            // continue routing to B's physical device until the token
            // rotates. This DELETE is owner-gated by RLS so it can only
            // remove rows that belong to the caller (B); rows owned by A
            // are deferred to the server-side dedupe in send_push.
            // P1d blocker: migration 20260428320000 revokes authenticated
            // table DELETE, so this can fail before the upsert below. Replace
            // both operations with a narrow versioned server claim contract;
            // restoring broad client DELETE would reopen a security hazard.
            supabase.from("device_tokens").delete {
                filter { eq("token", token) }
            }
            // Defense-in-depth: re-verify auth.uid hasn't shifted between
            // the delete and the upsert. RLS would already block a mismatched
            // INSERT, but failing fast here avoids surfacing a Postgrest
            // 42501 to the caller when the real cause is a mid-flight account
            // switch.
            val current = supabase.auth.currentUserOrNull()?.id
            if (current != userId) return@runCatching
            supabase.from("device_tokens").upsert(
                DeviceTokenRow(user_id = userId, platform = "android", token = token),
            )
        }
    }

    /**
     * Sign-out snapshot bound to the first-operation login ticket. The cached
     * installation token read may suspend; a replacement account or login
     * invalidates the ticket before any revocation pair is published.
     */
    suspend fun captureRevocation(ticket: LocalSessionOwnership.Ticket?): Revocation? {
        currentCoroutineContext().ensureActive()
        val departing = ticket ?: return null
        if (!ownership.withCurrent(departing) {}) {
            currentCoroutineContext().ensureActive()
            return null
        }
        val cachedToken = try {
            dao.current()?.token
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (_: Exception) {
            currentCoroutineContext().ensureActive()
            return null
        }
        currentCoroutineContext().ensureActive()
        if (!ownership.withCurrent(departing) {}) {
            currentCoroutineContext().ensureActive()
            return null
        }
        if (cachedToken.isNullOrBlank()) return null
        return Revocation(departing.identity.ownerId, cachedToken)
    }

    /**
     * Convenience snapshot for immediate capture/revoke callers. Sign-out uses
     * the ticketed overload above; this no-argument path has no cross-login
     * ownership guarantee if a caller suspends between capture and revoke.
     */
    suspend fun captureRevocation(): Revocation? {
        currentCoroutineContext().ensureActive()
        val userId = supabase.auth.currentUserOrNull()?.id ?: return null
        val cachedToken = try {
            dao.current()?.token
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (_: Exception) {
            currentCoroutineContext().ensureActive()
            return null
        }
        currentCoroutineContext().ensureActive()
        if (cachedToken.isNullOrBlank()) return null
        return Revocation(userId, cachedToken)
    }

    /**
     * Sign-out cleanup attempts a server-side device_tokens delete for the
     * CAPTURED user + token. Retains the installation-scoped local token: it
     * contains no user identity; Firebase still owns it, and sign-in refresh
     * needs it for registration. Clearing it after a slow
     * DELETE would erase the next login's cache and prevent its later revoke.
     * Never reads live auth: by the time a slow DELETE runs, the next
     * user may already be signed in and own this same token. Must be called
     * BEFORE [SupabaseAuthRepository.signOut] so the DELETE still has a valid
     * auth session; a flaky connection does not block sign-out, but caller
     * cancellation must still propagate.
     *
     * Repository migration 20260428320000 revokes authenticated DELETE on
     * device_tokens. Until a separate, versioned server release/claim contract
     * replaces this request, a correct local capture does not prove that the
     * remote row was removed. Do not re-grant broad client table DELETE.
     */
    suspend fun revoke(capture: Revocation?) {
        currentCoroutineContext().ensureActive()
        if (capture != null) {
            try {
                supabase.from("device_tokens")
                    .delete {
                        filter {
                            eq("user_id", capture.userId)
                            eq("token", capture.token)
                        }
                    }
                currentCoroutineContext().ensureActive()
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (_: Exception) {
                // Sign-out is best effort if the remote delete fails.
                currentCoroutineContext().ensureActive()
            }
        }
    }

    /** Convenience for callers that capture and revoke in one step (no other work in between). */
    suspend fun revoke() = revoke(captureRevocation())
}
