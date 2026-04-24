package com.equipseva.app.core.sync

import com.equipseva.app.core.data.entities.OutboxEntryEntity

/**
 * Per-kind dispatcher for a pending outbox entry. Implementations decode the
 * JSON payload themselves, perform the network write, and report back.
 *
 * Return [Outcome.Success] to drop the entry, [Outcome.Retry] to leave it in
 * the queue for a future flush, and [Outcome.GiveUp] to abandon a permanently
 * malformed / forbidden entry (RLS denial, bad schema, etc.) without burning
 * further attempts.
 */
interface OutboxKindHandler {
    suspend fun handle(entry: OutboxEntryEntity): Outcome

    sealed interface Outcome {
        data object Success : Outcome
        data class Retry(val reason: Throwable) : Outcome
        data class GiveUp(val reason: String) : Outcome
    }
}
