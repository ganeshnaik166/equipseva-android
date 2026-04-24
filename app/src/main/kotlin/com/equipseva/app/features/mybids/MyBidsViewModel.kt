package com.equipseva.app.features.mybids

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.dao.OutboxDao
import com.equipseva.app.core.data.repair.RepairBid
import com.equipseva.app.core.data.repair.RepairBidRepository
import com.equipseva.app.core.data.repair.RepairBidStatus
import com.equipseva.app.core.data.repair.RepairJob
import com.equipseva.app.core.data.repair.RepairJobRepository
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.core.sync.OutboxKinds
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.distinctUntilChangedBy
import kotlinx.coroutines.flow.filterIsInstance
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class MyBidsViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val bidRepository: RepairBidRepository,
    private val jobRepository: RepairJobRepository,
    private val outboxDao: OutboxDao,
) : ViewModel() {

    data class MyBidRow(val bid: RepairBid, val job: RepairJob?)

    data class UiState(
        val loading: Boolean = true,
        val refreshing: Boolean = false,
        val rows: List<MyBidRow> = emptyList(),
        val statusFilter: RepairBidStatus? = null,
        val queuedBidCount: Int = 0,
        val errorMessage: String? = null,
    ) {
        val visibleRows: List<MyBidRow>
            get() = if (statusFilter == null) rows
            else rows.filter { it.bid.status == statusFilter }
    }

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    fun onStatusFilterChange(filter: RepairBidStatus?) {
        _state.update { it.copy(statusFilter = filter) }
    }

    init {
        viewModelScope.launch {
            authRepository.sessionState
                .filterIsInstance<AuthSession.SignedIn>()
                .distinctUntilChangedBy { it.userId }
                .collect { load(initial = true) }
        }
        outboxDao.observePendingCountByKind(OutboxKinds.REPAIR_BID)
            .onEach { count -> _state.update { it.copy(queuedBidCount = count) } }
            .launchIn(viewModelScope)
    }

    fun onRefresh() = load(initial = false)

    private fun load(initial: Boolean) {
        _state.update {
            it.copy(
                loading = initial,
                refreshing = !initial,
                errorMessage = null,
            )
        }
        viewModelScope.launch {
            bidRepository.fetchMyBids()
                .onSuccess { bids ->
                    val jobIds = bids.map { it.repairJobId }.toSet()
                    val jobsById = if (jobIds.isEmpty()) emptyMap()
                    else jobRepository.fetchByIds(jobIds)
                        .getOrElse { emptyList() }
                        .associateBy { it.id }
                    _state.update {
                        it.copy(
                            loading = false,
                            refreshing = false,
                            rows = bids.map { bid -> MyBidRow(bid, jobsById[bid.repairJobId]) },
                            errorMessage = null,
                        )
                    }
                }
                .onFailure { error ->
                    _state.update {
                        it.copy(
                            loading = false,
                            refreshing = false,
                            errorMessage = error.toUserMessage(),
                        )
                    }
                }
        }
    }
}
