package com.equipseva.app.features.orders

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.orders.Order
import com.equipseva.app.core.data.orders.OrderRepository
import com.equipseva.app.core.network.toUserMessage
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.distinctUntilChangedBy
import kotlinx.coroutines.flow.filterIsInstance
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

private const val PAGE_SIZE = 20

@HiltViewModel
class OrdersViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val orderRepository: OrderRepository,
) : ViewModel() {

    data class UiState(
        val items: List<Order> = emptyList(),
        val initialLoading: Boolean = true,
        val refreshing: Boolean = false,
        val loadingMore: Boolean = false,
        val endReached: Boolean = false,
        val errorMessage: String? = null,
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    private var userId: String? = null
    private var pageJob: Job? = null

    init {
        viewModelScope.launch {
            authRepository.sessionState
                .filterIsInstance<AuthSession.SignedIn>()
                .distinctUntilChangedBy { it.userId }
                .collect { session ->
                    userId = session.userId
                    refresh(initial = true)
                }
        }
    }

    fun onRefresh() {
        refresh(initial = false)
    }

    fun onReachEnd() {
        val current = _state.value
        if (current.loadingMore || current.endReached || current.initialLoading) return
        val uid = userId ?: return
        val nextPage = current.items.size / PAGE_SIZE
        _state.update { it.copy(loadingMore = true, errorMessage = null) }
        pageJob?.cancel()
        pageJob = viewModelScope.launch {
            orderRepository.fetchMine(uid, page = nextPage, pageSize = PAGE_SIZE)
                .onSuccess { page ->
                    _state.update {
                        it.copy(
                            items = it.items + page,
                            loadingMore = false,
                            endReached = page.size < PAGE_SIZE,
                        )
                    }
                }
                .onFailure { error ->
                    _state.update {
                        it.copy(loadingMore = false, errorMessage = error.toUserMessage())
                    }
                }
        }
    }

    private fun refresh(initial: Boolean) {
        val uid = userId ?: return
        pageJob?.cancel()
        _state.update {
            it.copy(
                initialLoading = initial,
                refreshing = !initial,
                errorMessage = null,
            )
        }
        pageJob = viewModelScope.launch {
            orderRepository.fetchMine(uid, page = 0, pageSize = PAGE_SIZE)
                .onSuccess { page ->
                    _state.update {
                        UiState(
                            items = page,
                            initialLoading = false,
                            refreshing = false,
                            loadingMore = false,
                            endReached = page.size < PAGE_SIZE,
                            errorMessage = null,
                        )
                    }
                }
                .onFailure { error ->
                    _state.update {
                        it.copy(
                            initialLoading = false,
                            refreshing = false,
                            errorMessage = error.toUserMessage(),
                        )
                    }
                }
        }
    }
}
