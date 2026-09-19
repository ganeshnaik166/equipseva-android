package com.equipseva.app.core.payments

import com.equipseva.app.core.data.amc.AmcRepository
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Round 234 — sweep stale entries from [PendingAmcPaymentsStore] after
 * a process-death + cold-start cycle.
 *
 * Each entry represents an AMC payment whose checkout or credit confirmation
 * did not finish. The server marks an order `paid` before crediting its pool,
 * so a status read alone cannot prove that the money reached the ledger:
 *
 *   - `refunded` or `failed` → terminal; remove without replaying proof.
 *   - `pending` or `paid` → replay stored SDK proof through the idempotent
 *     verify endpoint, which can repair a paid order missing its pool credit.
 *     Remove only when that order's successful response names a credit ledger.
 *   - Missing proof, null/unrecognised status, or failed confirmation → keep
 *     recovery material. In particular, an RLS-hidden row is not proof of
 *     completion. The existing support prompt can surface unresolved markers.
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
            currentCoroutineContext().ensureActive()
            val result = amcRepository.fetchAmcPaymentOrderStatus(id)
            // The repository wraps its calls in runCatching, so a cancelled
            // sweep arrives here as a failed Result instead of unwinding the
            // loop; re-throw or the sweep keeps hitting the network after the
            // scope is gone.
            val statusError = result.exceptionOrNull()
            if (isScopeCancellation(statusError)) throw statusError!!
            currentCoroutineContext().ensureActive()
            if (result.isFailure) continue
            val status = result.getOrNull()
            if (shouldClearAmcPaymentMarker(status)) {
                try {
                    store.remove(id)
                } catch (ce: kotlinx.coroutines.CancellationException) {
                    throw ce
                } catch (_: Throwable) {
                    // Best-effort; lingering marker is recovered on next cold-start.
                }
            } else if (shouldReverifyAmcPayment(status)) {
                reverify(id)
            }
        }
    }

    /**
     * SDK success can outlive the client or the server's pool-credit write.
     * The idempotent endpoint handles both pending and paid-without-ledger
     * recovery. Preserve the original proof until it confirms this order's
     * ledger, including when the response is incomplete or the sweep is cancelled.
     */
    private suspend fun reverify(paymentOrderId: String) {
        val payload = try {
            store.verifiable(paymentOrderId)
        } catch (ce: kotlinx.coroutines.CancellationException) {
            throw ce
        } catch (_: Throwable) {
            null
        } ?: return
        currentCoroutineContext().ensureActive()
        val verified = amcRepository.verifyPayment(
            paymentOrderId = payload.paymentOrderId,
            razorpayOrderId = payload.razorpayOrderId,
            razorpayPaymentId = payload.razorpayPaymentId,
            razorpaySignature = payload.razorpaySignature,
        )
        val verifyError = verified.exceptionOrNull()
        if (isScopeCancellation(verifyError)) throw verifyError!!
        currentCoroutineContext().ensureActive()
        val confirmation = verified.getOrNull() ?: return
        if (!confirmation.ok || confirmation.paymentOrderId != paymentOrderId ||
            confirmation.ledgerId.isNullOrBlank()
        ) return
        try {
            store.remove(paymentOrderId)
        } catch (ce: kotlinx.coroutines.CancellationException) {
            throw ce
        } catch (_: Throwable) {
            // Best-effort; a later sweep must confirm the credit again.
        }
    }
}

/**
 * True when a still-unresolved payment order should have its stored Razorpay
 * signature replayed against `verify-amc-payment`.
 *
 * `paid` alone does not prove pool credit: the server writes that status before
 * applying the ledger entry. Both it and `pending` can recover through verify.
 * Refunded/failed orders and unknown states must never replay their signatures.
 */
internal fun shouldReverifyAmcPayment(status: String?): Boolean =
    status == "pending" || status == "paid"

/**
 * True when the reconciler should clear the in-flight AMC-payment
 * marker for a payment order, based on the server-side `status`
 * returned by `fetchAmcPaymentOrderStatus`.
 *
 * Only `refunded` and `failed` prove that credit recovery must stop. `paid`
 * needs a separate successful ledger confirmation. Null (including an RLS-
 * hidden row), pending and unknown status all retain the marker and proof.
 *
 * Sibling to [shouldClearEscrowMarker] — same shape but different
 * status vocabulary (AMC payment orders have `failed`; escrow rows
 * don't).
 */
internal fun shouldClearAmcPaymentMarker(status: String?): Boolean = when (status) {
    "refunded", "failed" -> true
    else -> false
}
