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
import com.equipseva.app.core.push.NotificationChannels
import dagger.assisted.Assisted
import dagger.assisted.AssistedInject

/**
 * Drains the offline outbox by dispatching each pending entry to a registered
 * [OutboxKindHandler]. The worker never holds business logic itself — features
 * contribute handlers via [OutboxHandlersModule].
 *
 * Retry policy:
 * - [OutboxKindHandler.Outcome.Success] → drop the entry.
 * - [OutboxKindHandler.Outcome.Retry] → bump attempts; after [MAX_ATTEMPTS] the
 *   entry is treated as poison and deleted (with a breadcrumb log).
 * - [OutboxKindHandler.Outcome.GiveUp] → delete immediately; the handler has
 *   decided the payload is permanently unusable (e.g. 403 from RLS).
 * - Unknown `kind` (no handler registered) → delete with a warning so a stale
 *   queued entry from an older build can't livelock the flush.
 *
 * The worker itself never fails the WorkRequest — WorkManager retries are
 * driven by the scheduler (periodic with network constraints), not by the
 * per-entry failures above.
 */
@HiltWorker
class OutboxWorker @AssistedInject constructor(
    @Assisted private val appContext: Context,
    @Assisted params: WorkerParameters,
    private val outbox: OutboxDao,
    private val handlers: Map<String, @JvmSuppressWildcards OutboxKindHandler>,
) : CoroutineWorker(appContext, params) {

    override suspend fun doWork(): Result {
        val pending = outbox.nextBatch()
        if (pending.isEmpty()) return Result.success()

        for (entry in pending) {
            val handler = handlers[entry.kind]
            if (handler == null) {
                Log.w(TAG, "No handler for kind=${entry.kind} (id=${entry.id}); dropping.")
                outbox.delete(entry.id)
                continue
            }
            val outcome = runCatching { handler.handle(entry) }
                .getOrElse { OutboxKindHandler.Outcome.Retry(it) }
            when (outcome) {
                is OutboxKindHandler.Outcome.Success -> outbox.delete(entry.id)
                is OutboxKindHandler.Outcome.GiveUp -> {
                    Log.w(TAG, "Giving up on ${entry.kind}#${entry.id}: ${outcome.reason}")
                    outbox.delete(entry.id)
                }
                is OutboxKindHandler.Outcome.Retry -> {
                    val nextAttempts = entry.attempts + 1
                    if (nextAttempts >= MAX_ATTEMPTS) {
                        Log.w(
                            TAG,
                            "Poison ${entry.kind}#${entry.id} after $nextAttempts attempts; dropping.",
                            outcome.reason,
                        )
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
                        outbox.markFailed(entry.id, outcome.reason.message ?: outcome.reason::class.simpleName.orEmpty())
                    }
                }
            }
        }
        return Result.success()
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
        val (title, body) = when (kind) {
            OutboxKinds.CHAT_MESSAGE -> "Couldn't send a chat message" to
                "We tried several times but couldn't deliver it. Open the conversation to retype."
            OutboxKinds.PHOTO_UPLOAD -> "Couldn't upload a photo" to
                "Tap the job to re-attach the photo when you have a stronger network."
            OutboxKinds.REPAIR_BID -> "Couldn't place your bid" to
                "Open the job to retry your bid — the previous attempt was discarded."
            OutboxKinds.JOB_STATUS -> "Couldn't sync a job status update" to
                "Open the job and re-tap the status button when you're online."
            else -> "Couldn't sync a queued action" to
                "Some offline action was discarded after repeated failures."
        }
        val notif = NotificationCompat.Builder(appContext, NotificationChannels.ACCOUNT)
            .setSmallIcon(R.mipmap.ic_launcher)
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
        const val MAX_ATTEMPTS = 5
        private const val TAG = "OutboxWorker"
        private const val POISON_NOTIF_BASE_ID = 0x0BA0
    }
}
