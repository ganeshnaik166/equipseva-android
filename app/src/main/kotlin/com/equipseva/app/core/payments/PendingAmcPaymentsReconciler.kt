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
        val pending = runCatching { store.list() }.getOrNull().orEmpty()
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
            when (result.getOrNull()) {
                "paid", "refunded", "failed", null -> {
                    runCatching { store.remove(id) }
                }
                else -> Unit
            }
        }
    }
}
