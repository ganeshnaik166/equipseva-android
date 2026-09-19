package com.equipseva.app.core.payments

import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringSetPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import dagger.hilt.android.qualifiers.ApplicationContext
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map

private val Context.pendingPaymentsDataStore by preferencesDataStore("pending_payments")

/**
 * Round 234 — Razorpay process-death recovery for AMC pool top-ups.
 *
 * Before checkout opens, retain its payment-order ID here. SDK success also
 * stores its verification proof; failed or incomplete confirmation preserves
 * it across process death. [PendingAmcPaymentsReconciler] retries supported
 * pending/paid recovery and removes proof only after matching ledger success,
 * or a confirmed failed/refunded terminal state.
 *
 * Alongside each id we keep the Razorpay success payload (when the
 * SDK got far enough to hand one over) because the client is the only
 * holder of the HMAC signature between `onPaymentSuccess` and a
 * successful `verify-amc-payment`. Without it, a verify that fails
 * transiently leaves a captured payment with no client-side way to
 * re-assert it, and crediting the pool depends entirely on the
 * Razorpay dashboard webhook being configured.
 */
@Singleton
class PendingAmcPaymentsStore @Inject constructor(
    @ApplicationContext private val context: Context,
) {

    fun observe(): Flow<Set<String>> =
        context.pendingPaymentsDataStore.data
            .map { it[KEY_PENDING_AMC] ?: emptySet() }

    suspend fun list(): Set<String> = observe().first()

    suspend fun add(paymentOrderId: String) {
        if (paymentOrderId.isBlank()) return
        context.pendingPaymentsDataStore.edit { prefs ->
            val current = prefs[KEY_PENDING_AMC] ?: emptySet()
            prefs[KEY_PENDING_AMC] = current + paymentOrderId
        }
    }

    suspend fun remove(paymentOrderId: String) {
        if (paymentOrderId.isBlank()) return
        context.pendingPaymentsDataStore.edit { prefs ->
            val current = prefs[KEY_PENDING_AMC] ?: emptySet()
            val next = current - paymentOrderId
            if (next.isEmpty()) {
                prefs.remove(KEY_PENDING_AMC)
            } else {
                prefs[KEY_PENDING_AMC] = next
            }
            // The signature is only useful while the order is unresolved; the
            // marker and the payload go together so a resolved order never
            // leaves a payment signature sitting on disk.
            val payloads = prefs[KEY_VERIFIABLE_AMC] ?: emptySet()
            val keptPayloads = payloads.filter {
                decodeVerifiableAmcPayment(it)?.paymentOrderId != paymentOrderId
            }.toSet()
            if (keptPayloads.isEmpty()) {
                prefs.remove(KEY_VERIFIABLE_AMC)
            } else {
                prefs[KEY_VERIFIABLE_AMC] = keptPayloads
            }
        }
    }

    /**
     * Stash the Razorpay success payload for an order whose verify call has
     * not landed yet, so [PendingAmcPaymentsReconciler] can retry the verify
     * instead of only reading the order's status.
     */
    suspend fun recordVerifiable(payment: VerifiableAmcPayment) {
        if (!payment.isVerifiable) return
        val encoded = encodeVerifiableAmcPayment(payment)
        context.pendingPaymentsDataStore.edit { prefs ->
            val current = prefs[KEY_VERIFIABLE_AMC] ?: emptySet()
            // One payload per order: a retry of the same order replaces the
            // earlier attempt rather than accumulating stale signatures.
            val others = current.filter {
                decodeVerifiableAmcPayment(it)?.paymentOrderId != payment.paymentOrderId
            }
            prefs[KEY_VERIFIABLE_AMC] = (others + encoded).toSet()
        }
    }

    suspend fun verifiable(paymentOrderId: String): VerifiableAmcPayment? {
        if (paymentOrderId.isBlank()) return null
        val raw = context.pendingPaymentsDataStore.data
            .map { it[KEY_VERIFIABLE_AMC] ?: emptySet() }
            .first()
        return raw.asSequence()
            .mapNotNull { decodeVerifiableAmcPayment(it) }
            .firstOrNull { it.paymentOrderId == paymentOrderId }
    }

    suspend fun clearAll() {
        context.pendingPaymentsDataStore.edit {
            it.remove(KEY_PENDING_AMC)
            it.remove(KEY_VERIFIABLE_AMC)
        }
    }

    private companion object {
        val KEY_PENDING_AMC = stringSetPreferencesKey("pending_amc_payment_orders")
        val KEY_VERIFIABLE_AMC = stringSetPreferencesKey("pending_amc_verifiable_payments")
    }
}

/**
 * A Razorpay success the server has not confirmed yet. All four fields are
 * required by `verify-amc-payment`; a payload missing any of them can never
 * verify, so [isVerifiable] keeps it out of the store.
 */
data class VerifiableAmcPayment(
    val paymentOrderId: String,
    val razorpayOrderId: String,
    val razorpayPaymentId: String,
    val razorpaySignature: String,
) {
    val isVerifiable: Boolean
        get() = paymentOrderId.isNotBlank() &&
            razorpayOrderId.isNotBlank() &&
            razorpayPaymentId.isNotBlank() &&
            razorpaySignature.isNotBlank()
}

// Unit Separator: Razorpay ids are `[A-Za-z0-9_]`-shaped and the signature is
// hex, so a control character cannot collide with payload content the way a
// pipe or comma could.
private const val VERIFIABLE_FIELD_SEPARATOR = '\u001F'

internal fun encodeVerifiableAmcPayment(payment: VerifiableAmcPayment): String =
    listOf(
        payment.paymentOrderId,
        payment.razorpayOrderId,
        payment.razorpayPaymentId,
        payment.razorpaySignature,
    ).joinToString(separator = VERIFIABLE_FIELD_SEPARATOR.toString())

/**
 * Returns null for anything this build cannot act on — a payload written by a
 * different schema, or one missing a field. A null here must be treated as
 * "no payload", never permission to discard unresolved recovery. The status
 * sweep may clear failed/refunded markers, but paid without proof stays visible
 * for support because status alone cannot establish pool credit.
 */
internal fun decodeVerifiableAmcPayment(raw: String): VerifiableAmcPayment? {
    val parts = raw.split(VERIFIABLE_FIELD_SEPARATOR)
    if (parts.size != 4) return null
    val payment = VerifiableAmcPayment(
        paymentOrderId = parts[0],
        razorpayOrderId = parts[1],
        razorpayPaymentId = parts[2],
        razorpaySignature = parts[3],
    )
    return payment.takeIf { it.isVerifiable }
}
