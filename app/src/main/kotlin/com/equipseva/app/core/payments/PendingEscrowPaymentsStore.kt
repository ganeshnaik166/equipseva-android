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

private val Context.pendingEscrowPaymentsDataStore by
    preferencesDataStore("pending_escrow_payments")

/**
 * Round 280 — process-death recovery for repair-job escrow top-ups.
 *
 * Sibling to [PendingAmcPaymentsStore]; same shape, different bucket so
 * the AMC reconciler and the escrow reconciler don't trample each other's
 * marker sets. The unique key here is the parent `repair_job_id` (one
 * escrow row per job — `repair_job_escrow.repair_job_id` is UNIQUE), so
 * the reconciler can resolve the current escrow status via the existing
 * `get_repair_job_escrow(repair_job_id)` RPC.
 *
 * Before launching Razorpay we add the repair_job_id; the runCheckout
 * `finally` removes it regardless of success / cancel / failure. If the
 * Android process is killed during Razorpay's checkout activity the
 * marker survives and [PendingEscrowPaymentsReconciler] picks it up on
 * the next cold start.
 */
@Singleton
class PendingEscrowPaymentsStore @Inject constructor(
    @ApplicationContext private val context: Context,
) {

    fun observe(): Flow<Set<String>> =
        context.pendingEscrowPaymentsDataStore.data
            .map { it[KEY_PENDING_ESCROW] ?: emptySet() }

    suspend fun list(): Set<String> = observe().first()

    suspend fun add(repairJobId: String) {
        if (repairJobId.isBlank()) return
        context.pendingEscrowPaymentsDataStore.edit { prefs ->
            val current = prefs[KEY_PENDING_ESCROW] ?: emptySet()
            prefs[KEY_PENDING_ESCROW] = current + repairJobId
        }
    }

    suspend fun remove(repairJobId: String) {
        if (repairJobId.isBlank()) return
        context.pendingEscrowPaymentsDataStore.edit { prefs ->
            val current = prefs[KEY_PENDING_ESCROW] ?: emptySet()
            val next = current - repairJobId
            if (next.isEmpty()) {
                prefs.remove(KEY_PENDING_ESCROW)
            } else {
                prefs[KEY_PENDING_ESCROW] = next
            }
        }
    }

    suspend fun clearAll() {
        context.pendingEscrowPaymentsDataStore.edit { it.remove(KEY_PENDING_ESCROW) }
    }

    private companion object {
        val KEY_PENDING_ESCROW = stringSetPreferencesKey("pending_escrow_repair_job_ids")
    }
}
