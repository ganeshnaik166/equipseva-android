package com.equipseva.app.features.earnings

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.amc.AmcRepository
import com.equipseva.app.core.data.escrow.RepairJobEscrowRepository
import com.equipseva.app.core.data.payouts.EngineerPayoutRepository
import com.equipseva.app.core.data.payouts.EngineerPayoutRow
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
    private val payoutRepository: EngineerPayoutRepository,
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
        // Round 368 — engineer's own monthly rank + jobs + revenue. Null
        // while loading or on RPC failure; the card hides in either case.
        val selfRank: RepairJobEscrowRepository.EngineerSelfRank? = null,
        // Round 427 — engineer-facing payout history (queued / processing /
        // processed / failed rows from engineer_payouts). Empty list while
        // loading or on RPC failure; the section just hides in either case.
        val payouts: List<EngineerPayoutRow> = emptyList(),
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
                    val split = computeEarningsSplit(rows)
                    val resolved = split.resolvedRows
                    val paid = split.paidTotal
                    val pending = split.pendingTotal

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
                    // Round 368 — self-rank fetch (auth.uid()-scoped).
                    // Same fire-and-forget pattern; the card hides on
                    // null. RPC returns a single row even if engineer
                    // has 0 jobs in window (rank = null then).
                    viewModelScope.launch {
                        escrowRepository.fetchEngineerSelfRank(windowDays = 30)
                            .onSuccess { rk -> _state.update { it.copy(selfRank = rk) } }
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
                    // Round 427 — auto-payout history. Distinct from the
                    // bid-level "Recent payouts" list above (which mirrors
                    // job-completion transactions) — this is the real
                    // money-transfer queue (engineer_payouts table).
                    viewModelScope.launch {
                        payoutRepository.listPayouts(limit = 50).onSuccess { rows ->
                            _state.update { it.copy(payouts = rows) }
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

/**
 * Bundle returned by [computeEarningsSplit]. Carries the projected
 * row list (job-resolved rows only) plus the paid / pending totals
 * the EarningsScreen hero cards render.
 */
internal data class EarningsSplit(
    val resolvedRows: List<EarningsViewModel.EarningRow>,
    val paidTotal: Double,
    val pendingTotal: Double,
)

/**
 * Pure projector that splits an accepted-bid row list into:
 *   * resolvedRows — only rows whose job was successfully fetched.
 *     Rows whose job is null (server-side delete / RLS hide / row
 *     dropped) are filtered out so they don't inflate the engineer's
 *     pending total.
 *   * paidTotal — sum of payout for completed rows. Uses
 *     `job.engineerPayoutRupees` (post-commission-split per PR-D36 /
 *     PR-D2 tier-aware) when present, falling back to the bid amount
 *     only on legacy rows that pre-date the commission trigger.
 *   * pendingTotal — sum of bid amounts for non-completed rows.
 *     Stays on bid amount because it's an estimate; commission hasn't
 *     been computed server-side yet.
 *
 * Extracted from EarningsViewModel.load so the post-D36 payout
 * semantics + null-job filtering can be unit-tested.
 */
internal fun computeEarningsSplit(
    rows: List<EarningsViewModel.EarningRow>,
): EarningsSplit {
    val resolved = rows.filter { it.job != null }
    val paid = resolved.filter { it.job?.status == RepairJobStatus.Completed }
        .sumOf { it.job?.engineerPayoutRupees ?: it.bid.amountRupees }
    val pending = resolved.filter { it.job?.status != RepairJobStatus.Completed }
        .sumOf { it.bid.amountRupees }
    return EarningsSplit(
        resolvedRows = resolved,
        paidTotal = paid,
        pendingTotal = pending,
    )
}

