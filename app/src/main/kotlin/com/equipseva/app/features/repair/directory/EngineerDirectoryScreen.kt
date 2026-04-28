package com.equipseva.app.features.repair.directory

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Engineering
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.Verified
import androidx.compose.material.icons.outlined.Inbox
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import coil3.compose.AsyncImage
import com.equipseva.app.core.data.engineers.EngineerDirectoryRepository
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.EsBtn
import com.equipseva.app.designsystem.components.EsBtnKind
import com.equipseva.app.designsystem.components.EsChip
import com.equipseva.app.designsystem.components.EsField
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.Paper2
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaGlowRaw
import com.equipseva.app.designsystem.theme.SevaGreen50
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaGreen900
import com.equipseva.app.designsystem.theme.SevaInk400
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk600
import com.equipseva.app.designsystem.theme.SevaInk700
import com.equipseva.app.designsystem.theme.SevaInk900
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

@OptIn(FlowPreview::class)
@HiltViewModel
class EngineerDirectoryViewModel @Inject constructor(
    private val repo: EngineerDirectoryRepository,
) : ViewModel() {
    data class UiState(
        val loading: Boolean = true,
        val error: String? = null,
        val query: String = "",
        val district: String = "All",
        val rows: List<EngineerDirectoryRepository.DirectoryRow> = emptyList(),
    ) {
        val filteredRows: List<EngineerDirectoryRepository.DirectoryRow>
            get() = if (district == "All") rows
            else rows.filter { it.city?.equals(district, ignoreCase = true) == true }
    }

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init {
        refresh()
        _state
            .map { it.query }
            .distinctUntilChanged()
            .drop(1)
            .debounce(300L)
            .onEach { refresh() }
            .launchIn(viewModelScope)
    }

    fun onQueryChange(v: String) = _state.update { it.copy(query = v) }
    fun onDistrictChange(d: String) = _state.update { it.copy(district = d) }

    private fun refresh() {
        _state.update { it.copy(loading = true, error = null) }
        viewModelScope.launch {
            repo.search(query = _state.value.query.takeIf { it.isNotBlank() })
                .onSuccess { rows -> _state.update { it.copy(loading = false, rows = rows) } }
                .onFailure { e -> _state.update { it.copy(loading = false, error = e.toUserMessage()) } }
        }
    }
}

// Telangana districts the design's directory chip row enumerates. Real
// list will come from the engineers' city values once the founder
// onboards more than the seed cities; for now this matches the design.
private val DEFAULT_DISTRICTS = listOf(
    "All",
    "Hyderabad",
    "Nalgonda",
    "Warangal",
    "Khammam",
    "Karimnagar",
    "Mahbubnagar",
    "Nizamabad",
)

@Composable
fun EngineerDirectoryScreen(
    onBack: () -> Unit,
    onOpenProfile: (engineerId: String) -> Unit,
    onAnyEngineer: () -> Unit,
    viewModel: EngineerDirectoryViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsState()
    val visibleRows = state.filteredRows
    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(
                title = "Find an engineer",
                subtitle = "${visibleRows.size} verified · near ${state.district}",
                onBack = onBack,
            )
            // Sticky search + district chip strip
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(PaperDefault)
                    .padding(horizontal = 16.dp, vertical = 8.dp),
            ) {
                EsField(
                    value = state.query,
                    onChange = viewModel::onQueryChange,
                    placeholder = "Search by name, brand, district…",
                    leading = {
                        Icon(Icons.Filled.Search, contentDescription = null, tint = SevaInk500, modifier = Modifier.size(18.dp))
                    },
                )
                Spacer(Modifier.height(10.dp))
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .horizontalScroll(rememberScrollState()),
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    DEFAULT_DISTRICTS.forEach { d ->
                        EsChip(
                            text = d,
                            active = state.district == d,
                            onClick = { viewModel.onDistrictChange(d) },
                        )
                    }
                }
                Spacer(Modifier.height(10.dp))
                EsBtn(
                    text = "Skip comparison — request from any verified engineer",
                    onClick = onAnyEngineer,
                    kind = EsBtnKind.Secondary,
                    full = true,
                    leading = {
                        Icon(
                            Icons.Filled.Engineering,
                            contentDescription = null,
                            tint = SevaGreen700,
                            modifier = Modifier.size(18.dp),
                        )
                    },
                )
            }
            Box(modifier = Modifier.fillMaxSize()) {
                when {
                    state.loading && state.rows.isEmpty() -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator()
                    }
                    state.error != null && state.rows.isEmpty() -> EmptyStateView(
                        icon = Icons.Outlined.Inbox,
                        title = "Couldn't load",
                        subtitle = state.error,
                    )
                    visibleRows.isEmpty() -> EmptyStateView(
                        icon = Icons.Filled.Engineering,
                        title = "No engineers match",
                        subtitle = "Try a wider district or fewer filters.",
                    )
                    else -> LazyColumn(
                        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
                        verticalArrangement = Arrangement.spacedBy(10.dp),
                    ) {
                        items(visibleRows, key = { it.engineerId }) { row ->
                            EngineerCard(row = row, onClick = { onOpenProfile(row.engineerId) })
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun EngineerCard(
    row: EngineerDirectoryRepository.DirectoryRow,
    onClick: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
            .clickable(onClick = onClick)
            .padding(14.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.Top,
    ) {
        Box(
            modifier = Modifier
                .size(48.dp)
                .clip(CircleShape)
                .background(SevaGreen50),
            contentAlignment = Alignment.Center,
        ) {
            val img = row.avatarUrl
            if (!img.isNullOrBlank()) {
                AsyncImage(
                    model = img,
                    contentDescription = null,
                    modifier = Modifier.fillMaxSize().clip(CircleShape),
                    contentScale = androidx.compose.ui.layout.ContentScale.Crop,
                )
            } else {
                Text(
                    row.fullName.firstOrNull()?.uppercaseChar()?.toString() ?: "E",
                    color = SevaGreen900,
                    fontWeight = FontWeight.Bold,
                    fontSize = 18.sp,
                )
            }
            // Online dot — small green badge bottom-right when available.
            if (row.isAvailable) {
                Box(
                    modifier = Modifier
                        .size(10.dp)
                        .clip(CircleShape)
                        .background(SevaGlowRaw)
                        .border(1.5.dp, Color.White, CircleShape)
                        .align(Alignment.BottomEnd),
                )
            }
        }
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Text(
                    row.fullName,
                    color = SevaInk900,
                    style = EsType.Body.copy(fontWeight = FontWeight.SemiBold),
                    modifier = Modifier.weight(1f),
                )
                Icon(
                    imageVector = Icons.Filled.Verified,
                    contentDescription = "Verified",
                    tint = SevaGreen700,
                    modifier = Modifier.size(14.dp),
                )
            }
            val locLine = listOfNotNull(row.city, row.state).joinToString(" · ").ifBlank { null }
            if (locLine != null) {
                Text(locLine, color = SevaInk500, style = EsType.Caption)
            }
            val specs = row.specializations.orEmpty().take(3)
            if (specs.isNotEmpty()) {
                Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    specs.forEach { sp ->
                        Box(
                            modifier = Modifier
                                .clip(RoundedCornerShape(4.dp))
                                .background(Paper2)
                                .padding(horizontal = 6.dp, vertical = 2.dp),
                        ) {
                            Text(prettyKey(sp), color = SevaInk600, fontSize = 10.sp)
                        }
                    }
                }
            }
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(3.dp)) {
                    Icon(Icons.Filled.Star, contentDescription = null, tint = SevaGlowRaw, modifier = Modifier.size(12.dp))
                    Text(
                        "${"%.1f".format(row.ratingAvg)} · ${row.totalJobs} jobs",
                        color = SevaInk700,
                        fontSize = 11.sp,
                    )
                }
                row.hourlyRate?.let { rate ->
                    Text("· ₹${rate.toInt()}/hr", color = SevaGreen700, fontWeight = FontWeight.SemiBold, fontSize = 11.sp)
                }
                Text("· ${row.experienceYears} yrs", color = SevaInk400, fontSize = 11.sp)
            }
        }
    }
}

private fun prettyKey(k: String): String =
    k.split('_', '-').joinToString(" ") { it.replaceFirstChar { c -> c.uppercase() } }
