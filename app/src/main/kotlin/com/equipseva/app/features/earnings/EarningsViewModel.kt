package com.equipseva.app.features.earnings

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.amc.AmcRepository
import com.equipseva.app.core.data.escrow.RepairJobEscrowRepository
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
    private val escrowRepository: RepairJobEscrowRepository,
    private val amcRepository: AmcRepository,
) : ViewModel() {

    data class EarningRow(val bid: RepairBid, val job: RepairJob?)

    data class UiState(
        val loading: Boolean = true,
        val refreshing: Boolean = false,
        val paidTotal: Double = 0.0,
        val pendingTotal: Double = 0.0,
        val rows: List<EarningRow> = emptyList(),
        val escrowSummary: RepairJobEscrowRepository.EngineerEscrowSummary? = null,
        // Round 234 — AMC visit payouts surfaced alongside repair-bid
        // earnings. Total is the sum of engineer_payout_rupees (85% of
        // the per-visit cost). Empty list / 0 total when the engineer
        // hasn't completed any AMC visits.
        val amcEarnings: List<AmcRepository.EngineerAmcEarning> = emptyList(),
        val amcPaidTotal: Double = 0.0,
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

                    val rows = accepted.map { EarningRow(it, jobsById[it.repairJobId]) }
                    // Drop bids whose job we couldn't resolve (server-side
                    // delete, RLS hides it, or the row dropped) — counting
                    // them as "pending" inflated the engineer's expected
                    // payout. They surface in the row list with a null-job
                    // hint so the engineer can investigate.
                    val resolved = rows.filter { it.job != null }
                    // PR-D36: paid total reflects ACTUAL payout after the
                    // commission split (PR #259 + tier-aware PR-D2). Falls
                    // back to bid amount only when payout column is null
                    // (legacy completed rows pre-trigger). Pending stays
                    // on bid amount — it's an estimate.
                    val paid = resolved.filter { it.job?.status == RepairJobStatus.Completed }
                        .sumOf { it.job?.engineerPayoutRupees ?: it.bid.amountRupees }
                    val pending = resolved.filter { it.job?.status != RepairJobStatus.Completed }
                        .sumOf { it.bid.amountRupees }

                    _state.update {
                        UiState(
                            loading = false,
                            refreshing = false,
                            paidTotal = paid,
                            pendingTotal = pending,
                            // Feed `resolved` (not the full `rows` list) so
                            // the row count + totals stay aligned. The full
                            // list included null-job orphans rendered as a
                            // generic "Repair job" placeholder, inflating
                            // the row count without contributing to the
                            // paid/pending hero numbers.
                            rows = resolved,
                            escrowSummary = it.escrowSummary,
                            errorMessage = null,
                        )
                    }
                    // Fire-and-forget escrow summary alongside the bid pull —
                    // failures here don't fail the screen; the card just stays
                    // hidden if the RPC errors.
                    viewModelScope.launch {
                        escrowRepository.fetchEngineerSummary().onSuccess { sum ->
                            _state.update { it.copy(escrowSummary = sum) }
                        }
                    }
                    // Same fire-and-forget pattern for AMC visit payouts.
                    // Quiet on errors: the section just stays hidden.
                    viewModelScope.launch {
                        amcRepository.listMyAmcEarnings().onSuccess { amc ->
                            _state.update {
                                it.copy(
                                    amcEarnings = amc,
                                    amcPaidTotal = amc.sumOf { row -> row.engineerPayoutRupees },
                                )
                            }
                        }
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

