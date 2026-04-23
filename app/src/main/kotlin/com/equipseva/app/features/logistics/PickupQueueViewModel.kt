package com.equipseva.app.features.logistics

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.logistics.LogisticsJob
import com.equipseva.app.core.data.logistics.LogisticsJobRepository
import com.equipseva.app.core.network.toUserMessage
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.distinctUntilChangedBy
import kotlinx.coroutines.flow.filterIsInstance
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class PickupQueueViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val logisticsRepository: LogisticsJobRepository,
) : ViewModel() {

    data class UiState(
        val loading: Boolean = true,
        val refreshing: Boolean = false,
        val jobs: List<LogisticsJob> = emptyList(),
        val acceptingJobId: String? = null,
        val errorMessage: String? = null,
    )

    sealed interface Effect {
        data class ShowMessage(val text: String) : Effect
    }

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    private val _effects = Channel<Effect>(Channel.BUFFERED)
    val effects = _effects.receiveAsFlow()

    private var userId: String? = null

    init {
        viewModelScope.launch {
            authRepository.sessionState
                .filterIsInstance<AuthSession.SignedIn>()
                .distinctUntilChangedBy { it.userId }
                .collect { session ->
                    userId = session.userId
                    load(initial = true)
                }
        }
    }

    fun onRefresh() = load(initial = false)

    fun onAcceptJob(job: LogisticsJob) {
        val uid = userId ?: run {
            emit(Effect.ShowMessage("Sign in again to accept jobs"))
            return
        }
        if (_state.value.acceptingJobId != null) return
        _state.update { it.copy(acceptingJobId = job.id) }
        viewModelScope.launch {
            logisticsRepository.acceptJob(job.id, uid)
                .onSuccess {
                    _state.update { snap ->
                        snap.copy(
                            acceptingJobId = null,
                            jobs = snap.jobs.filterNot { it.id == job.id },
                        )
                    }
                    emit(Effect.ShowMessage("Job accepted"))
                }
                .onFailure { error ->
                    _state.update { it.copy(acceptingJobId = null) }
                    emit(Effect.ShowMessage(error.toUserMessage()))
                }
        }
    }

    private fun load(initial: Boolean) {
        _state.update {
            it.copy(loading = initial, refreshing = !initial, errorMessage = null)
        }
        viewModelScope.launch {
            logisticsRepository.fetchPending()
                .onSuccess { jobs ->
                    _state.update {
                        it.copy(loading = false, refreshing = false, jobs = jobs)
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

    private fun emit(effect: Effect) {
        viewModelScope.launch { _effects.send(effect) }
    }
}
