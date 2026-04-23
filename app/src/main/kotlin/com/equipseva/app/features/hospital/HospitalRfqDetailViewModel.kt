package com.equipseva.app.features.hospital

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.data.rfq.Rfq
import com.equipseva.app.core.data.rfq.RfqBid
import com.equipseva.app.core.data.rfq.RfqRepository
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.navigation.Routes
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class HospitalRfqDetailViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val rfqRepository: RfqRepository,
) : ViewModel() {

    data class UiState(
        val loading: Boolean = true,
        val refreshing: Boolean = false,
        val rfq: Rfq? = null,
        val bids: List<RfqBid> = emptyList(),
        val errorMessage: String? = null,
    )

    private val rfqId: String = checkNotNull(savedStateHandle[Routes.HOSPITAL_RFQ_DETAIL_ARG_ID])

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init {
        load(initial = true)
    }

    fun onRefresh() = load(initial = false)

    private fun load(initial: Boolean) {
        _state.update { it.copy(loading = initial, refreshing = !initial, errorMessage = null) }
        viewModelScope.launch {
            runCatching {
                coroutineScope {
                    val rfqDeferred = async { rfqRepository.fetchRfqById(rfqId).getOrThrow() }
                    val bidsDeferred = async { rfqRepository.fetchBidsForRfq(rfqId).getOrThrow() }
                    rfqDeferred.await() to bidsDeferred.await()
                }
            }.onSuccess { (rfq, bids) ->
                _state.update {
                    UiState(loading = false, refreshing = false, rfq = rfq, bids = bids)
                }
            }.onFailure { error ->
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
