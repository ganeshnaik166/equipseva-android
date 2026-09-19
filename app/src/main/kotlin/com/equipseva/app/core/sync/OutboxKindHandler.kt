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

    /**
     * Last call before the worker deletes an entry the handler never got to
     * decide on itself (the poison drop). Handlers that own local resources —
     * the stashed photo / KYC bytes, say — release them here: the drop is
     * terminal, so a handler that frees only on its own success path leaves
     * those bytes on disk forever. Default no-op, because most kinds own
     * nothing beyond the payload string.
     */
    suspend fun onDropped(entry: OutboxEntryEntity) {}

    sealed interface Outcome {
        data object Success : Outcome

        /**
         * [countsAgainstBudget] = false marks a precondition the queued payload
         * cannot influence — no restored auth session yet at WorkManager cold
         * start being the one that matters. Charging attempts for those turned
         * the budget into a timer on the process lifecycle: a handful of ticks
         * emptied the queue of a user who was signed in and online and told
         * them their writes had been discarded, although nothing was ever sent.
         */
        data class Retry(val reason: Throwable, val countsAgainstBudget: Boolean = true) : Outcome

        data class GiveUp(val reason: String) : Outcome
    }
}
