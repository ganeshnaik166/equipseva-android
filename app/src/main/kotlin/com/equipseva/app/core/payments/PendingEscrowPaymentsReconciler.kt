package com.equipseva.app.core.payments

import com.equipseva.app.core.data.escrow.RepairJobEscrowRepository
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.coroutines.CancellationException

/**
 * Round 280 — sweep stale entries from [PendingEscrowPaymentsStore] after
 * a process-death + cold-start cycle.
 *
 * Each entry is a repair_job_id whose Razorpay escrow checkout activity
 * didn't return cleanly. We query the canonical server-side status via
 * the existing get_repair_job_escrow RPC and bucket the response:
 *
 *   - status='held' / 'released' / 'refunded' / 'in_dispute' → terminal
 *     or post-pending, the verify-payment edge function did fire (or
 *     the escrow has progressed past the in-flight state). Remove the
 *     marker — no client action needed.
 *   - status='pending'         → keep the marker. The hospital paid via
 *     Razorpay but the verify call never completed (process death). They
 *     need to retry from the job detail screen; we leave the marker so
 *     the home UI can surface the in-flight pill.
 *   - row missing (RLS denied, escrow row never created, etc.) → remove
 *     the marker; we can't act on what we can't see.
 *
 * Failures are silently ignored — the marker lingers until the next
 * cold-start retries the reconciliation.
 */
@Singleton
class PendingEscrowPaymentsReconciler @Inject constructor(
    private val store: PendingEscrowPaymentsStore,
    private val escrowRepository: RepairJobEscrowRepository,
) {

    suspend fun reconcile() {
        // Round 433 — explicit try/catch so CancellationException re-throws.
        // runCatching catches all Throwables including CancellationException,
        // which would silently absorb scope teardown (Worker stop, etc.).
        val pending = try {
            store.list()
        } catch (ce: CancellationException) {
            throw ce
        } catch (_: Throwable) {
            emptyList()
        }
        if (pending.isEmpty()) return
        for (repairJobId in pending) {
            // Round 294 — distinguish "row is gone" (Result.success(null))
            // from "fetch failed" (Result.failure). The original
            // double-getOrNull collapsed both to null and removed the
            // marker, silently dropping an in-flight payment on a
            // transient network blip. Network failure → leave the marker.
            val result = escrowRepository.fetchByJob(repairJobId)
            if (result.isFailure) continue
            if (shouldClearEscrowMarker(result.getOrNull()?.status)) {
                try {
                    store.remove(repairJobId)
                } catch (ce: CancellationException) {
                    throw ce
                } catch (_: Throwable) {
                    // Best-effort; lingering marker is recovered on next cold-start.
                }
            }
        }
    }
}

/**
 * True when the reconciler should clear the in-flight escrow marker
 * for a repair job, based on the server-side `status` returned by
 * get_repair_job_escrow.
 *
 *   * "held", "released", "refunded", "in_dispute" — terminal or
 *     post-pending, the verify-payment edge function fired. Clear.
 *   * null (row missing — RLS denied, escrow never created) — clear,
 *     we can't act on what we can't see.
 *   * "pending" — keep the marker. The hospital paid but the verify
 *     call never completed (process death); they need to retry.
 *   * Unknown status — keep, defense against a future status the
 *     reconciler doesn't recognise (forward-compat for v2).
 *
 * Pinned semantics so a future relax that auto-cleared "pending"
 * would surface in review.
 */
internal fun shouldClearEscrowMarker(status: String?): Boolean = when (status) {
    "held", "released", "refunded", "in_dispute", null -> true
    else -> false  // "pending" + any unknown future status — keep the marker
}
