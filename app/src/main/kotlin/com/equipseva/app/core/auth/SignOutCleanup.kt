package com.equipseva.app.core.auth

import android.content.Context
import androidx.core.app.NotificationManagerCompat
import com.equipseva.app.core.data.moderation.UserBlockRepository
import com.equipseva.app.core.sync.OutboxSignOutCleaner
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
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive
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
 * The token pair is captured with the first-operation exact login ticket,
 * before draft disk I/O; its remote revoke remains last. Draft, AMC and Room
 * outbox deletion check that ticket at their own storage mutation boundaries.
 * Other local wipes, producers/readers, historical global records and final
 * SDK logout remain separate ownership work. This bounded sequence does not
 * establish whole-app account isolation. See the S1 boundary plan at
 * docs/helper-reviews/codex-20260919/signout-ownership-plan.md.
 *
 * Each step is best-effort: sign-out must never block on a flaky DELETE.
 * Unlike the old `runCatching`, [bestEffort] rethrows [CancellationException]
 * so a cancelled caller can actually stop the sequence. Call BEFORE the
 * network signOut so the FCM token-revoke DELETE still has a valid session.
 */
@Singleton
class SignOutCleanup @Inject constructor(
    private val deviceTokenRegistrar: DeviceTokenRegistrar,
    private val outboxSignOutCleaner: OutboxSignOutCleaner,
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
    private val localSessionOwnership: LocalSessionOwnership,
    @ApplicationContext private val context: Context,
) {
    suspend fun wipeLocalUserState() {
        currentCoroutineContext().ensureActive()
        val departingTicket = localSessionOwnership.capture()
        // Retire only this login's draft lease synchronously, before the first
        // token/database suspension. A stale A cannot fence B's live form.
        val draftFence = bestEffort {
            requestServiceDraftStore.fenceForSignOut(departingTicket, localSessionOwnership)
        }
        // The DAO read may suspend: revalidate the exact ticket after it before
        // publishing a (user, token) pair. Never derive the owner from live B.
        val revocation = bestEffort { deviceTokenRegistrar.captureRevocation(departingTicket) }
        // Disk clear checks the same ticket inside DataStore's admitted edit.
        bestEffort { requestServiceDraftStore.clearFencedForSignOut(draftFence) }

        // ---- local wipes: nothing below suspends on the network ----
        bestEffort { deepLinkRouter.clear() }
        bestEffort { NotificationManagerCompat.from(context).cancelAll() }
        bestEffort { outboxSignOutCleaner.clearForSignOut(departingTicket) }
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
        bestEffort { pendingAmcPaymentsStore.clearForSignOut(departingTicket) }
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
    private suspend inline fun <T> bestEffort(block: () -> T): T? {
        currentCoroutineContext().ensureActive()
        return try {
            val result = block()
            currentCoroutineContext().ensureActive()
            result
        } catch (ce: CancellationException) {
            throw ce
        } catch (_: Throwable) {
            // A noncooperative dependency may throw an ordinary error after
            // the caller was cancelled. Never treat that as permission to
            // continue with the next device-wide cleanup step.
            currentCoroutineContext().ensureActive()
            null
        }
    }
}
