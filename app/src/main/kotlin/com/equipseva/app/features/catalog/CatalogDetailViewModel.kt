package com.equipseva.app.features.catalog

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.data.catalog.CatalogReferenceRepository
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.navigation.Routes
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

@HiltViewModel
class CatalogDetailViewModel @Inject constructor(
    private val repo: CatalogReferenceRepository,
    savedStateHandle: SavedStateHandle,
) : ViewModel() {

    data class UiState(
        val loading: Boolean = true,
        val item: CatalogReferenceRepository.Item? = null,
        val error: String? = null,
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    private val itemId: Int = savedStateHandle.get<String>(Routes.CATALOG_DETAIL_ARG_ID)
        ?.toIntOrNull() ?: -1

    init {
        if (itemId <= 0) {
            _state.update { it.copy(loading = false, error = "Invalid catalogue id") }
        } else {
            load()
        }
    }

    fun load() {
        _state.update { it.copy(loading = true, error = null) }
        viewModelScope.launch {
            repo.fetchById(itemId)
                .onSuccess { item ->
                    _state.update {
                        it.copy(
                            loading = false,
                            item = item,
                            error = if (item == null) "Catalog item not found" else null,
                        )
                    }
                }
                .onFailure { ex ->
                    _state.update { it.copy(loading = false, error = ex.toUserMessage()) }
                }
        }
    }
}
