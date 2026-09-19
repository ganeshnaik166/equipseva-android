package com.equipseva.app.core.sync

import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Process-wide "one outbox drain at a time" gate.
 *
 * The 15-minute periodic flush and the one-shot flush [OutboxEnqueuer] kicks
 * are two distinct unique-work names, so WorkManager is free to run them at
 * the same instant — the classic trigger is a reconnect, which satisfies the
 * network constraint of both requests at once. Neither
 * [com.equipseva.app.core.data.dao.OutboxDao] nor the `outbox` table has a
 * claim column, so both runs read the same rows: the same chat message was
 * inserted twice and a single failure was charged two attempts against the
 * entry's budget.
 *
 * A singleton [Mutex] fixes that without a schema change. It is also fair
 * (kotlinx `Mutex` hands the lock out in FIFO order), so the second drain runs
 * immediately after the first instead of being discarded — anything queued
 * while a drain was in flight still leaves in seconds rather than waiting for
 * the next tick.
 *
 * Scope note: this only serialises drains inside one process. It is sufficient
 * because WorkManager runs all of an app's workers in a single process; a
 * claim column would be needed the day the app gains a second process.
 */
@Singleton
class OutboxDrainLock @Inject constructor() {

    private val mutex = Mutex()

    suspend fun <T> withDrain(block: suspend () -> T): T = mutex.withLock { block() }
}
