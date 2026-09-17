package com.equipseva.app.core.auth

import android.content.Context
import androidx.core.app.NotificationManagerCompat
import com.equipseva.app.core.data.moderation.UserBlockRepository
import com.equipseva.app.core.data.dao.OutboxDao
import com.equipseva.app.core.data.prefs.UserPrefs
import com.equipseva.app.core.data.repair.RequestServiceDraftStore
import com.equipseva.app.core.payments.PendingAmcContractsStore
import com.equipseva.app.core.payments.PendingAmcPaymentsStore
import com.equipseva.app.core.payments.PendingEscrowPaymentsStore
import com.equipseva.app.core.push.DeviceTokenRegistrar
import com.equipseva.app.core.sync.OutboxScheduler
import com.equipseva.app.core.sync.handlers.PhotoUploadStash
import com.equipseva.app.navigation.DeepLinkRouter
import dagger.hilt.android.qualifiers.ApplicationContext
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.realtime.realtime
import kotlinx.coroutines.CancellationException
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
 * Ordering contract (A4-01 / A4-02):
 *  1. Capture the departing identity (user id + cached FCM token) BEFORE
 *     anything can suspend on the network.
 *  2. Run every LOCAL wipe — draft fence, deep-link queue, tray, outbox,
 *     scheduler, photo stash, prefs, caches, pending-payment markers,
 *     realtime channels. These finish while the departing user is still
 *     the signed-in one, so they can never land on the next login's data.
 *  3. Only then the single NETWORK step: revoke the CAPTURED device-token
 *     row. Previously the revoke ran second and could stall for the HTTP
 *     timeout while B signed in; the global wipes that followed then
 *     deleted B's queued outbox rows, photo stash and pending-payment
 *     markers, and the revoke itself read the live user and deleted B's
 *     device_tokens row.
 *
 * Each step is best-effort: sign-out must never block on a flaky DELETE.
 * Unlike the old `runCatching`, [bestEffort] rethrows [CancellationException]
 * so a cancelled caller can actually stop the sequence. Call BEFORE the
 * network signOut so the FCM token-revoke DELETE still has a valid session.
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
    // Round 460: pending-payment DataStores also hold per-user device
    // state (Razorpay order ids the previous user opened and hasn't
    // verified). Without a reset the next user on the same device
    // sees ghost "Pending payment" banners for orders that belong to
    // an account they never owned.
    private val pendingEscrowPaymentsStore: PendingEscrowPaymentsStore,
    private val pendingAmcPaymentsStore: PendingAmcPaymentsStore,
    // Round 477: contract-level pending markers are wiped on sign-out so
    // the next user doesn't see a previous user's stranded AMC contract
    // appear as a "complete payment" banner on Home.
    private val pendingAmcContractsStore: PendingAmcContractsStore,
    private val requestServiceDraftStore: RequestServiceDraftStore,
    // A3-02: buffered deep links and posted tray notifications belong to
    // the departing user; a tap on A's stale tray entry must not navigate
    // inside B's session.
    private val deepLinkRouter: DeepLinkRouter,
    @ApplicationContext private val context: Context,
) {
    suspend fun wipeLocalUserState() {
        // Revoke draft leases before slow FCM/network cleanup. Even if the disk
        // clear fails, an old form cannot restore or repopulate a later session.
        bestEffort { requestServiceDraftStore.fenceAndClearForSignOut() }
        // Snapshot WHO is signing out while they still are the current user.
        val revocation = bestEffort { deviceTokenRegistrar.captureRevocation() }

        // ---- local wipes: nothing below suspends on the network ----
        bestEffort { deepLinkRouter.clear() }
        bestEffort { NotificationManagerCompat.from(context).cancelAll() }
        bestEffort { outboxDao.clearAll() }
        bestEffort { outboxScheduler.cancelAll() }
        bestEffort { photoUploadStash.clearAll() }
        bestEffort { userPrefs.setLastScreen(null) }
        bestEffort { userPrefs.clearActiveRole() }
        // v2 onboarding cache is per-user device state. Without a reset
        // the next account inherits the previous user's "already
        // onboarded" sticky flag and skips the mandatory gate.
        bestEffort { userPrefs.setV2OnboardingComplete(false) }
        // Notification prefs are device-resident user state. Without
        // a reset the next account inherits the previous user's mute
        // categories + quiet-hours window, silently swallowing pushes
        // the new user explicitly enabled.
        bestEffort { userPrefs.setMutedPushCategories(emptySet()) }
        bestEffort { userPrefs.setQuietHoursEnabled(false) }
        // @Singleton UserBlockRepository holds the previous user's
        // blocked-id set in memory; clear so the next sign-in
        // doesn't see stale blocks until the first refresh().
        bestEffort { userBlockRepository.clearCache() }
        // Round 460: drop pending-payment DataStore entries so the
        // next user on this device doesn't see ghost "Pending payment"
        // banners for the previous user's Razorpay orders.
        bestEffort { pendingEscrowPaymentsStore.clearAll() }
        bestEffort { pendingAmcPaymentsStore.clearAll() }
        bestEffort { pendingAmcContractsStore.clearAll() }
        // Realtime channels live on the singleton supabase client.
        // Disconnect drops the websocket so any chat / notification /
        // cost-revision subscription tied to the previous user is
        // torn down — without this the next user's first subscribe
        // could collide with the previous one's awaitClose cleanup
        // mid-flight (RLS still gates emissions, but processing
        // phantom events wastes battery + can briefly leak counts).
        bestEffort {
            val rt = supabaseClient.realtime
            rt.subscriptions.values.toList().forEach { ch ->
                rt.removeChannel(ch)
            }
        }

        // ---- the one network step, last, against the captured identity ----
        bestEffort { deviceTokenRegistrar.revoke(revocation) }
    }

    /**
     * `runCatching` minus its worst property: it swallows [CancellationException],
     * so a cancelled sign-out kept marching through every global wipe. This
     * rethrows cancellation and swallows everything else.
     */
    private inline fun <T> bestEffort(block: () -> T): T? = try {
        block()
    } catch (ce: CancellationException) {
        throw ce
    } catch (_: Throwable) {
        null
    }
}
