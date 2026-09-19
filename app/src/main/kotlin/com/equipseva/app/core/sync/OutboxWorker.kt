package com.equipseva.app.core.sync

import android.Manifest
import android.app.NotificationManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import androidx.core.content.getSystemService
import androidx.hilt.work.HiltWorker
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.equipseva.app.R
import com.equipseva.app.core.data.dao.OutboxDao
import com.equipseva.app.core.data.entities.OutboxEntryEntity
import com.equipseva.app.core.push.NotificationChannels
import dagger.assisted.Assisted
import dagger.assisted.AssistedInject
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.withTimeoutOrNull

/**
 * Drains the offline outbox by dispatching each pending entry to a registered
 * [OutboxKindHandler]. The worker never holds business logic itself — features
 * contribute handlers via [OutboxHandlersModule].
 *
 * Retry policy:
 * - [OutboxKindHandler.Outcome.Success] → drop the entry.
 * - [OutboxKindHandler.Outcome.Retry] → bump attempts; an entry is only
 *   treated as poison once it is both out of attempts and old enough that no
 *   plausible outage explains the failures (see [outboxEntryIsPoison]), at
 *   which point it is deleted with a user-visible breadcrumb.
 * - [OutboxKindHandler.Outcome.GiveUp] → delete immediately; the handler has
 *   decided the payload is permanently unusable (e.g. 403 from RLS).
 * - Unknown `kind` (no handler registered) → delete with a warning so a stale
 *   queued entry from an older build can't livelock the flush.
 *
 * A run always reports success, even when it leaves entries queued. Re-attempts
 * come from the periodic tick and from the next [OutboxEnqueuer.enqueue], never
 * from WorkManager's backoff, and that is deliberate: the one-shot request is
 * enqueued with `APPEND_OR_REPLACE`, so reporting `retry` parks the chain head
 * in ENQUEUED, and a dependent only runs once every prerequisite has
 * SUCCEEDED. One entry that keeps deferring would hold a brand-new chat message
 * BLOCKED behind it on a perfectly good network, for as long as the head's
 * exponential backoff — which doubles toward WorkManager's five-hour ceiling.
 * Making the backoff live is not worth trading a bounded wait for an unbounded
 * one.
 */
@HiltWorker
class OutboxWorker @AssistedInject constructor(
    @Assisted private val appContext: Context,
    @Assisted params: WorkerParameters,
    private val outbox: OutboxDao,
    private val handlers: Map<String, @JvmSuppressWildcards OutboxKindHandler>,
    private val supabase: SupabaseClient,
    private val drainLock: OutboxDrainLock,
) : CoroutineWorker(appContext, params) {

    override suspend fun doWork(): Result = drainLock.withDrain { drain() }

    private suspend fun drain(): Result {
        val pending = outbox.nextBatch()
        if (pending.isEmpty()) return Result.success()

        // WorkManager cold-starts the process for the periodic tick, and
        // supabase-kt restores the persisted session asynchronously: a
        // Keystore-backed read plus a token refresh whenever the access token
        // expired while the app was idle. A drain that starts inside that
        // window sees no user at all, so every handler reports the same
        // precondition failure — which used to cost every queued row one of
        // its attempts for a state the user never caused. Wait for the session
        // to settle, and if there still isn't one, leave the queue untouched.
        val signedIn = withTimeoutOrNull(AUTH_READY_TIMEOUT_MS) {
            supabase.auth.awaitInitialization()
            supabase.auth.currentUserOrNull() != null
        } == true
        if (!signedIn) {
            Log.i(TAG, "No restored session; deferring ${pending.size} entries without charging attempts.")
            return Result.success()
        }

        val now = System.currentTimeMillis()
        for (entry in pending) {
            val handler = handlers[entry.kind]
            if (handler == null) {
                Log.w(TAG, "No handler for kind=${entry.kind} (id=${entry.id}); dropping.")
                outbox.delete(entry.id)
                continue
            }
            // Round 435 — runCatching catches CancellationException too,
            // which would absorb WorkManager's stop()/cancel signal and
            // keep the drain loop spinning until natural completion. The
            // explicit re-throw lets the worker stop cleanly while still
            // demoting genuine handler failures to a Retry outcome.
            val outcome = try {
                handler.handle(entry)
            } catch (ce: CancellationException) {
                throw ce
            } catch (e: Throwable) {
                OutboxKindHandler.Outcome.Retry(e)
            }
            when (outcome) {
                is OutboxKindHandler.Outcome.Success -> outbox.delete(entry.id)
                is OutboxKindHandler.Outcome.GiveUp -> {
                    Log.w(TAG, "Giving up on ${entry.kind}#${entry.id}: ${outcome.reason}")
                    outbox.delete(entry.id)
                }
                is OutboxKindHandler.Outcome.Retry -> {
                    if (!outcome.countsAgainstBudget) {
                        Log.i(
                            TAG,
                            "Deferring ${entry.kind}#${entry.id} on a precondition; attempts unchanged.",
                        )
                    } else {
                        val nextAttempts = entry.attempts + 1
                        if (outboxEntryIsPoison(nextAttempts, now - entry.createdAt)) {
                            Log.w(
                                TAG,
                                "Poison ${entry.kind}#${entry.id} after $nextAttempts attempts; dropping.",
                                outcome.reason,
                            )
                            releaseLocalResources(handler, entry)
                            // Surface the drop to the user. Without this the
                            // message / bid / status update they queued offline
                            // would silently vanish — they'd open the app days
                            // later and assume it sent. Posts to the existing
                            // ACCOUNT channel so it inherits the user's mute
                            // settings rather than spamming the chat / jobs
                            // channels with a sync alert.
                            notifyPoisonDrop(entry.kind)
                            outbox.delete(entry.id)
                        } else {
                            outbox.markFailed(
                                entry.id,
                                outcome.reason.message ?: outcome.reason::class.simpleName.orEmpty(),
                            )
                        }
                    }
                }
            }
        }
        return Result.success()
    }

    /**
     * Give the handler its one chance to free whatever the payload points at
     * (a stashed photo / KYC file) before the row that names it is deleted and
     * the reference is gone for good. A handler that fails here must not abort
     * the rest of the batch, but a cancellation still has to reach the worker.
     */
    private suspend fun releaseLocalResources(handler: OutboxKindHandler, entry: OutboxEntryEntity) {
        try {
            handler.onDropped(entry)
        } catch (ce: CancellationException) {
            throw ce
        } catch (t: Throwable) {
            Log.w(TAG, "Cleanup failed for dropped ${entry.kind}#${entry.id}", t)
        }
    }

    private fun notifyPoisonDrop(kind: String) {
        // POST_NOTIFICATIONS is a runtime permission on Android 13+
        // (TIRAMISU). Without the grant, the post is silently dropped
        // (best case) or throws SecurityException on some OEMs. The
        // poison-drop alert is purely informational — if the user
        // denied the perm, the queue's GiveUp already handled the
        // failure; we just can't tell them about it.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(appContext, Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            return
        }
        val nm = appContext.getSystemService<NotificationManager>() ?: return
        val (title, body) = poisonDropCopy(kind)
        val notif = NotificationCompat.Builder(appContext, NotificationChannels.ACCOUNT)
            // Round 450 — see EquipSevaMessagingService for rationale.
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)
            .build()
        runCatching { nm.notify(POISON_NOTIF_BASE_ID + kind.hashCode(), notif) }
            .onFailure { Log.w(TAG, "Failed to display poison-drop notification for kind=$kind", it) }
    }

    companion object {
        const val UNIQUE_NAME = "outbox-flush"
        private const val TAG = "OutboxWorker"
        private const val POISON_NOTIF_BASE_ID = 0x0BA0

        // Long enough to cover a Keystore read plus one token refresh on a
        // slow link, short enough that the worker still finishes well inside
        // WorkManager's 10-minute execution budget with a batch to drain.
        private const val AUTH_READY_TIMEOUT_MS = 20_000L
    }
}

/** Attempts a queued entry must have burned before it can be called poison. */
internal const val OUTBOX_POISON_ATTEMPT_FLOOR = 20

/** How long a queued entry must have existed before it can be called poison. */
internal const val OUTBOX_POISON_MIN_AGE_MS = 24L * 60 * 60 * 1000

/**
 * Poison test for a queued write, on attempts AND age together.
 *
 * Attempts alone made the budget a wall-clock timer: with a 15-minute tick and
 * a 5-attempt cap, roughly 75 minutes of *any* transient failure — a PostgREST
 * schema-cache reload, a Supabase incident, an unrefreshed token — permanently
 * deleted the user's queued bid, status change or message and notified them it
 * had been discarded. Permanent failures already leave by the GiveUp route, so
 * this path exists only for writes that keep failing transiently; requiring a
 * day in the queue as well means an outage can't masquerade as poison.
 */
internal fun outboxEntryIsPoison(attempts: Int, ageMs: Long): Boolean =
    attempts >= OUTBOX_POISON_ATTEMPT_FLOOR && ageMs >= OUTBOX_POISON_MIN_AGE_MS

/**
 * Per-kind user-facing copy for the poison-drop notification that
 * fires once [outboxEntryIsPoison] holds. The user needs an actionable
 * hint pointing at the surface where they can retry (conversation /
 * job detail / etc.). A generic fallback covers any future kind.
 *
 * Extracted from [OutboxWorker.notifyPoisonDrop] so the per-kind
 * copy can be unit-tested without standing up the worker.
 */
internal fun poisonDropCopy(kind: String): Pair<String, String> = when (kind) {
    OutboxKinds.CHAT_MESSAGE -> "Couldn't send a chat message" to
        "We tried several times but couldn't deliver it. Open the conversation to retype."
    OutboxKinds.PHOTO_UPLOAD -> "Couldn't upload a photo" to
        "Tap the job to re-attach the photo when you have a stronger network."
    OutboxKinds.REPAIR_BID -> "Couldn't place your bid" to
        "Open the job to retry your bid — the previous attempt was discarded."
    OutboxKinds.JOB_STATUS -> "Couldn't sync a job status update" to
        "Open the job and re-tap the status button when you're online."
    // round3820 — the photo itself DID upload; only its evidence-ledger
    // registration kept failing. Say so, or the user re-attaches a photo
    // that is already on the job.
    OutboxKinds.EVIDENCE_REGISTER -> "Couldn't certify a photo as evidence" to
        "The photo is on the job, but its tamper-proof record could not be filed. Open the job and re-attach it to retry."
    else -> "Couldn't sync a queued action" to
        "Some offline action was discarded after repeated failures."
}
