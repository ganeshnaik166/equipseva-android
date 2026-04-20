package com.equipseva.app.features.manufacturer

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.orgroles.OrgRoleRepository
import com.equipseva.app.core.data.profile.ProfileRepository
import com.equipseva.app.core.data.rfq.Rfq
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
class RfqsAssignedViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val profileRepository: ProfileRepository,
    private val orgRoleRepository: OrgRoleRepository,
    private val rfqRepository: RfqRepository,
) : ViewModel() {

    data class UiState(
        val loading: Boolean = true,
        val refreshing: Boolean = false,
        val targeted: List<Rfq> = emptyList(),
        val other: List<Rfq> = emptyList(),
        val errorMessage: String? = null,
        val noOrgWarning: Boolean = false,
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
            it.copy(loading = initial, refreshing = !initial, errorMessage = null, noOrgWarning = false)
        }
        viewModelScope.launch {
            val orgId = profileRepository.fetchById(uid).getOrNull()?.organizationId
            if (orgId.isNullOrBlank()) {
                _state.update {
                    it.copy(
                        loading = false,
                        refreshing = false,
                        targeted = emptyList(),
                        other = emptyList(),
                        noOrgWarning = true,
                    )
                }
                return@launch
            }
            val categories = orgRoleRepository.manufacturerCategoriesForOrg(orgId).getOrDefault(emptyList())
            rfqRepository.fetchOpen()
                .onSuccess { rfqs ->
                    val normalized = categories.map { it.lowercase().trim() }
                    val targeted = if (normalized.isEmpty()) emptyList() else rfqs.filter { rfq ->
                        rfq.equipmentCategory?.lowercase()?.trim() in normalized
                    }
                    val other = rfqs.filterNot { it in targeted }
                    _state.update {
                        UiState(
                            loading = false,
                            refreshing = false,
                            targeted = targeted,
                            other = other,
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
