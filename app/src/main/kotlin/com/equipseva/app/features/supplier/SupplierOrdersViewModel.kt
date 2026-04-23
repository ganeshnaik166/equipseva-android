package com.equipseva.app.features.supplier

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.orders.Order
import com.equipseva.app.core.data.orders.OrderRepository
import com.equipseva.app.core.data.orders.OrderStatus
import com.equipseva.app.core.data.profile.ProfileRepository
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
class SupplierOrdersViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val profileRepository: ProfileRepository,
    private val orderRepository: OrderRepository,
) : ViewModel() {

    data class UiState(
        val loading: Boolean = true,
        val refreshing: Boolean = false,
        val orders: List<Order> = emptyList(),
        val errorMessage: String? = null,
        val noOrgWarning: Boolean = false,
        /** Non-null while a confirm/ship PATCH is in flight for this order id; disables the button. */
        val actingOrderId: String? = null,
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

    fun onConfirmOrder(order: Order) {
        if (order.status != OrderStatus.PLACED) return
        runAction(order.id) {
            orderRepository.confirmOrder(order.id)
                .onSuccess {
                    emit(Effect.ShowMessage("Order confirmed"))
                    load(initial = false)
                }
                .onFailure { error -> emit(Effect.ShowMessage(error.toUserMessage())) }
        }
    }

    fun onMarkShipped(order: Order) {
        if (order.status != OrderStatus.CONFIRMED) return
        runAction(order.id) {
            orderRepository.markShipped(order.id)
                .onSuccess {
                    emit(Effect.ShowMessage("Marked shipped"))
                    load(initial = false)
                }
                .onFailure { error -> emit(Effect.ShowMessage(error.toUserMessage())) }
        }
    }

    private fun runAction(orderId: String, block: suspend () -> Unit) {
        if (_state.value.actingOrderId != null) return
        _state.update { it.copy(actingOrderId = orderId) }
        viewModelScope.launch {
            try {
                block()
            } finally {
                _state.update { it.copy(actingOrderId = null) }
            }
        }
    }

    private fun emit(effect: Effect) {
        viewModelScope.launch { _effects.send(effect) }
    }

    private fun load(initial: Boolean) {
        val uid = userId ?: return
        _state.update {
            it.copy(loading = initial, refreshing = !initial, errorMessage = null, noOrgWarning = false)
        }
        viewModelScope.launch {
            val orgId = profileRepository.fetchById(uid).getOrNull()?.organizationId
            if (orgId.isNullOrBlank()) {
                _state.update {
                    it.copy(
                        loading = false,
                        refreshing = false,
                        orders = emptyList(),
                        noOrgWarning = true,
                    )
                }
                return@launch
            }
            orderRepository.fetchForSupplier(orgId)
                .onSuccess { orders ->
                    _state.update {
                        it.copy(
                            loading = false,
                            refreshing = false,
                            orders = orders,
                            errorMessage = null,
                            noOrgWarning = false,
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
