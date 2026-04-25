package com.equipseva.app.features.marketplace

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.cart.CartRepository
import com.equipseva.app.core.data.moderation.ContentReportReason
import com.equipseva.app.core.data.moderation.ContentReportRepository
import com.equipseva.app.core.data.moderation.ContentReportTarget
import com.equipseva.app.core.data.parts.SparePart
import com.equipseva.app.core.data.parts.SparePartsRepository
import com.equipseva.app.core.data.prefs.UserPrefs
import com.equipseva.app.core.data.profile.ProfileRepository
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.features.cart.CartBridge
import com.equipseva.app.navigation.Routes
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.filterIsInstance
import kotlinx.coroutines.flow.firstOrNull
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class PartDetailViewModel @Inject constructor(
    savedState: SavedStateHandle,
    private val repository: SparePartsRepository,
    private val cartRepository: CartRepository,
    private val userPrefs: UserPrefs,
    private val authRepository: AuthRepository,
    private val profileRepository: ProfileRepository,
    private val reportRepository: ContentReportRepository,
) : ViewModel() {

    data class PartDetailState(
        val loading: Boolean = true,
        val part: SparePart? = null,
        val errorMessage: String? = null,
        val notFound: Boolean = false,
        val addingToCart: Boolean = false,
        val isFavorite: Boolean = false,
        /** Org id of the signed-in user — used to hide the report CTA on own listings. */
        val selfOrgId: String? = null,
        /** Part id whose report sheet is open, null when sheet closed. */
        val reportingTargetId: String? = null,
        val submittingReport: Boolean = false,
    ) {
        /** Hide the report button if the listing belongs to the viewer's org. */
        val canReport: Boolean
            get() {
                val supplier = part?.supplierOrgId ?: return part != null
                return selfOrgId == null || selfOrgId != supplier
            }
    }

    private val partId: String =
        checkNotNull(savedState.get<String>(Routes.MARKETPLACE_DETAIL_ARG_ID)) {
            "PartDetailViewModel requires arg ${Routes.MARKETPLACE_DETAIL_ARG_ID}"
        }

    private val _state = MutableStateFlow(PartDetailState())
    val state: StateFlow<PartDetailState> = _state.asStateFlow()

    private val _messages = Channel<String>(Channel.BUFFERED)
    val messages = _messages.receiveAsFlow()

    init {
        load()
        viewModelScope.launch {
            userPrefs.favorites.collect { favs ->
                _state.update { it.copy(isFavorite = partId in favs) }
            }
        }
        viewModelScope.launch {
            val session = authRepository.sessionState
                .filterIsInstance<AuthSession.SignedIn>()
                .firstOrNull()
            val orgId = session?.userId
                ?.let { profileRepository.fetchById(it).getOrNull()?.organizationId }
            _state.update { it.copy(selfOrgId = orgId) }
        }
    }

    fun onOpenReport() {
        val part = _state.value.part ?: return
        if (!_state.value.canReport) return
        _state.update { it.copy(reportingTargetId = part.id) }
    }

    fun onDismissReport() {
        if (_state.value.submittingReport) return
        _state.update { it.copy(reportingTargetId = null) }
    }

    fun onSubmitReport(reason: ContentReportReason, notes: String?) {
        val id = _state.value.reportingTargetId ?: return
        if (_state.value.submittingReport) return
        _state.update { it.copy(submittingReport = true) }
        viewModelScope.launch {
            reportRepository.submitReport(
                target = ContentReportTarget.PartListing,
                targetId = id,
                reason = reason,
                notes = notes,
            ).onSuccess {
                _state.update { it.copy(submittingReport = false, reportingTargetId = null) }
                _messages.send("Thanks — our team will review this.")
            }.onFailure { err ->
                _state.update { it.copy(submittingReport = false) }
                _messages.send(err.toUserMessage())
            }
        }
    }

    fun retry() = load()

    fun onToggleFavorite() {
        viewModelScope.launch { userPrefs.toggleFavorite(partId) }
    }

    fun onAddToCart() {
        val part = _state.value.part ?: return
        if (_state.value.addingToCart) return
        _state.update { it.copy(addingToCart = true) }
        viewModelScope.launch {
            cartRepository.addOrIncrement(CartBridge.buildCartItem(part))
                .onSuccess { _messages.send("${part.name} added to cart") }
                .onFailure { _messages.send(it.toUserMessage()) }
            _state.update { it.copy(addingToCart = false) }
        }
    }

    private fun load() {
        _state.update { it.copy(loading = true, errorMessage = null, notFound = false) }
        viewModelScope.launch {
            repository.fetchById(partId).fold(
                onSuccess = { part ->
                    _state.update {
                        it.copy(
                            loading = false,
                            part = part,
                            notFound = part == null,
                        )
                    }
                    if (part != null) userPrefs.addRecentlyViewedPart(part.id)
                },
                onFailure = { ex ->
                    _state.update { it.copy(loading = false, errorMessage = ex.toUserMessage()) }
                },
            )
        }
    }
}
