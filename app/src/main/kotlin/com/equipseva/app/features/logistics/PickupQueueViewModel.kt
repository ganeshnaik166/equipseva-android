package com.equipseva.app.features.logistics

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.logistics.LogisticsJob
import com.equipseva.app.core.data.logistics.LogisticsJobRepository
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
class PickupQueueViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val logisticsRepository: LogisticsJobRepository,
) : ViewModel() {

    data class UiState(
        val loading: Boolean = true,
        val refreshing: Boolean = false,
        val jobs: List<LogisticsJob> = emptyList(),
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
            logisticsRepository.fetchPending()
                .onSuccess { jobs ->
                    _state.update {
                        UiState(loading = false, refreshing = false, jobs = jobs)
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
