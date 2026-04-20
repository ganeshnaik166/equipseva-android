package com.equipseva.app.features.manufacturer

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.orgroles.OrgRoleRepository
import com.equipseva.app.core.data.profile.ProfileRepository
import com.equipseva.app.core.data.rfq.RfqBid
import com.equipseva.app.core.data.rfq.RfqRepository
import com.equipseva.app.core.network.toUserMessage
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.distinctUntilChangedBy
import kotlinx.coroutines.flow.filterIsInstance
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class AnalyticsViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val profileRepository: ProfileRepository,
    private val orgRoleRepository: OrgRoleRepository,
    private val rfqRepository: RfqRepository,
) : ViewModel() {

    data class UiState(
        val loading: Boolean = true,
        val bidsSubmitted: Int = 0,
        val bidsAwarded: Int = 0,
        val bidsOpen: Int = 0,
        val winRatePercent: Int = 0,
        val pipelineValueRupees: Double = 0.0,
        val awardedValueRupees: Double = 0.0,
        val errorMessage: String? = null,
        val noManufacturerWarning: Boolean = false,
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

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

    private fun load(initial: Boolean) {
        val uid = userId ?: return
        _state.update {
            it.copy(
                loading = initial,
                errorMessage = null, noManufacturerWarning = false,
            )
        }
        viewModelScope.launch {
            val orgId = profileRepository.fetchById(uid).getOrNull()?.organizationId
            if (orgId.isNullOrBlank()) {
                _state.update { it.copy(loading = false, noManufacturerWarning = true) }
                return@launch
            }
            val manufacturerId = orgRoleRepository.manufacturerIdForOrg(orgId).getOrNull()
            if (manufacturerId.isNullOrBlank()) {
                _state.update { it.copy(loading = false, noManufacturerWarning = true) }
                return@launch
            }
            rfqRepository.fetchBidsByManufacturer(manufacturerId)
                .onSuccess { bids ->
                    val totals = summarize(bids)
                    _state.update { totals.copy(loading = false) }
                }
                .onFailure { error ->
                    _state.update {
                        it.copy(
                            loading = false,
                            errorMessage = error.toUserMessage(),
                        )
                    }
                }
        }
    }

    private fun summarize(bids: List<RfqBid>): UiState {
        val awarded = bids.filter { it.status.equals("awarded", true) || it.status.equals("accepted", true) }
        val open = bids.filter {
            val s = it.status.lowercase()
            s == "submitted" || s == "pending" || s == "shortlisted"
        }
        val winRate = if (bids.isEmpty()) 0
        else ((awarded.size.toDouble() / bids.size) * 100).toInt().coerceIn(0, 100)
        return UiState(
            bidsSubmitted = bids.size,
            bidsAwarded = awarded.size,
            bidsOpen = open.size,
            winRatePercent = winRate,
            pipelineValueRupees = open.sumOf { it.totalPriceRupees },
            awardedValueRupees = awarded.sumOf { it.totalPriceRupees },
        )
    }
}
