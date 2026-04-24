package com.equipseva.app.features.orders

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.data.orders.Order
import com.equipseva.app.core.data.orders.OrderRepository
import com.equipseva.app.core.data.orders.OrderStatus
import com.equipseva.app.core.data.reviews.OrderReviewRepository
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.navigation.Routes
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class OrderDetailViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val orderRepository: OrderRepository,
    private val reviewRepository: OrderReviewRepository,
) : ViewModel() {

    data class UiState(
        val loading: Boolean = true,
        val refreshing: Boolean = false,
        val order: Order? = null,
        val notFound: Boolean = false,
        val errorMessage: String? = null,
        val cancellationInFlight: Boolean = false,
        val cancellationError: String? = null,
        val cancelSheetOpen: Boolean = false,
        val cancelReasonDraft: String = "",
        /**
         * True once we've confirmed the signed-in buyer already rated this
         * order. Used to hide the "Rate this order" CTA so we don't prompt
         * a duplicate submission — there is no unique constraint on
         * `reviews(reviewer_user_id, related_entity_id)` today, so the guard
         * is purely client-side.
         */
        val hasRating: Boolean = false,
    ) {
        /** CTA visible only on a delivered order the buyer hasn't rated yet. */
        val canRateOrder: Boolean
            get() = order != null &&
                order.status == OrderStatus.DELIVERED &&
                !hasRating
    }

    sealed interface Effect {
        data class ShowMessage(val text: String) : Effect
    }

    private val orderId: String = requireNotNull(savedStateHandle[Routes.ORDER_DETAIL_ARG_ID]) {
        "Missing orderId nav arg"
    }

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    private val _effects = Channel<Effect>(Channel.BUFFERED)
    val effects = _effects.receiveAsFlow()

    init { refresh() }

    fun refresh() {
        val hasOrder = _state.value.order != null
        _state.update {
            it.copy(
                loading = !hasOrder,
                refreshing = hasOrder,
                errorMessage = null,
                notFound = false,
            )
        }
        viewModelScope.launch {
            loadOrder()
            _state.update { it.copy(refreshing = false) }
        }
    }

    fun onRequestCancel() {
        if (_state.value.cancellationInFlight) return
        _state.update {
            it.copy(
                cancelSheetOpen = true,
                cancelReasonDraft = "",
                cancellationError = null,
            )
        }
    }

    fun onCancelReasonChange(next: String) {
        if (_state.value.cancellationInFlight) return
        _state.update { it.copy(cancelReasonDraft = next.take(MAX_CANCEL_REASON_LEN)) }
    }

    fun onDismissCancelSheet() {
        if (_state.value.cancellationInFlight) return
        _state.update { it.copy(cancelSheetOpen = false) }
    }

    fun onConfirmCancel() {
        val current = _state.value
        if (current.cancellationInFlight) return
        val targetId = current.order?.id ?: return
        val reason = current.cancelReasonDraft.trim().takeIf { it.isNotEmpty() }
        _state.update { it.copy(cancellationInFlight = true, cancellationError = null) }
        viewModelScope.launch {
            orderRepository.cancelOrder(targetId, reason)
                .onSuccess {
                    // Re-fetch so the UI sees the new status; the cancel button hides itself
                    // once order.status is no longer PLACED/CONFIRMED.
                    loadOrder()
                    _state.update {
                        it.copy(
                            cancellationInFlight = false,
                            cancellationError = null,
                            cancelSheetOpen = false,
                            cancelReasonDraft = "",
                        )
                    }
                    _effects.send(Effect.ShowMessage("Order cancelled"))
                }
                .onFailure { error ->
                    _state.update {
                        it.copy(
                            cancellationInFlight = false,
                            cancellationError = error.toUserMessage(),
                        )
                    }
                }
        }
    }

    private suspend fun loadOrder() {
        orderRepository.fetchById(orderId)
            .onSuccess { order ->
                _state.update {
                    it.copy(
                        loading = false,
                        order = order,
                        notFound = order == null,
                    )
                }
                // Only bother asking Supabase for an existing review once the
                // order is actually delivered — other statuses don't render
                // the rating CTA anyway, so the round-trip would be wasted.
                if (order != null && order.status == OrderStatus.DELIVERED) {
                    val existing = reviewRepository.fetchMineForOrder(order.id).getOrNull()
                    _state.update { it.copy(hasRating = existing != null) }
                }
            }
            .onFailure { error ->
                _state.update {
                    it.copy(loading = false, errorMessage = error.toUserMessage())
                }
            }
    }

    private companion object {
        // Matches the server-side check constraint spare_part_orders_cancel_reason_len.
        const val MAX_CANCEL_REASON_LEN = 500
    }
}
