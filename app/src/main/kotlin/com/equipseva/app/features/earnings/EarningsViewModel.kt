package com.equipseva.app.features.earnings

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.repair.RepairBid
import com.equipseva.app.core.data.repair.RepairBidRepository
import com.equipseva.app.core.data.repair.RepairBidStatus
import com.equipseva.app.core.data.repair.RepairJob
import com.equipseva.app.core.data.repair.RepairJobRepository
import com.equipseva.app.core.data.repair.RepairJobStatus
import com.equipseva.app.core.network.toUserMessage
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.distinctUntilChangedBy
import kotlinx.coroutines.flow.filterIsInstance
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class EarningsViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val bidRepository: RepairBidRepository,
    private val jobRepository: RepairJobRepository,
) : ViewModel() {

    data class EarningRow(val bid: RepairBid, val job: RepairJob?)

    data class UiState(
        val loading: Boolean = true,
        val refreshing: Boolean = false,
        val paidTotal: Double = 0.0,
        val pendingTotal: Double = 0.0,
        val rows: List<EarningRow> = emptyList(),
        val errorMessage: String? = null,
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init {
        viewModelScope.launch {
            authRepository.sessionState
                .filterIsInstance<AuthSession.SignedIn>()
                .distinctUntilChangedBy { it.userId }
                .collect { load(initial = true) }
        }
    }

    fun onRefresh() = load(initial = false)

    private fun load(initial: Boolean) {
        _state.update {
            it.copy(loading = initial, refreshing = !initial, errorMessage = null)
        }
        viewModelScope.launch {
            bidRepository.fetchMyBids()
                .onSuccess { bids ->
                    val accepted = bids.filter { it.status == RepairBidStatus.Accepted }
                    val jobIds = accepted.map { it.repairJobId }.toSet()
                    val jobsById = if (jobIds.isEmpty()) emptyMap()
                    else jobRepository.fetchByIds(jobIds)
                        .getOrElse { emptyList() }
                        .associateBy { it.id }

                    val rows = buildEarningRows(accepted, jobsById)
                    val totals = computeEarningTotals(rows)

                    _state.update {
                        UiState(
                            loading = false,
                            refreshing = false,
                            paidTotal = totals.paid,
                            pendingTotal = totals.pending,
                            rows = rows,
                            errorMessage = null,
                        )
                    }
                }
                .onFailure { ex ->
                    _state.update {
                        UiState(
                            loading = false,
                            refreshing = false,
                            paidTotal = 0.0,
                            pendingTotal = 0.0,
                            rows = emptyList(),
                            errorMessage = ex.toUserMessage(),
                        )
                    }
                }
        }
    }
}

/**
 * Paid (Completed job) vs pending (still-in-flight job) rupee totals
 * for the engineer's earnings screen. Bids whose job couldn't be
 * resolved (server-side delete, RLS hides it, or row dropped) are
 * excluded from both buckets — counting them as pending inflated the
 * expected payout in production.
 */
internal data class EarningTotals(val paid: Double, val pending: Double)

/**
 * Pair every accepted bid with the (already-fetched) job map. The row
 * list mirrors the engineer's bid order so the UI can render even when
 * a job is missing (null-job hint) — only the totals filter those out.
 */
internal fun buildEarningRows(
    acceptedBids: List<RepairBid>,
    jobsById: Map<String, RepairJob>,
): List<EarningsViewModel.EarningRow> =
    acceptedBids.map { EarningsViewModel.EarningRow(it, jobsById[it.repairJobId]) }

/**
 * Split rows into paid (Completed) vs pending (anything else) rupee
 * sums. Rows with a null job are dropped from both buckets — they're
 * unresolved on the server and we don't want to inflate either total
 * by guessing their state.
 */
internal fun computeEarningTotals(rows: List<EarningsViewModel.EarningRow>): EarningTotals {
    val resolved = rows.filter { it.job != null }
    val paid = resolved.filter { it.job?.status == RepairJobStatus.Completed }
        .sumOf { it.bid.amountRupees }
    val pending = resolved.filter { it.job?.status != RepairJobStatus.Completed }
        .sumOf { it.bid.amountRupees }
    return EarningTotals(paid = paid, pending = pending)
}

