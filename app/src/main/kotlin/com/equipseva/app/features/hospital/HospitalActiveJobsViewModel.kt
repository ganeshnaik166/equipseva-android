package com.equipseva.app.features.hospital

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.repair.RepairJob
import com.equipseva.app.core.data.repair.RepairJobRepository
import com.equipseva.app.core.data.repair.RepairJobStatus
import com.equipseva.app.core.network.toUserMessage
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.async
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.distinctUntilChangedBy
import kotlinx.coroutines.flow.filterIsInstance
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class HospitalActiveJobsViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val jobRepository: RepairJobRepository,
    // r1509 — best-effort escrow lookups so Assigned-but-unpaid jobs can wear
    // an "Awaiting payment" badge at the list level (the revenue leak: a
    // hospital who accepts a bid then dismisses the pay sheet had NO nudge
    // anywhere — the job stalled silently and the engineer stayed blocked).
    private val escrowRepository: com.equipseva.app.core.data.escrow.RepairJobEscrowRepository,
) : ViewModel() {

    enum class Filter { All, Open, Active, Closed }

    data class UiState(
        val loading: Boolean = true,
        val refreshing: Boolean = false,
        val openJobs: List<RepairJob> = emptyList(),
        val inProgressJobs: List<RepairJob> = emptyList(),
        val closedJobs: List<RepairJob> = emptyList(),
        val errorMessage: String? = null,
        val filter: Filter = Filter.All,
        // r1509 — job ids whose escrow is still 'pending' (accepted bid,
        // payment not completed). Best-effort: empty on lookup failure.
        val awaitingPaymentJobIds: Set<String> = emptySet(),
    ) {
        val visibleJobs: List<RepairJob>
            get() = when (filter) {
                Filter.All -> openJobs + inProgressJobs + closedJobs
                Filter.Open -> openJobs
                Filter.Active -> inProgressJobs
                Filter.Closed -> closedJobs
            }
    }

    fun onFilterChange(filter: Filter) {
        _state.update { it.copy(filter = filter) }
    }

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    private var currentUserId: String? = null

    init {
        viewModelScope.launch {
            authRepository.sessionState
                .filterIsInstance<AuthSession.SignedIn>()
                .distinctUntilChangedBy { it.userId }
                .collect { session ->
                    currentUserId = session.userId
                    load(initial = true)
                }
        }
    }

    fun onRefresh() = load(initial = false)

    private fun load(initial: Boolean) {
        val userId = currentUserId ?: return
        _state.update { it.copy(loading = initial, refreshing = !initial, errorMessage = null) }
        viewModelScope.launch {
            jobRepository.fetchByHospitalUser(userId)
                .onSuccess { jobs ->
                    val open = jobs.filter { it.status == RepairJobStatus.Requested }
                    val inProgress = jobs.filter {
                        it.status in listOf(
                            RepairJobStatus.Assigned,
                            RepairJobStatus.EnRoute,
                            RepairJobStatus.InProgress,
                        )
                    }
                    val closed = jobs.filter {
                        it.status in listOf(
                            RepairJobStatus.Completed,
                            RepairJobStatus.Cancelled,
                            RepairJobStatus.Disputed,
                        )
                    }
                    _state.update {
                        // it.copy (not a fresh UiState) so the user's selected
                        // filter chip survives a refresh — a fresh UiState reset
                        // `filter` to its default (All), silently discarding the
                        // chosen tab on every pull-to-refresh / RefreshOnReturn.
                        it.copy(
                            loading = false,
                            refreshing = false,
                            openJobs = open,
                            inProgressJobs = inProgress,
                            closedJobs = closed,
                            errorMessage = null,
                        )
                    }
                    // r1509 — check escrow for the Assigned slice only (an
                    // accepted-but-unpaid job is always Assigned; pre-check-in
                    // there are at most a handful). Best-effort + concurrent;
                    // any lookup failure just leaves that badge off.
                    val checkIds = assignedJobIdsForEscrowCheck(jobs)
                    if (checkIds.isNotEmpty()) {
                        viewModelScope.launch {
                            val pending = kotlinx.coroutines.coroutineScope {
                                checkIds.map { id ->
                                    async {
                                        id.takeIf {
                                            escrowRepository.fetchByJob(id)
                                                .getOrNull()?.isPending == true
                                        }
                                    }
                                }.mapNotNull { it.await() }
                            }.toSet()
                            _state.update { it.copy(awaitingPaymentJobIds = pending) }
                        }
                    } else {
                        _state.update { it.copy(awaitingPaymentJobIds = emptySet()) }
                    }
                }
                .onFailure { ex ->
                    _state.update {
                        // Keep already-loaded jobs on a transient refresh failure;
                        // only surface the fatal error when there's nothing to show.
                        if (it.openJobs.isEmpty() && it.inProgressJobs.isEmpty() && it.closedJobs.isEmpty()) {
                            UiState(
                                loading = false,
                                refreshing = false,
                                errorMessage = ex.toUserMessage(),
                            )
                        } else {
                            it.copy(loading = false, refreshing = false)
                        }
                    }
                }
        }
    }
}

/**
 * r1509 — which jobs get a best-effort escrow lookup for the
 * "Awaiting payment" badge. Only Assigned jobs can be accepted-but-unpaid
 * (accept flips Requested → Assigned; payment flips the escrow pending →
 * held while the job STAYS Assigned until check-in), and pre-check-in there
 * are at most a handful — capped at [cap] as an N+1 safety valve so a
 * pathological account can't fan out dozens of lookups.
 */
internal fun assignedJobIdsForEscrowCheck(
    jobs: List<RepairJob>,
    cap: Int = 5,
): List<String> =
    jobs.filter { it.status == RepairJobStatus.Assigned }
        .map { it.id }
        .take(cap)

