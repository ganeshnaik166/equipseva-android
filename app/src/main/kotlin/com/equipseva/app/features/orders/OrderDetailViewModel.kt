package com.equipseva.app.features.orders

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.data.orders.Order
import com.equipseva.app.core.data.orders.OrderRepository
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.navigation.Routes
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class OrderDetailViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val orderRepository: OrderRepository,
) : ViewModel() {

    data class UiState(
        val loading: Boolean = true,
        val order: Order? = null,
        val notFound: Boolean = false,
        val errorMessage: String? = null,
    )

    private val orderId: String = requireNotNull(savedStateHandle[Routes.ORDER_DETAIL_ARG_ID]) {
        "Missing orderId nav arg"
    }

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init { refresh() }

    fun refresh() {
        _state.update { it.copy(loading = true, errorMessage = null, notFound = false) }
        viewModelScope.launch {
            orderRepository.fetchById(orderId)
                .onSuccess { order ->
                    _state.update {
                        it.copy(
                            loading = false,
                            order = order,
                            notFound = order == null,
                        )
                    }
                }
                .onFailure { error ->
                    _state.update {
                        it.copy(loading = false, errorMessage = error.toUserMessage())
                    }
                }
        }
    }
}
