package com.equipseva.app.features.catalog

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.data.catalog.CatalogReferenceRepository
import com.equipseva.app.core.network.toUserMessage
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

@HiltViewModel
class CatalogBrowseViewModel @Inject constructor(
    private val repo: CatalogReferenceRepository,
) : ViewModel() {

    data class UiState(
        val query: String = "",
        val category: String? = null,
        val items: List<CatalogReferenceRepository.Item> = emptyList(),
        val loading: Boolean = true,
        val error: String? = null,
        val categories: List<String> = emptyList(),
    )

    private val _state = MutableStateFlow(UiState(categories = repo.categories()))
    val state: StateFlow<UiState> = _state.asStateFlow()

    private var loadJob: Job? = null

    init {
        reload()
    }

    fun onQueryChange(value: String) {
        _state.update { it.copy(query = value) }
        // 250 ms debounce so we don't hit Supabase on every keystroke.
        loadJob?.cancel()
        loadJob = viewModelScope.launch {
            delay(250)
            reload()
        }
    }

    fun onCategoryChange(value: String?) {
        _state.update { it.copy(category = value) }
        reload()
    }

    fun reload() {
        loadJob?.cancel()
        loadJob = viewModelScope.launch {
            _state.update { it.copy(loading = true, error = null) }
            val s = _state.value
            repo.search(query = s.query, category = s.category, limit = 100)
                .onSuccess { rows -> _state.update { it.copy(loading = false, items = rows) } }
                .onFailure { ex -> _state.update { it.copy(loading = false, error = ex.toUserMessage()) } }
        }
    }
}
