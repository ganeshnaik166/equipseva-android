package com.equipseva.app.features.cart

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.data.cart.CartItem
import com.equipseva.app.core.data.cart.CartRepository
import com.equipseva.app.core.network.toUserMessage
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class CartViewModel @Inject constructor(
    private val cartRepository: CartRepository,
) : ViewModel() {

    data class UiState(
        val items: List<CartItem> = emptyList(),
        val totalInPaise: Long = 0L,
        val loading: Boolean = true,
    )

    sealed interface Effect {
        data class ShowMessage(val text: String) : Effect
        data object OpenCheckout : Effect
    }

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    private val _effects = Channel<Effect>(Channel.BUFFERED)
    val effects = _effects.receiveAsFlow()

    init {
        cartRepository.observe()
            .onEach { items ->
                _state.update {
                    it.copy(
                        items = items,
                        totalInPaise = items.sumOf { line -> line.unitPriceInPaise * line.quantity },
                        loading = false,
                    )
                }
            }
            .catch { error ->
                _state.update { it.copy(loading = false) }
                _effects.send(Effect.ShowMessage(error.toUserMessage()))
            }
            .launchIn(viewModelScope)
    }

    fun onIncrement(partId: String) = mutate { cartRepository.increment(partId) }

    fun onDecrement(partId: String) = mutate { cartRepository.decrement(partId) }

    fun onRemove(partId: String) = mutate { cartRepository.remove(partId) }

    fun onClear() = mutate { cartRepository.clear() }

    fun onCheckout() {
        if (_state.value.items.isEmpty()) {
            viewModelScope.launch { _effects.send(Effect.ShowMessage("Your cart is empty")) }
            return
        }
        viewModelScope.launch { _effects.send(Effect.OpenCheckout) }
    }

    private fun mutate(block: suspend () -> Result<Unit>) {
        viewModelScope.launch {
            block().onFailure { error ->
                _effects.send(Effect.ShowMessage(error.toUserMessage()))
            }
        }
    }
}
