package com.equipseva.app.features.catalog

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Inventory2
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.data.catalog.CatalogRepository
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.EsField
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk900
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
    private val repo: CatalogRepository,
) : ViewModel() {
    data class UiState(
        val query: String = "",
        val brands: List<CatalogRepository.CatalogBrand> = emptyList(),
        val selectedBrandId: String? = null,
        val results: List<CatalogRepository.CatalogDevice> = emptyList(),
        val loading: Boolean = true,
        val error: String? = null,
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    private var searchJob: Job? = null

    init {
        viewModelScope.launch {
            repo.brands().onSuccess { b -> _state.update { it.copy(brands = b) } }
        }
        search(immediate = true)
    }

    fun onQueryChange(q: String) {
        _state.update { it.copy(query = q) }
        search(immediate = false)
    }

    fun onBrandToggle(brandId: String) {
        _state.update {
            it.copy(selectedBrandId = if (it.selectedBrandId == brandId) null else brandId)
        }
        search(immediate = true)
    }

    fun retry() = search(immediate = true)

    private fun search(immediate: Boolean) {
        searchJob?.cancel()
        searchJob = viewModelScope.launch {
            if (!immediate) delay(350) // debounce type-ahead
            _state.update { it.copy(loading = true, error = null) }
            val s = _state.value
            repo.search(query = s.query, brandId = s.selectedBrandId)
                .onSuccess { rows -> _state.update { it.copy(loading = false, results = rows) } }
                .onFailure { e -> _state.update { it.copy(loading = false, error = e.toUserMessage()) } }
        }
    }
}

/**
 * Equipment catalog browse (r1410): a searchable, brand-filterable reference
 * list of medical-equipment devices (generic name, brand, manufacturer,
 * category). Surfaces catalog_devices_search() + catalog_brands_list()
 * (r486 catalog seed), which had no Android screen before. Reachable from
 * Profile (both roles).
 */
@Composable
fun CatalogBrowseScreen(
    onBack: () -> Unit,
    viewModel: CatalogBrowseViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(title = "Equipment catalog", onBack = onBack)
            Column(modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp)) {
                EsField(
                    value = state.query,
                    onChange = viewModel::onQueryChange,
                    placeholder = "Search devices",
                    leading = { Icon(Icons.Outlined.Search, contentDescription = null, tint = SevaInk500) },
                )
                if (state.brands.isNotEmpty()) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .horizontalScroll(rememberScrollState())
                            .padding(top = 8.dp),
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        state.brands.forEach { brand ->
                            FilterChip(
                                selected = state.selectedBrandId == brand.id,
                                onClick = { viewModel.onBrandToggle(brand.id) },
                                label = { Text(brand.name) },
                            )
                        }
                    }
                }
            }
            when {
                state.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }
                state.error != null -> EmptyStateView(
                    icon = Icons.Outlined.Inventory2,
                    title = "Couldn't load catalog",
                    subtitle = state.error,
                    ctaLabel = "Try again",
                    onCta = { viewModel.retry() },
                )
                state.results.isEmpty() -> EmptyStateView(
                    icon = Icons.Outlined.Inventory2,
                    title = "No devices found",
                    subtitle = "Try a different search term or clear the brand filter.",
                )
                else -> LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(12.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    items(state.results, key = { it.id }) { device -> CatalogDeviceRow(device) }
                }
            }
        }
    }
}

@Composable
private fun CatalogDeviceRow(device: CatalogRepository.CatalogDevice) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
            .padding(12.dp),
    ) {
        Text(
            device.genericName.ifBlank { "Device" },
            style = EsType.Body.copy(fontWeight = FontWeight.Medium),
            color = SevaInk900,
        )
        val subtitle = deviceSubtitle(device.brandName, device.manufacturer, device.categoryKey)
        if (subtitle.isNotEmpty()) {
            Text(subtitle, style = EsType.Caption, color = SevaInk500, modifier = Modifier.padding(top = 2.dp))
        }
    }
}

// ---------------------------------------------------------------------
//  Pinned helpers
// ---------------------------------------------------------------------

/** Human label for a category_key; de-snake fallback so a new key never shows raw. */
internal fun categoryKeyLabel(key: String?): String {
    if (key.isNullOrBlank()) return ""
    return key.replace('_', ' ').replaceFirstChar { it.uppercase() }
}

/** Device subtitle: brand · manufacturer · category, omitting blanks. */
internal fun deviceSubtitle(brandName: String?, manufacturer: String?, categoryKey: String?): String =
    listOfNotNull(
        brandName?.takeIf { it.isNotBlank() },
        manufacturer?.takeIf { it.isNotBlank() },
        categoryKeyLabel(categoryKey).takeIf { it.isNotBlank() },
    ).joinToString(" · ")
