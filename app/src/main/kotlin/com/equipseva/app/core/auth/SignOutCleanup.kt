package com.equipseva.app.core.auth

import com.equipseva.app.core.data.moderation.UserBlockRepository
import com.equipseva.app.core.data.dao.OutboxDao
import com.equipseva.app.core.data.prefs.UserPrefs
import com.equipseva.app.core.push.DeviceTokenRegistrar
import com.equipseva.app.core.sync.OutboxScheduler
import com.equipseva.app.core.sync.handlers.PhotoUploadStash
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.realtime.realtime
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Wipes per-user device-resident state during sign-out. Pulled out of
 * ProfileViewModel.onSignOut so the same cleanup runs when
 * SessionViewModel detects a zombie session (server-deleted account, or
 * legacy soft-delete with is_active=false). Without this, the zombie
 * path called authRepository.signOut() directly and the previous user's
 * outbox / FCM token / DataStore prefs survived into the next user's
 * sign-in on the same device.
 *
 * Each step is best-effort and runCatching-wrapped: sign-out must never
 * block on a flaky DELETE. Call BEFORE the network signOut so the FCM
 * token-revoke DELETE still has a valid session.
 */
@Singleton
class SignOutCleanup @Inject constructor(
    private val deviceTokenRegistrar: DeviceTokenRegistrar,
    private val outboxDao: OutboxDao,
    private val outboxScheduler: OutboxScheduler,
    private val photoUploadStash: PhotoUploadStash,
    private val userPrefs: UserPrefs,
    private val userBlockRepository: UserBlockRepository,
    private val supabaseClient: SupabaseClient,
) {
    suspend fun wipeLocalUserState() {
        runCatching { deviceTokenRegistrar.revoke() }
        runCatching { outboxDao.clearAll() }
        runCatching { outboxScheduler.cancelAll() }
        runCatching { photoUploadStash.clearAll() }
        runCatching { userPrefs.setLastScreen(null) }
        runCatching { userPrefs.clearActiveRole() }
        // v2 onboarding cache is per-user device state. Without a reset
        // the next account inherits the previous user's "already
        // onboarded" sticky flag and skips the mandatory gate.
        runCatching { userPrefs.setV2OnboardingComplete(false) }
        // Notification prefs are device-resident user state. Without
        // a reset the next account inherits the previous user's mute
        // categories + quiet-hours window, silently swallowing pushes
        // the new user explicitly enabled.
        runCatching { userPrefs.setMutedPushCategories(emptySet()) }
        runCatching { userPrefs.setQuietHoursEnabled(false) }
        // @Singleton UserBlockRepository holds the previous user's
        // blocked-id set in memory; clear so the next sign-in
        // doesn't see stale blocks until the first refresh().
        runCatching { userBlockRepository.clearCache() }
        // Realtime channels live on the singleton supabase client.
        // Disconnect drops the websocket so any chat / notification /
        // cost-revision subscription tied to the previous user is
        // torn down — without this the next user's first subscribe
        // could collide with the previous one's awaitClose cleanup
        // mid-flight (RLS still gates emissions, but processing
        // phantom events wastes battery + can briefly leak counts).
        runCatching {
            val rt = supabaseClient.realtime
            rt.subscriptions.values.toList().forEach { ch ->
                rt.removeChannel(ch)
            }
        }
    }
}
