package com.equipseva.app.features.manufacturer

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.orgroles.OrgRoleRepository
import com.equipseva.app.core.data.profile.ProfileRepository
import com.equipseva.app.core.data.rfq.Rfq
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
class LeadPipelineViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val profileRepository: ProfileRepository,
    private val orgRoleRepository: OrgRoleRepository,
    private val rfqRepository: RfqRepository,
) : ViewModel() {

    data class LeadRow(val bid: RfqBid, val rfq: Rfq?)

    data class UiState(
        val loading: Boolean = true,
        val refreshing: Boolean = false,
        val rows: List<LeadRow> = emptyList(),
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
            it.copy(loading = initial, refreshing = !initial, errorMessage = null, noManufacturerWarning = false)
        }
        viewModelScope.launch {
            val orgId = profileRepository.fetchById(uid).getOrNull()?.organizationId
            if (orgId.isNullOrBlank()) {
                _state.update {
                    it.copy(
                        loading = false,
                        refreshing = false,
                        rows = emptyList(),
                        noManufacturerWarning = true,
                    )
                }
                return@launch
            }
            val manufacturerId = orgRoleRepository.manufacturerIdForOrg(orgId).getOrNull()
            if (manufacturerId.isNullOrBlank()) {
                _state.update {
                    it.copy(
                        loading = false,
                        refreshing = false,
                        rows = emptyList(),
                        noManufacturerWarning = true,
                    )
                }
                return@launch
            }
            rfqRepository.fetchBidsByManufacturer(manufacturerId)
                .onSuccess { bids ->
                    val rfqIds = bids.map { it.rfqId }.toSet()
                    val rfqsById = if (rfqIds.isEmpty()) emptyMap()
                    else rfqRepository.fetchRfqsByIds(rfqIds)
                        .getOrElse { emptyList() }
                        .associateBy { it.id }
                    _state.update {
                        UiState(
                            loading = false,
                            refreshing = false,
                            rows = bids.map { LeadRow(it, rfqsById[it.rfqId]) },
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
