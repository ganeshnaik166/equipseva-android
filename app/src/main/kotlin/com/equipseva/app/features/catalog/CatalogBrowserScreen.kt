package com.equipseva.app.features.catalog

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.RequestQuote
import androidx.compose.material.icons.outlined.Inbox
import androidx.compose.material.icons.outlined.LocalOffer
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import coil3.compose.AsyncImage
import com.equipseva.app.core.data.catalog.CatalogRepository
import com.equipseva.app.designsystem.components.ESBackTopBar
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.theme.AccentLimeSoft
import com.equipseva.app.designsystem.theme.BrandGreen
import com.equipseva.app.designsystem.theme.BrandGreenDeep
import com.equipseva.app.designsystem.theme.Ink500
import com.equipseva.app.designsystem.theme.Ink700
import com.equipseva.app.designsystem.theme.Ink900
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.designsystem.theme.Surface0
import com.equipseva.app.designsystem.theme.Surface200
import com.equipseva.app.designsystem.theme.Surface50
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.FlowPreview
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.debounce
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.drop
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

private const val PAGE_SIZE = 50
private const val DEBOUNCE_MS = 300L

@OptIn(FlowPreview::class)
@HiltViewModel
class CatalogBrowserViewModel @Inject constructor(
    private val repo: CatalogRepository,
) : ViewModel() {
    data class UiState(
        val loading: Boolean = true,
        val error: String? = null,
        val query: String = "",
        val brands: List<CatalogRepository.CatalogBrand> = emptyList(),
        val selectedBrandId: String? = null,
        val rows: List<CatalogRepository.CatalogDevice> = emptyList(),
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init {
        viewModelScope.launch {
            repo.brands().onSuccess { _state.update { it.copy(brands = it.brands + emptyList()) } }
            // Refresh: do brand fetch + first page in parallel.
        }
        viewModelScope.launch {
            repo.brands().onSuccess { brands ->
                _state.update { it.copy(brands = brands.take(40)) }
            }
        }
        refresh()
        _state
            .map { it.query to it.selectedBrandId }
            .distinctUntilChanged()
            .drop(1)
            .debounce(DEBOUNCE_MS)
            .onEach { refresh() }
            .launchIn(viewModelScope)
    }

    fun onQueryChange(v: String) = _state.update { it.copy(query = v) }
    fun onBrandSelected(id: String?) = _state.update {
        it.copy(selectedBrandId = if (it.selectedBrandId == id) null else id)
    }

    private fun refresh() {
        _state.update { it.copy(loading = true, error = null) }
        viewModelScope.launch {
            val s = _state.value
            repo.search(query = s.query.takeIf { it.isNotBlank() }, brandId = s.selectedBrandId, limit = PAGE_SIZE)
                .onSuccess { rows -> _state.update { it.copy(loading = false, rows = rows) } }
                .onFailure { e -> _state.update { it.copy(loading = false, error = e.message ?: "Failed to load") } }
        }
    }
}

@Composable
fun CatalogBrowserScreen(
    onBack: () -> Unit,
    onRequestQuote: (deviceName: String, brandName: String?) -> Unit,
    viewModel: CatalogBrowserViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsState()
    Scaffold(topBar = { ESBackTopBar(title = "Browse 5,000+ devices", onBack = onBack) }) { padding ->
        Column(modifier = Modifier.fillMaxSize().padding(padding).background(Surface50)) {
            OutlinedTextField(
                value = state.query,
                onValueChange = viewModel::onQueryChange,
                placeholder = { Text("Search by name, brand, manufacturer…") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth().padding(Spacing.md),
            )
            // Brand filter chips.
            if (state.brands.isNotEmpty()) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .horizontalScroll(rememberScrollState())
                        .padding(horizontal = Spacing.md),
                    horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
                ) {
                    state.brands.forEach { b ->
                        BrandChip(
                            brand = b,
                            selected = state.selectedBrandId == b.id,
                            onClick = { viewModel.onBrandSelected(b.id) },
                        )
                    }
                }
            }
            Box(modifier = Modifier.fillMaxSize()) {
                when {
                    state.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator()
                    }
                    state.error != null && state.rows.isEmpty() -> EmptyStateView(
                        icon = Icons.Outlined.Inbox,
                        title = "Couldn't load",
                        subtitle = state.error,
                    )
                    state.rows.isEmpty() -> EmptyStateView(
                        icon = Icons.Outlined.Inbox,
                        title = "No matches",
                        subtitle = "Adjust the search or brand filter.",
                    )
                    else -> LazyColumn(
                        contentPadding = PaddingValues(Spacing.md),
                        verticalArrangement = Arrangement.spacedBy(Spacing.sm),
                    ) {
                        items(state.rows, key = { it.id }) { row ->
                            DeviceRowCard(
                                row = row,
                                onRequestQuote = { onRequestQuote(row.genericName, row.brandName) },
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun BrandChip(
    brand: CatalogRepository.CatalogBrand,
    selected: Boolean,
    onClick: () -> Unit,
) {
    Row(
        modifier = Modifier
            .height(34.dp)
            .clip(RoundedCornerShape(50))
            .background(if (selected) BrandGreen else Surface0)
            .border(1.dp, if (selected) BrandGreen else Surface200, RoundedCornerShape(50))
            .clickable(onClick = onClick)
            .padding(horizontal = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Text(
            brand.name.take(28),
            color = if (selected) Surface0 else Ink900,
            fontSize = 12.sp,
            fontWeight = FontWeight.SemiBold,
        )
        Text(
            "(${brand.manufacturerCount})",
            color = if (selected) Surface0.copy(alpha = 0.85f) else Ink500,
            fontSize = 11.sp,
        )
    }
}

@Composable
private fun DeviceRowCard(
    row: CatalogRepository.CatalogDevice,
    onRequestQuote: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(Surface0)
            .border(1.dp, Surface200, RoundedCornerShape(14.dp))
            .padding(Spacing.md),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.Top,
    ) {
        Box(
            modifier = Modifier
                .size(64.dp)
                .clip(RoundedCornerShape(10.dp))
                .background(Surface50)
                .border(1.dp, Surface200, RoundedCornerShape(10.dp)),
            contentAlignment = Alignment.Center,
        ) {
            val img = row.imageUrl
            if (!img.isNullOrBlank()) {
                AsyncImage(
                    model = img,
                    contentDescription = null,
                    modifier = Modifier.fillMaxSize(),
                    contentScale = androidx.compose.ui.layout.ContentScale.Crop,
                )
            } else {
                Icon(Icons.Outlined.LocalOffer, contentDescription = null, tint = Ink500)
            }
        }
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(row.genericName, color = Ink900, fontWeight = FontWeight.Bold, fontSize = 14.sp)
            row.brandName?.takeIf { it.isNotBlank() }?.let {
                Text(it, color = Ink700, fontSize = 12.sp)
            }
            row.manufacturer?.takeIf { it.isNotBlank() && it != row.brandName }?.let {
                Text("by $it", color = Ink500, fontSize = 11.sp)
            }
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(50))
                    .background(AccentLimeSoft)
                    .padding(horizontal = 10.dp, vertical = 3.dp),
            ) {
                Text("Request a quote", color = BrandGreenDeep, fontSize = 11.sp, fontWeight = FontWeight.Bold)
            }
            Button(
                onClick = onRequestQuote,
                modifier = Modifier.fillMaxWidth().padding(top = 4.dp),
            ) {
                Icon(Icons.Filled.RequestQuote, contentDescription = null, modifier = Modifier.size(16.dp))
                Text("Request quote", modifier = Modifier.padding(start = 6.dp), fontSize = 13.sp)
            }
        }
    }
}
