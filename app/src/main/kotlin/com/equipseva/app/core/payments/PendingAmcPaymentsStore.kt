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
 * Before the SDK's checkout.open() call we stash the [paymentOrderId]
 * here. The runCheckout coroutine then clears the entry in its
 * `finally` block — regardless of success / cancel / failure. If the
 * Android process gets killed *during* Razorpay's checkout activity
 * (user switches to a UPI app, OS memory pressure), the entry survives
 * and [PendingAmcPaymentsReconciler] picks it up on next cold start to
 * decide whether the payment actually went through.
 *
 * Storing only the order id keeps the surface tiny: the canonical
 * truth is server-side (`amc_payment_orders.status`); we just need
 * a list of ids the client thought were in-flight.
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
        }
    }

    suspend fun clearAll() {
        context.pendingPaymentsDataStore.edit { it.remove(KEY_PENDING_AMC) }
    }

    private companion object {
        val KEY_PENDING_AMC = stringSetPreferencesKey("pending_amc_payment_orders")
    }
}
