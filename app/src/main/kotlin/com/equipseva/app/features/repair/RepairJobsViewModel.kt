package com.equipseva.app.features.repair

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.data.repair.RepairBidRepository
import com.equipseva.app.core.data.repair.RepairJobRepository
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.features.repair.state.RepairJobsUiState
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.FlowPreview
import kotlinx.coroutines.Job
import kotlinx.coroutines.async
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.debounce
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.drop
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

private const val PAGE_SIZE = 20
private const val SEARCH_DEBOUNCE_MS = 300L

@OptIn(FlowPreview::class)
@HiltViewModel
class RepairJobsViewModel @Inject constructor(
    private val repository: RepairJobRepository,
    private val bidRepository: RepairBidRepository,
) : ViewModel() {

    private val _state = MutableStateFlow(RepairJobsUiState())
    val state: StateFlow<RepairJobsUiState> = _state.asStateFlow()

    /** Tracks the in-flight query/page combo so stale results get dropped. */
    private var pageJob: Job? = null

    init {
        refresh()

        // Re-query when the typed query stabilises. Drop(1) skips the initial
        // empty-query emission which `refresh()` in init already handled.
        _state
            .map { it.query }
            .distinctUntilChanged()
            .drop(1)
            .debounce(SEARCH_DEBOUNCE_MS)
            .onEach { refresh() }
            .launchIn(viewModelScope)
    }

    fun onQueryChange(value: String) {
        _state.update { it.copy(query = value, errorMessage = null) }
    }

    fun onRefresh() = refresh(viaPullToRefresh = true)

    fun onReachEnd() {
        val current = _state.value
        if (current.loadingMore || current.refreshing || current.initialLoading || current.endReached) return
        loadNext(page = current.items.size / PAGE_SIZE)
    }

    private fun refresh(viaPullToRefresh: Boolean = false) {
        pageJob?.cancel()
        _state.update {
            it.copy(
                initialLoading = it.items.isEmpty() && !viaPullToRefresh,
                refreshing = viaPullToRefresh,
                endReached = false,
                errorMessage = null,
                mineLoading = it.mineItems.isEmpty() && !viaPullToRefresh,
                mineErrorMessage = null,
            )
        }
        pageJob = viewModelScope.launch {
            val current = _state.value
            val jobsDeferred = async {
                repository.fetchOpenJobs(page = 0, pageSize = PAGE_SIZE, query = current.query)
            }
            val bidsDeferred = async { bidRepository.fetchMyBids() }
            val mineDeferred = async { repository.fetchAssignedToMe() }
            jobsDeferred.await().fold(
                onSuccess = { rows ->
                    val ownBids = bidsDeferred.await().getOrNull().orEmpty()
                        .associateBy { it.repairJobId }
                    _state.update {
                        it.copy(
                            items = rows,
                            ownBidsByJob = ownBids,
                            initialLoading = false,
                            refreshing = false,
                            endReached = rows.size < PAGE_SIZE,
                        )
                    }
                },
                onFailure = { ex ->
                    _state.update {
                        it.copy(
                            initialLoading = false,
                            refreshing = false,
                            errorMessage = ex.toUserMessage(),
                        )
                    }
                },
            )
            mineDeferred.await().fold(
                onSuccess = { rows ->
                    _state.update {
                        it.copy(mineItems = rows, mineLoading = false, mineErrorMessage = null)
                    }
                },
                onFailure = { ex ->
                    _state.update {
                        it.copy(mineLoading = false, mineErrorMessage = ex.toUserMessage())
                    }
                },
            )
        }
    }

    private fun loadNext(page: Int) {
        pageJob?.cancel()
        _state.update { it.copy(loadingMore = true, errorMessage = null) }
        pageJob = viewModelScope.launch {
            val current = _state.value
            repository.fetchOpenJobs(
                page = page,
                pageSize = PAGE_SIZE,
                query = current.query,
            ).fold(
                onSuccess = { rows ->
                    _state.update {
                        it.copy(
                            items = it.items + rows,
                            loadingMore = false,
                            endReached = rows.size < PAGE_SIZE,
                        )
                    }
                },
                onFailure = { ex ->
                    _state.update {
                        it.copy(
                            loadingMore = false,
                            errorMessage = ex.toUserMessage(),
                        )
                    }
                },
            )
        }
    }
}
