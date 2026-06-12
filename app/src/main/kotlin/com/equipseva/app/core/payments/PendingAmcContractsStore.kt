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

private val Context.pendingAmcContractsDataStore by preferencesDataStore("pending_amc_contracts")

/**
 * Round 477 — payment-first AMC contract markers.
 *
 * The server migration adds `pending_payment` as the initial status of a
 * freshly-created AMC contract; the contract is promoted to `active` only
 * after the first verified pool credit. If the hospital backs out of
 * Razorpay mid-flow OR loses connectivity before verifyPayment lands,
 * the contract sits in `pending_payment` until the 24h server reaper
 * cancels it.
 *
 * This client-side store records contract ids the wizard created but
 * never saw activated. The home banner reads it to nudge the user to
 * finish payment before the reaper takes the contract away. The wizard
 * adds the entry right after createContract; the marker is cleared
 * only when verifyPayment succeeds (contract is now `active` server-
 * side) OR the user explicitly cancels the contract.
 *
 * Note: the existing [PendingAmcPaymentsStore] is per-payment-order
 * and used by [PendingAmcPaymentsReconciler] for process-death
 * recovery. This one is per-contract and surfaces the higher-level
 * "your contract isn't paid yet" UX — both can be in-flight together
 * for the same flow.
 */
@Singleton
class PendingAmcContractsStore @Inject constructor(
    @ApplicationContext private val context: Context,
) {

    fun observe(): Flow<Set<String>> =
        context.pendingAmcContractsDataStore.data
            .map { it[KEY_PENDING_CONTRACTS] ?: emptySet() }

    suspend fun list(): Set<String> = observe().first()

    suspend fun add(contractId: String) {
        if (contractId.isBlank()) return
        context.pendingAmcContractsDataStore.edit { prefs ->
            val current = prefs[KEY_PENDING_CONTRACTS] ?: emptySet()
            prefs[KEY_PENDING_CONTRACTS] = current + contractId
        }
    }

    suspend fun remove(contractId: String) {
        if (contractId.isBlank()) return
        context.pendingAmcContractsDataStore.edit { prefs ->
            val current = prefs[KEY_PENDING_CONTRACTS] ?: emptySet()
            val next = current - contractId
            if (next.isEmpty()) {
                prefs.remove(KEY_PENDING_CONTRACTS)
            } else {
                prefs[KEY_PENDING_CONTRACTS] = next
            }
        }
    }

    suspend fun clearAll() {
        context.pendingAmcContractsDataStore.edit { it.remove(KEY_PENDING_CONTRACTS) }
    }

    private companion object {
        val KEY_PENDING_CONTRACTS = stringSetPreferencesKey("pending_amc_contract_ids")
    }
}
