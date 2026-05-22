package com.equipseva.app.core.payments

import com.equipseva.app.core.data.amc.AmcRepository
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Round 234 — sweep stale entries from [PendingAmcPaymentsStore] after
 * a process-death + cold-start cycle.
 *
 * Each entry represents an AMC payment order whose Razorpay checkout
 * activity didn't return cleanly (process killed mid-payment). We
 * query the canonical server-side status:
 *
 *   - status='paid' or 'refunded'  → terminal; remove the marker.
 *     Razorpay's webhook (when configured) will have already triggered
 *     verify-amc-payment server-side; the hospital's ledger is in
 *     order, no client action needed.
 *   - status='failed'              → terminal; remove the marker.
 *   - status='pending'             → keep so the home banner / support
 *     prompt can surface it to the user.
 *   - row missing (RLS denied, deleted, etc.) → remove; we can't act
 *     on what we can't see.
 *
 * Failures are silently ignored — the marker just lingers until the
 * next cold-start retries.
 */
@Singleton
class PendingAmcPaymentsReconciler @Inject constructor(
    private val store: PendingAmcPaymentsStore,
    private val amcRepository: AmcRepository,
) {

    suspend fun reconcile() {
        // Round 433 — explicit try/catch so CancellationException re-throws.
        // Sibling to PendingEscrowPaymentsReconciler.
        val pending = try {
            store.list()
        } catch (ce: kotlinx.coroutines.CancellationException) {
            throw ce
        } catch (_: Throwable) {
            emptyList()
        }
        if (pending.isEmpty()) return
        for (id in pending) {
            // Round 294 — distinguish "row is gone" (Result.success(null))
            // from "fetch failed" (Result.failure). The original
            // `.getOrNull()` collapsed both to null and removed the
            // marker, which silently dropped an in-flight payment record
            // on a transient network blip during the cold-start sweep.
            // Network failure → leave the marker for next cold-start.
            val result = amcRepository.fetchAmcPaymentOrderStatus(id)
            if (result.isFailure) continue
            if (shouldClearAmcPaymentMarker(result.getOrNull())) {
                try {
                    store.remove(id)
                } catch (ce: kotlinx.coroutines.CancellationException) {
                    throw ce
                } catch (_: Throwable) {
                    // Best-effort; lingering marker is recovered on next cold-start.
                }
            }
        }
    }
}

/**
 * True when the reconciler should clear the in-flight AMC-payment
 * marker for a payment order, based on the server-side `status`
 * returned by `fetchAmcPaymentOrderStatus`.
 *
 *   * "paid", "refunded" — terminal; verify-amc-payment fired and
 *     the hospital's ledger is in order. Clear.
 *   * "failed" — terminal (Razorpay reported failure). Clear; the
 *     hospital will retry from the AMC detail screen.
 *   * null (row missing — RLS denied / deleted / never created) —
 *     clear; we can't act on what we can't see.
 *   * "pending" — keep the marker so the home banner / support
 *     prompt can surface it to the user.
 *   * Unknown future status — keep (forward-compat).
 *
 * Sibling to [shouldClearEscrowMarker] — same shape but different
 * status vocabulary (AMC payment orders have `failed`; escrow rows
 * don't).
 */
internal fun shouldClearAmcPaymentMarker(status: String?): Boolean = when (status) {
    "paid", "refunded", "failed", null -> true
    else -> false  // "pending" + unknown future status — keep
}
