package com.equipseva.app.core.sync

import android.content.Context
import android.util.Log
import androidx.hilt.work.HiltWorker
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.equipseva.app.core.data.dao.OutboxDao
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
    @Assisted appContext: Context,
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
                        outbox.delete(entry.id)
                    } else {
                        outbox.markFailed(entry.id, outcome.reason.message ?: outcome.reason::class.simpleName.orEmpty())
                    }
                }
            }
        }
        return Result.success()
    }

    companion object {
        const val UNIQUE_NAME = "outbox-flush"
        const val MAX_ATTEMPTS = 5
        private const val TAG = "OutboxWorker"
    }
}
