package com.equipseva.app.features.supplier

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.parts.SparePart
import com.equipseva.app.core.data.parts.SparePartsRepository
import com.equipseva.app.core.data.profile.ProfileRepository
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
class StockAlertsViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val profileRepository: ProfileRepository,
    private val partsRepository: SparePartsRepository,
) : ViewModel() {

    data class UiState(
        val loading: Boolean = true,
        val refreshing: Boolean = false,
        val outOfStock: List<SparePart> = emptyList(),
        val lowStock: List<SparePart> = emptyList(),
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
                        outOfStock = emptyList(),
                        lowStock = emptyList(),
                        noOrgWarning = true,
                    )
                }
                return@launch
            }
            partsRepository.fetchLowStockBySupplier(orgId, threshold = 5)
                .onSuccess { parts ->
                    val (out, low) = parts.partition { it.stockQuantity <= 0 }
                    _state.update {
                        UiState(
                            loading = false,
                            refreshing = false,
                            outOfStock = out,
                            lowStock = low,
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
