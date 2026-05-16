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
            // `Result<String?>`: outer success/failure separates network
            // outcome from row presence. Previous code collapsed both
            // via `getOrNull()` and treated network failures as
            // "row missing → drop marker", which silently lost legitimate
            // pending markers on every offline cold start. Now only
            // terminal statuses + explicit row-missing remove; network
            // failures keep the marker for the next cold-start retry.
            amcRepository.fetchAmcPaymentOrderStatus(id).fold(
                onSuccess = { status ->
                    when (status) {
                        "paid", "refunded", "failed", null -> {
                            runCatching { store.remove(id) }
                        }
                        else -> Unit // 'pending' or other non-terminal — keep marker
                    }
                },
                onFailure = {
                    // Network / RLS error — preserve the marker so the
                    // next reconcile attempt can act on canonical state.
                },
            )
        }
    }
}
