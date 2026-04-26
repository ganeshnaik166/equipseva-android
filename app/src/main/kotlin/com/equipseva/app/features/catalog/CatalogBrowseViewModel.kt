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
        val type: String? = null,
        val items: List<CatalogReferenceRepository.Item> = emptyList(),
        val loading: Boolean = true,            // initial / first-page load
        val loadingMore: Boolean = false,       // appending another page
        val endReached: Boolean = false,        // last page fetched returned <PAGE_SIZE
        val error: String? = null,
        val categories: List<String> = emptyList(),
        val types: List<String> = emptyList(),
        val totalLoaded: Int = 0,               // items.size for cheap UI display
    )

    private val _state = MutableStateFlow(
        UiState(categories = repo.categories(), types = repo.types())
    )
    val state: StateFlow<UiState> = _state.asStateFlow()

    private var loadJob: Job? = null

    private companion object {
        const val PAGE_SIZE = 60

        /** Page-size for the OpenFDA fallback. 25 keeps the response under
         *  ~50 KB on a typical query. */
        const val OPENFDA_LIMIT = 25
    }

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

    fun onTypeChange(value: String?) {
        _state.update { it.copy(type = value) }
        reload()
    }

    /** Re-fetches the first page (resets pagination). Used by query / category changes. */
    fun reload() {
        loadJob?.cancel()
        loadJob = viewModelScope.launch {
            _state.update {
                it.copy(loading = true, loadingMore = false, endReached = false, error = null, items = emptyList(), totalLoaded = 0)
            }
            val s = _state.value
            repo.search(query = s.query, category = s.category, type = s.type, limit = PAGE_SIZE, offset = 0)
                .onSuccess { rows ->
                    _state.update {
                        it.copy(
                            loading = false,
                            items = rows,
                            totalLoaded = rows.size,
                            endReached = rows.size < PAGE_SIZE,
                        )
                    }
                    // Long-tail fallback: when the user types a query we
                    // always pull live results from OpenFDA and append them
                    // below the local rows. Skipped when the user is just
                    // browsing (no query) or has a category/type filter
                    // active (those are local-only). Earlier we gated this
                    // on local hits being thin (<10) but a query like
                    // "pacemaker" has 38 local + 7,492 FDA, so users were
                    // missing the long tail.
                    if (s.query.isNotBlank() &&
                        s.category == null &&
                        s.type == null
                    ) {
                        repo.searchOpenFda(query = s.query, limit = OPENFDA_LIMIT)
                            .onSuccess { remote ->
                                if (remote.isNotEmpty()) {
                                    _state.update { st ->
                                        // Dedupe by UDI so the same device
                                        // doesn't show twice when it's both
                                        // in our Supabase sample + FDA's
                                        // current dump.
                                        val existingUdis = st.items.mapNotNull { it.udi }.toSet()
                                        val merged = st.items + remote.filter { it.udi !in existingUdis }
                                        st.copy(
                                            items = merged,
                                            totalLoaded = merged.size,
                                            endReached = true, // OpenFDA is single-shot, no infinite scroll
                                        )
                                    }
                                }
                            }
                    }
                }
                .onFailure { ex ->
                    _state.update { it.copy(loading = false, error = ex.toUserMessage()) }
                }
        }
    }

    /** Append the next page when the user scrolls near the end of the list. No-op if a load
     *  is already in flight or the previous page was short (we hit the end). */
    fun loadMore() {
        val s = _state.value
        if (s.loading || s.loadingMore || s.endReached) return
        loadJob?.cancel()
        loadJob = viewModelScope.launch {
            _state.update { it.copy(loadingMore = true, error = null) }
            val offset = _state.value.items.size
            repo.search(query = s.query, category = s.category, type = s.type, limit = PAGE_SIZE, offset = offset)
                .onSuccess { rows ->
                    _state.update {
                        val merged = it.items + rows
                        it.copy(
                            loadingMore = false,
                            items = merged,
                            totalLoaded = merged.size,
                            endReached = rows.size < PAGE_SIZE,
                        )
                    }
                }
                .onFailure { ex ->
                    _state.update { it.copy(loadingMore = false, error = ex.toUserMessage()) }
                }
        }
    }
}
