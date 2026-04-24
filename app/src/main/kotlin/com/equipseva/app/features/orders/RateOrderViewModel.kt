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

/**
 * Drives the RateOrderScreen. Holds a draft (stars + optional comment), loads
 * the target order so we can show the supplier context + guard against rating
 * an undelivered order, and submits the review through [OrderReviewRepository].
 *
 * The screen is reachable only via the "Rate this order" CTA on
 * OrderDetailScreen, which already hides itself when the order isn't delivered
 * or when a review already exists — but we re-check server-side state on init
 * so a shared / deep link still behaves correctly.
 */
@HiltViewModel
class RateOrderViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val orderRepository: OrderRepository,
    private val reviewRepository: OrderReviewRepository,
) : ViewModel() {

    data class UiState(
        val loading: Boolean = true,
        val order: Order? = null,
        val notFound: Boolean = false,
        val ineligibleReason: String? = null,
        val stars: Int = 0,
        val comment: String = "",
        val submitting: Boolean = false,
        val submitted: Boolean = false,
        val errorMessage: String? = null,
    ) {
        val canSubmit: Boolean
            get() = !submitting &&
                !submitted &&
                order != null &&
                ineligibleReason == null &&
                stars in 1..5
    }

    sealed interface Effect {
        data class ShowMessage(val text: String) : Effect
        data object Done : Effect
    }

    private val orderId: String = requireNotNull(savedStateHandle[Routes.RATE_ORDER_ARG_ID]) {
        "Missing orderId nav arg"
    }

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    private val _effects = Channel<Effect>(Channel.BUFFERED)
    val effects = _effects.receiveAsFlow()

    init { load() }

    fun onStarsChange(value: Int) {
        if (_state.value.submitting || _state.value.submitted) return
        _state.update { it.copy(stars = value.coerceIn(0, 5)) }
    }

    fun onCommentChange(value: String) {
        if (_state.value.submitting || _state.value.submitted) return
        _state.update { it.copy(comment = value.take(MAX_COMMENT_LEN)) }
    }

    fun submit() {
        val snap = _state.value
        if (!snap.canSubmit) return
        val order = snap.order ?: return
        _state.update { it.copy(submitting = true, errorMessage = null) }
        viewModelScope.launch {
            reviewRepository.submit(
                orderId = order.id,
                revieweeOrgId = order.supplierOrgId,
                rating = snap.stars,
                comment = snap.comment.trim().ifBlank { null },
            ).onSuccess {
                _state.update { it.copy(submitting = false, submitted = true) }
                _effects.send(Effect.ShowMessage("Thanks — rating submitted"))
                _effects.send(Effect.Done)
            }.onFailure { ex ->
                _state.update {
                    it.copy(submitting = false, errorMessage = ex.toUserMessage())
                }
            }
        }
    }

    private fun load() {
        _state.update { it.copy(loading = true, errorMessage = null) }
        viewModelScope.launch {
            orderRepository.fetchById(orderId)
                .onSuccess { order ->
                    if (order == null) {
                        _state.update { it.copy(loading = false, notFound = true) }
                        return@onSuccess
                    }
                    // The CTA is only rendered for delivered orders, but we
                    // re-verify here so a shared rate-link for a non-delivered
                    // order lands on a helpful empty state rather than a write
                    // the server would probably still accept.
                    val ineligible = when (order.status) {
                        OrderStatus.DELIVERED -> null
                        else -> "You can only rate an order after it's delivered."
                    }
                    _state.update {
                        it.copy(
                            loading = false,
                            order = order,
                            ineligibleReason = ineligible,
                        )
                    }
                    // Load existing rating (if any) so repeat taps on the CTA
                    // after it's already submitted don't let the buyer double-rate.
                    val existing = reviewRepository.fetchMineForOrder(order.id).getOrNull()
                    if (existing != null) {
                        _state.update {
                            it.copy(
                                stars = existing.rating,
                                comment = existing.comment.orEmpty(),
                                submitted = true,
                            )
                        }
                    }
                }
                .onFailure { ex ->
                    _state.update {
                        it.copy(loading = false, errorMessage = ex.toUserMessage())
                    }
                }
        }
    }

    companion object {
        const val MAX_COMMENT_LEN = 500
    }
}
