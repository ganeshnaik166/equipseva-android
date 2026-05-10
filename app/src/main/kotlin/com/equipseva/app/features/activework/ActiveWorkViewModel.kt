package com.equipseva.app.features.activework

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.dao.OutboxDao
import com.equipseva.app.core.data.repair.RepairJob
import com.equipseva.app.core.data.repair.RepairJobRepository
import com.equipseva.app.core.data.repair.RepairJobStatus
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
class ActiveWorkViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val jobRepository: RepairJobRepository,
    private val outboxDao: OutboxDao,
) : ViewModel() {

    data class UiState(
        val loading: Boolean = true,
        val refreshing: Boolean = false,
        val activeJobs: List<RepairJob> = emptyList(),
        val completedJobs: List<RepairJob> = emptyList(),
        val queuedStatusCount: Int = 0,
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
        outboxDao.observePendingCountByKind(OutboxKinds.JOB_STATUS)
            .onEach { count -> _state.update { it.copy(queuedStatusCount = count) } }
            .launchIn(viewModelScope)
    }

    fun onRefresh() = load(initial = false)

    private fun load(initial: Boolean) {
        _state.update {
            it.copy(loading = initial, refreshing = !initial, errorMessage = null)
        }
        viewModelScope.launch {
            jobRepository.fetchAssignedToMe()
                .onSuccess { jobs ->
                    val active = jobs.filter {
                        // Include Assigned so engineers see jobs the moment a
                        // hospital accepts their bid — without this they had
                        // no entry point to the job until they Check-in
                        // flipped status to InProgress, which is impossible
                        // to do from a screen the assignment doesn't appear on.
                        it.status in listOf(
                            RepairJobStatus.Assigned,
                            RepairJobStatus.EnRoute,
                            RepairJobStatus.InProgress,
                        )
                    }
                    val completed = jobs.filter {
                        it.status in listOf(RepairJobStatus.Completed, RepairJobStatus.Cancelled)
                    }
                    _state.update {
                        it.copy(
                            loading = false,
                            refreshing = false,
                            activeJobs = active,
                            completedJobs = completed,
                            errorMessage = null,
                        )
                    }
                }
                .onFailure { ex ->
                    _state.update {
                        it.copy(
                            loading = false,
                            refreshing = false,
                            activeJobs = emptyList(),
                            completedJobs = emptyList(),
                            errorMessage = ex.toUserMessage(),
                        )
                    }
                }
        }
    }
}

