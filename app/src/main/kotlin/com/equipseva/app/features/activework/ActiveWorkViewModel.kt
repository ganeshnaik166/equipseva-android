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
                    val active = jobs.filter { isActiveWorkJob(it.status) }
                    val completed = jobs.filter { isClosedWorkJob(it.status) }
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
                        if (it.activeJobs.isEmpty() && it.completedJobs.isEmpty())
                            it.copy(loading = false, refreshing = false, errorMessage = ex.toUserMessage())
                        else it.copy(loading = false, refreshing = false)
                    }
                }
        }
    }
}

/**
 * Is this status one the engineer is still working?
 *
 * Assigned is included so an engineer sees the job the moment a hospital
 * accepts their bid — without it they had no entry point at all until
 * check-in flipped the status, which cannot be done from a screen the
 * assignment never appears on.
 *
 * Requested is included for the same reason, and it is not a contradiction:
 * the list is fed by the assigned-to-me query, which filters on engineer_id
 * alone with no status filter. A visit pre-assigned to an engineer rather
 * than bid on keeps `requested` until they move it, so it arrives here with
 * their engineer id on it — and matching neither bucket dropped it off their
 * only list. An unassigned `requested` job never reaches this screen; those
 * live on the open-for-bidding feed.
 */
internal fun isActiveWorkJob(status: RepairJobStatus): Boolean = status in setOf(
    RepairJobStatus.Requested,
    RepairJobStatus.Assigned,
    RepairJobStatus.EnRoute,
    RepairJobStatus.InProgress,
)

/**
 * Is this status closed — no longer progressing, still needed in the list?
 *
 * Disputed belongs here, not nowhere. The server allows
 * `completed -> disputed`, the detail screen renders a dispute banner
 * plus the engineer's "Respond to dispute" action, and the hospital's own
 * list already files Disputed under closed. Matching neither bucket
 * dropped the job off the engineer's list at the exact moment they had an
 * admin review window to answer in — and the list is their only route to
 * the screen that lets them answer.
 */
internal fun isClosedWorkJob(status: RepairJobStatus): Boolean = status in setOf(
    RepairJobStatus.Completed,
    RepairJobStatus.Cancelled,
    RepairJobStatus.Disputed,
)
