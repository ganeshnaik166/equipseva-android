package com.equipseva.app.navigation

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.data.orders.OrderRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.channels.BufferOverflow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * Owns the decision of whether a deep-link event should actually navigate.
 * The [DeepLinkRouter] produces raw events straight from the intent; this host
 * verifies them against the backend before re-emitting, so a crafted URL from
 * another app can't blind-jump to a detail screen the user doesn't own.
 */
@HiltViewModel
class DeepLinkHost @Inject constructor(
    router: DeepLinkRouter,
    private val orderRepository: OrderRepository,
) : ViewModel() {

    sealed interface VerifiedEvent {
        data class OpenOrder(val orderId: String) : VerifiedEvent
        data object OrderNotFound : VerifiedEvent
    }

    private val _events = MutableSharedFlow<VerifiedEvent>(
        replay = 0,
        extraBufferCapacity = 4,
        onBufferOverflow = BufferOverflow.DROP_OLDEST,
    )
    val events: SharedFlow<VerifiedEvent> = _events.asSharedFlow()

    init {
        viewModelScope.launch {
            router.events.collect { raw ->
                when (raw) {
                    is DeepLinkRouter.Event.OpenOrder -> verifyOrder(raw.orderId)
                }
            }
        }
    }

    private suspend fun verifyOrder(orderId: String) {
        val order = orderRepository.fetchById(orderId).getOrNull()
        if (order != null) {
            _events.tryEmit(VerifiedEvent.OpenOrder(orderId))
        } else {
            // Either RLS refused or the row genuinely doesn't exist — either
            // way the caller doesn't own it, so don't navigate to detail.
            _events.tryEmit(VerifiedEvent.OrderNotFound)
        }
    }
}
