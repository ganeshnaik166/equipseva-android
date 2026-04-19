package com.equipseva.app.features.marketplace

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.data.cart.CartRepository
import com.equipseva.app.core.data.parts.SparePart
import com.equipseva.app.core.data.parts.SparePartsRepository
import com.equipseva.app.core.data.prefs.UserPrefs
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.features.cart.CartBridge
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
class PartDetailViewModel @Inject constructor(
    savedState: SavedStateHandle,
    private val repository: SparePartsRepository,
    private val cartRepository: CartRepository,
    private val userPrefs: UserPrefs,
) : ViewModel() {

    data class PartDetailState(
        val loading: Boolean = true,
        val part: SparePart? = null,
        val errorMessage: String? = null,
        val notFound: Boolean = false,
        val addingToCart: Boolean = false,
        val isFavorite: Boolean = false,
    )

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
                },
                onFailure = { ex ->
                    _state.update { it.copy(loading = false, errorMessage = ex.toUserMessage()) }
                },
            )
        }
    }
}
