package com.equipseva.app.features.marketplace

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.data.cart.CartRepository
import com.equipseva.app.core.data.parts.MarketplaceSort
import com.equipseva.app.core.data.parts.PartCategory
import com.equipseva.app.core.data.parts.SparePartsRepository
import com.equipseva.app.core.data.prefs.UserPrefs
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.features.marketplace.state.MarketplaceUiState
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.FlowPreview
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.debounce
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.drop
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

private const val PAGE_SIZE = 20
private const val SEARCH_DEBOUNCE_MS = 300L

@OptIn(FlowPreview::class)
@HiltViewModel
class MarketplaceViewModel @Inject constructor(
    private val repository: SparePartsRepository,
    cartRepository: CartRepository,
    private val userPrefs: UserPrefs,
) : ViewModel() {

    private val _state = MutableStateFlow(MarketplaceUiState())
    val state: StateFlow<MarketplaceUiState> = _state.asStateFlow()

    val cartCount: StateFlow<Int> = cartRepository.observeCount()
        .stateIn(viewModelScope, SharingStarted.Eagerly, 0)

    val favorites: StateFlow<Set<String>> = userPrefs.favorites
        .stateIn(viewModelScope, SharingStarted.Eagerly, emptySet())

    fun onToggleFavorite(partId: String) {
        viewModelScope.launch { userPrefs.toggleFavorite(partId) }
    }

    /** Tracks the in-flight query/category combination so stale results get dropped. */
    private var pageJob: Job? = null

    init {
        // First page on creation.
        refresh()

        // Re-query whenever the typed query stabilises. We drop the very first emission
        // because `init { refresh() }` already kicked off the empty-query fetch.
        _state
            .map { it.query }
            .distinctUntilChanged()
            .drop(1)
            .debounce(SEARCH_DEBOUNCE_MS)
            .onEach { refresh() }
            .launchIn(viewModelScope)
    }

    fun onQueryChange(value: String) {
        _state.update { it.copy(query = value, errorMessage = null) }
    }

    fun onCategorySelected(category: PartCategory?) {
        if (_state.value.selectedCategory == category) return
        _state.update { it.copy(selectedCategory = category, errorMessage = null) }
        refresh()
    }

    fun onSortSelected(sort: MarketplaceSort) {
        if (_state.value.sort == sort) return
        _state.update { it.copy(sort = sort, errorMessage = null) }
        refresh()
    }

    fun onRefresh() = refresh(viaPullToRefresh = true)

    fun onReachEnd() {
        val current = _state.value
        if (current.loadingMore || current.refreshing || current.initialLoading || current.endReached) return
        loadNext(page = current.items.size / PAGE_SIZE)
    }

    private fun refresh(viaPullToRefresh: Boolean = false) {
        pageJob?.cancel()
        _state.update {
            it.copy(
                initialLoading = it.items.isEmpty() && !viaPullToRefresh,
                refreshing = viaPullToRefresh,
                endReached = false,
                errorMessage = null,
            )
        }
        pageJob = viewModelScope.launch {
            val current = _state.value
            repository.fetchAvailable(
                query = current.query,
                category = current.selectedCategory,
                sort = current.sort,
                page = 0,
                pageSize = PAGE_SIZE,
            ).fold(
                onSuccess = { rows ->
                    _state.update {
                        it.copy(
                            items = rows,
                            initialLoading = false,
                            refreshing = false,
                            endReached = rows.size < PAGE_SIZE,
                        )
                    }
                },
                onFailure = { ex ->
                    _state.update {
                        it.copy(
                            initialLoading = false,
                            refreshing = false,
                            errorMessage = ex.toUserMessage(),
                        )
                    }
                },
            )
        }
    }

    private fun loadNext(page: Int) {
        pageJob?.cancel()
        _state.update { it.copy(loadingMore = true, errorMessage = null) }
        pageJob = viewModelScope.launch {
            val current = _state.value
            repository.fetchAvailable(
                query = current.query,
                category = current.selectedCategory,
                sort = current.sort,
                page = page,
                pageSize = PAGE_SIZE,
            ).fold(
                onSuccess = { rows ->
                    _state.update {
                        it.copy(
                            items = it.items + rows,
                            loadingMore = false,
                            endReached = rows.size < PAGE_SIZE,
                        )
                    }
                },
                onFailure = { ex ->
                    _state.update {
                        it.copy(
                            loadingMore = false,
                            errorMessage = ex.toUserMessage(),
                        )
                    }
                },
            )
        }
    }
}
