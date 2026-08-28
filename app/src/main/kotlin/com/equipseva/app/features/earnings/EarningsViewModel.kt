package com.equipseva.app.features.earnings

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.amc.AmcRepository
import com.equipseva.app.core.data.escrow.RepairJobEscrowRepository
import com.equipseva.app.core.data.payouts.EngineerPayoutRepository
import com.equipseva.app.core.data.payouts.EngineerPayoutRow
import com.equipseva.app.core.data.payouts.PayoutMethodVerification
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
        // r783 — payout-method verification state. true iff engineer has at
        // least one row in engineer_payout_methods with status='verified'.
        // When false AND engineer has any earnings, the screen shows a
        // nudge banner urging VPA verification (analog of founder
        // /engineers-missing-payout r726).
        val payoutMethodVerified: Boolean = false,
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
            // Round 436 — fire all 5 fetches in parallel and INDEPENDENT
            // of each other. Pre-432 the 4 fire-and-forget child fetches
            // were nested INSIDE bidRepository.fetchMyBids().onSuccess, so
            // a transient bid-RPC error (network blip, RLS hiccup) silently
            // wiped escrow/self-rank/AMC/payouts data from a previous
            // successful load — the engineer's whole screen blanked out
            // even though escrow + payouts are independent sources of
            // truth. Each fetch now owns its own UiState slice and
            // surfaces its own error scope.
            val bid = launch { loadBidRows() }
            val escrow = launch { loadEscrowSummary() }
            val rank = launch { loadSelfRank() }
            val amc = launch { loadAmcEarnings() }
            val payouts = launch { loadPayouts() }
            // r783 — payout method verification check. Independent slice,
            // failure leaves the banner hidden (safe default).
            val method = launch { loadPayoutMethod() }
            // Wait for ALL to settle before flipping loading/refreshing
            // off so the pull-to-refresh indicator hides only when the
            // screen has actually re-stabilised.
            bid.join(); escrow.join(); rank.join(); amc.join(); payouts.join(); method.join()
            _state.update { it.copy(loading = false, refreshing = false) }
        }
    }

    private suspend fun loadBidRows() {
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
                _state.update {
                    it.copy(
                        paidTotal = split.paidTotal,
                        pendingTotal = split.pendingTotal,
                        // Feed `resolved` (not the full `rows` list) so the
                        // row count + totals stay aligned. The full list
                        // included null-job orphans rendered as a generic
                        // "Repair job" placeholder, inflating the row count
                        // without contributing to the paid/pending hero
                        // numbers.
                        rows = split.resolvedRows,
                    )
                }
            }
            .onFailure { ex ->
                // Only the bid-derived slice fails. Other sections
                // remain populated. Error surfaces in the banner.
                _state.update {
                    it.copy(
                        paidTotal = 0.0,
                        pendingTotal = 0.0,
                        rows = emptyList(),
                        errorMessage = ex.toUserMessage(),
                    )
                }
            }
    }

    private suspend fun loadEscrowSummary() {
        escrowRepository.fetchEngineerSummary().onSuccess { sum ->
            _state.update { it.copy(escrowSummary = sum) }
        }
        // Quiet on failure — card hides.
    }

    private suspend fun loadSelfRank() {
        escrowRepository.fetchEngineerSelfRank(windowDays = 30)
            .onSuccess { rk -> _state.update { it.copy(selfRank = rk) } }
    }

    private suspend fun loadAmcEarnings() {
        amcRepository.listMyAmcEarnings().onSuccess { amc ->
            _state.update {
                it.copy(
                    amcEarnings = amc,
                    amcPaidTotal = amc.sumOf { row -> row.engineerPayoutRupees },
                )
            }
        }
    }

    private suspend fun loadPayouts() {
        payoutRepository.listPayouts(limit = 50).onSuccess { rows ->
            _state.update { it.copy(payouts = rows) }
        }
    }

    private suspend fun loadPayoutMethod() {
        // r783 — fetchCurrent returns the engineer's default payout method
        // (or null if none set). Treat it as verified ONLY when status is
        // explicitly 'verified'. Anything else (null, unverified, invalid)
        // → banner appears if engineer has earnings.
        payoutRepository.fetchAll()
            .onSuccess { methods ->
                val hasVerified = methods.any {
                    it.verificationStatus == PayoutMethodVerification.Verified
                }
                _state.update { it.copy(payoutMethodVerified = hasVerified) }
            }
            .onFailure {
                // Safe default: don't pop a banner on transient errors.
                _state.update { it.copy(payoutMethodVerified = true) }
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
    // Round 3760 — repair_job_bids.amount_rupees can be null on a
    // legacy/anomalous bid row; fold to 0.0 in these SUM aggregates
    // (rather than crashing or dropping the row from resolvedRows,
    // which would break the filtering invariants pinned below).
    val paid = resolved.filter { it.job?.status == RepairJobStatus.Completed }
        .sumOf { it.job?.engineerPayoutRupees ?: it.bid.amountRupees ?: 0.0 }
    val pending = resolved.filter { it.job?.status != RepairJobStatus.Completed }
        .sumOf { it.bid.amountRupees ?: 0.0 }
    return EarningsSplit(
        resolvedRows = resolved,
        paidTotal = paid,
        pendingTotal = pending,
    )
}

