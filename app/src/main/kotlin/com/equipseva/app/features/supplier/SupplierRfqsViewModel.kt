package com.equipseva.app.features.supplier

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.rfq.Rfq
import com.equipseva.app.core.data.rfq.RfqBidInsertDto
import com.equipseva.app.core.data.rfq.RfqRepository
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
class SupplierRfqsViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val rfqRepository: RfqRepository,
) : ViewModel() {

    data class BidForm(
        val rfqId: String,
        val quantity: Int,
        val unitPriceText: String = "",
        val deliveryTimelineDaysText: String = "",
        val warrantyMonthsText: String = "",
        val includesInstallation: Boolean = false,
        val includesTraining: Boolean = false,
        val notes: String = "",
        val showValidationErrors: Boolean = false,
    ) {
        val unitPriceError: String?
            get() = when {
                unitPriceText.isBlank() -> "Required"
                unitPriceText.toDoubleOrNull() == null -> "Enter a valid number"
                (unitPriceText.toDoubleOrNull() ?: 0.0) <= 0.0 -> "Must be greater than 0"
                else -> null
            }
        val deliveryTimelineError: String?
            get() = if (deliveryTimelineDaysText.isBlank()) null
            else if (deliveryTimelineDaysText.toIntOrNull() == null) "Enter a whole number"
            else null
        val warrantyMonthsError: String?
            get() = if (warrantyMonthsText.isBlank()) null
            else if (warrantyMonthsText.toIntOrNull() == null) "Enter a whole number"
            else null

        val totalPrice: Double
            get() = (unitPriceText.toDoubleOrNull() ?: 0.0) * quantity

        val isValid: Boolean
            get() = listOf(unitPriceError, deliveryTimelineError, warrantyMonthsError)
                .all { it == null }
    }

    data class UiState(
        val loading: Boolean = true,
        val refreshing: Boolean = false,
        val rfqs: List<Rfq> = emptyList(),
        val errorMessage: String? = null,
        val bidForm: BidForm? = null,
        val submittingBid: Boolean = false,
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

    fun onOpenBid(rfq: Rfq) {
        _state.update { it.copy(bidForm = BidForm(rfqId = rfq.id, quantity = rfq.quantity)) }
    }

    fun onDismissBid() {
        _state.update { it.copy(bidForm = null, submittingBid = false) }
    }

    fun onUnitPriceChange(value: String) = updateBidForm { it.copy(unitPriceText = value.filterDecimal()) }
    fun onDeliveryTimelineChange(value: String) =
        updateBidForm { it.copy(deliveryTimelineDaysText = value.filter { c -> c.isDigit() }) }
    fun onWarrantyMonthsChange(value: String) =
        updateBidForm { it.copy(warrantyMonthsText = value.filter { c -> c.isDigit() }) }
    fun onIncludesInstallationChange(value: Boolean) = updateBidForm { it.copy(includesInstallation = value) }
    fun onIncludesTrainingChange(value: Boolean) = updateBidForm { it.copy(includesTraining = value) }
    fun onNotesChange(value: String) = updateBidForm { it.copy(notes = value) }

    fun onSubmitBid() {
        val snap = _state.value
        val form = snap.bidForm ?: return
        if (snap.submittingBid) return
        if (!form.isValid) {
            updateBidForm { it.copy(showValidationErrors = true) }
            return
        }
        val uid = userId ?: run {
            emit(Effect.ShowMessage("Sign in again to place a bid"))
            return
        }
        val unitPrice = form.unitPriceText.toDouble()
        val insert = RfqBidInsertDto(
            rfqId = form.rfqId,
            manufacturerId = uid,
            unitPrice = unitPrice,
            totalPrice = unitPrice * form.quantity,
            deliveryTimelineDays = form.deliveryTimelineDaysText.toIntOrNull(),
            warrantyMonths = form.warrantyMonthsText.toIntOrNull(),
            includesInstallation = form.includesInstallation,
            includesTraining = form.includesTraining,
            notes = form.notes.trim().takeIf { it.isNotBlank() },
        )
        _state.update { it.copy(submittingBid = true) }
        viewModelScope.launch {
            rfqRepository.placeBid(insert)
                .onSuccess {
                    _state.update { it.copy(submittingBid = false, bidForm = null) }
                    emit(Effect.ShowMessage("Bid submitted"))
                    load(initial = false)
                }
                .onFailure { error ->
                    _state.update { it.copy(submittingBid = false) }
                    emit(Effect.ShowMessage(error.toUserMessage()))
                }
        }
    }

    private fun load(initial: Boolean) {
        _state.update {
            it.copy(loading = initial, refreshing = !initial, errorMessage = null)
        }
        viewModelScope.launch {
            rfqRepository.fetchOpen()
                .onSuccess { rfqs ->
                    _state.update {
                        it.copy(
                            loading = false,
                            refreshing = false,
                            rfqs = rfqs,
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

    private fun updateBidForm(block: (BidForm) -> BidForm) {
        _state.update { it.copy(bidForm = it.bidForm?.let(block)) }
    }

    private fun emit(effect: Effect) {
        viewModelScope.launch { _effects.send(effect) }
    }

    private fun String.filterDecimal(): String {
        val cleaned = filter { it.isDigit() || it == '.' }
        val firstDot = cleaned.indexOf('.')
        return if (firstDot == -1) cleaned
        else cleaned.substring(0, firstDot + 1) +
            cleaned.substring(firstDot + 1).filter { it.isDigit() }
    }
}
