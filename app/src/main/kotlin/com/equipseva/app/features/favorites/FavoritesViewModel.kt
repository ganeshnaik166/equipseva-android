package com.equipseva.app.features.favorites

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.data.parts.SparePart
import com.equipseva.app.core.data.parts.SparePartsRepository
import com.equipseva.app.core.data.prefs.UserPrefs
import com.equipseva.app.core.network.toUserMessage
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class FavoritesViewModel @Inject constructor(
    private val repository: SparePartsRepository,
    private val userPrefs: UserPrefs,
) : ViewModel() {

    data class FavoritesState(
        val loading: Boolean = true,
        val items: List<SparePart> = emptyList(),
        val errorMessage: String? = null,
    )

    private val _state = MutableStateFlow(FavoritesState())
    val state: StateFlow<FavoritesState> = _state.asStateFlow()

    private val _removedEvents = Channel<String>(capacity = Channel.BUFFERED)
    val removedEvents = _removedEvents.receiveAsFlow()

    init {
        viewModelScope.launch {
            userPrefs.favorites
                .distinctUntilChanged()
                .collect { ids -> reload(ids) }
        }
    }

    fun onRemove(partId: String) {
        viewModelScope.launch {
            userPrefs.toggleFavorite(partId)
            _removedEvents.send(partId)
        }
    }

    fun undoRemove(partId: String) {
        viewModelScope.launch { userPrefs.toggleFavorite(partId) }
    }

    private suspend fun reload(ids: Set<String>) {
        if (ids.isEmpty()) {
            _state.update { it.copy(loading = false, items = emptyList(), errorMessage = null) }
            return
        }
        _state.update { it.copy(loading = true, errorMessage = null) }
        val collected = mutableListOf<SparePart>()
        var firstError: String? = null
        ids.forEach { id ->
            repository.fetchById(id).fold(
                onSuccess = { part -> if (part != null) collected.add(part) },
                onFailure = { ex ->
                    if (firstError == null) firstError = ex.toUserMessage()
                },
            )
        }
        _state.update {
            it.copy(
                loading = false,
                items = collected.sortedBy { p -> p.name },
                errorMessage = firstError,
            )
        }
    }
}
