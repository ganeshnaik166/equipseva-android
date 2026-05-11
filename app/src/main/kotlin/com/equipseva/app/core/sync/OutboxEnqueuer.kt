package com.equipseva.app.core.sync

import androidx.work.BackoffPolicy
import androidx.work.Constraints
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import com.equipseva.app.core.data.dao.OutboxDao
import com.equipseva.app.core.data.entities.OutboxEntryEntity
import java.util.concurrent.TimeUnit
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Thin injection seam for features that need to queue a write for later retry.
 * Hides the [OutboxDao] + [WorkManager] wiring so each feature just produces a
 * kind + JSON payload and calls [enqueue]. The enqueuer immediately kicks a
 * one-shot flush so a transient network hiccup recovers in seconds, not at the
 * next 15-minute periodic tick.
 */
@Singleton
class OutboxEnqueuer @Inject constructor(
    private val outboxDao: OutboxDao,
    private val workManager: WorkManager,
) {
    suspend fun enqueue(kind: String, payloadJson: String) {
        outboxDao.enqueue(
            OutboxEntryEntity(
                kind = kind,
                payload = payloadJson,
                createdAt = System.currentTimeMillis(),
            ),
        )
        // Network-required + exponential backoff: without these, queueing
        // five messages while offline immediately ran the worker five times,
        // each attempt failed instantly, and the per-entry attempts counter
        // hit MAX_ATTEMPTS in seconds — entries got poison-dropped before
        // the user even reconnected. With CONNECTED + EXPONENTIAL, WorkManager
        // defers the run until the device is online and spaces out failed
        // retries so transient 5xx errors don't burn the attempts budget.
        val request = OneTimeWorkRequestBuilder<OutboxWorker>()
            .setConstraints(
                Constraints.Builder()
                    .setRequiredNetworkType(NetworkType.CONNECTED)
                    .build(),
            )
            .setBackoffCriteria(
                BackoffPolicy.EXPONENTIAL,
                BACKOFF_INITIAL_SECONDS,
                TimeUnit.SECONDS,
            )
            .build()
        workManager.enqueueUniqueWork(
            OutboxWorker.UNIQUE_NAME + "-oneshot",
            ExistingWorkPolicy.REPLACE,
            request,
        )
    }

    private companion object {
        // Exponential-backoff floor for outbox retries. WorkManager doubles
        // this each failure, capped by its own ceiling (~5h). Lower than
        // this and a flaky 5xx burns the daily quota in minutes.
        const val BACKOFF_INITIAL_SECONDS: Long = 30L
    }
}
