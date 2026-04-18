package com.equipseva.app.features.repair

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.data.repair.RepairBid
import com.equipseva.app.core.data.repair.RepairBidRepository
import com.equipseva.app.core.data.repair.RepairBidStatus
import com.equipseva.app.core.data.repair.RepairJob
import com.equipseva.app.core.data.repair.RepairJobRepository
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
class RepairJobDetailViewModel @Inject constructor(
    savedState: SavedStateHandle,
    private val jobRepository: RepairJobRepository,
    private val bidRepository: RepairBidRepository,
) : ViewModel() {

    data class RepairJobDetailUiState(
        val loading: Boolean = true,
        val job: RepairJob? = null,
        val notFound: Boolean = false,
        val errorMessage: String? = null,
        val ownBid: RepairBid? = null,
        val placingBid: Boolean = false,
        val withdrawingBid: Boolean = false,
        val bidComposerOpen: Boolean = false,
    )

    private val jobId: String =
        checkNotNull(savedState.get<String>(Routes.REPAIR_DETAIL_ARG_ID)) {
            "RepairJobDetailViewModel requires arg ${Routes.REPAIR_DETAIL_ARG_ID}"
        }

    private val _state = MutableStateFlow(RepairJobDetailUiState())
    val state: StateFlow<RepairJobDetailUiState> = _state.asStateFlow()

    private val _messages = Channel<String>(Channel.BUFFERED)
    val messages = _messages.receiveAsFlow()

    init {
        load()
    }

    fun retry() = load()

    fun openBidComposer() {
        if (_state.value.job == null) return
        _state.update { it.copy(bidComposerOpen = true) }
    }

    fun closeBidComposer() {
        _state.update { it.copy(bidComposerOpen = false) }
    }

    fun submitBid(amountRupees: Double, etaHours: Int?, note: String?) {
        if (_state.value.placingBid) return
        val hadPending = _state.value.ownBid?.status == RepairBidStatus.Pending
        _state.update { it.copy(placingBid = true) }
        viewModelScope.launch {
            bidRepository.placeBid(
                jobId = jobId,
                amountRupees = amountRupees,
                etaHours = etaHours,
                note = note,
            ).fold(
                onSuccess = { bid ->
                    _state.update {
                        it.copy(
                            ownBid = bid,
                            bidComposerOpen = false,
                            placingBid = false,
                        )
                    }
                    _messages.send(if (hadPending) "Bid updated" else "Bid submitted")
                },
                onFailure = { ex ->
                    _state.update { it.copy(placingBid = false) }
                    _messages.send(ex.toUserMessage())
                },
            )
        }
    }

    fun withdrawBid() {
        val bid = _state.value.ownBid ?: return
        if (bid.status != RepairBidStatus.Pending) return
        if (_state.value.withdrawingBid) return
        _state.update { it.copy(withdrawingBid = true) }
        viewModelScope.launch {
            bidRepository.withdrawBid(bid.id).fold(
                onSuccess = {
                    bidRepository.fetchOwnBidForJob(jobId).fold(
                        onSuccess = { refreshed ->
                            _state.update { it.copy(ownBid = refreshed, withdrawingBid = false) }
                            _messages.send("Bid withdrawn")
                        },
                        onFailure = { ex ->
                            _state.update { it.copy(withdrawingBid = false) }
                            _messages.send(ex.toUserMessage())
                        },
                    )
                },
                onFailure = { ex ->
                    _state.update { it.copy(withdrawingBid = false) }
                    _messages.send(ex.toUserMessage())
                },
            )
        }
    }

    private fun load() {
        _state.update { it.copy(loading = true, errorMessage = null, notFound = false) }
        viewModelScope.launch {
            val jobResult = jobRepository.fetchById(jobId)
            val bidResult = bidRepository.fetchOwnBidForJob(jobId)
            jobResult.fold(
                onSuccess = { job ->
                    _state.update {
                        it.copy(
                            loading = false,
                            job = job,
                            notFound = job == null,
                            ownBid = bidResult.getOrNull(),
                        )
                    }
                },
                onFailure = { ex ->
                    _state.update {
                        it.copy(
                            loading = false,
                            errorMessage = ex.toUserMessage(),
                        )
                    }
                },
            )
        }
    }
}
