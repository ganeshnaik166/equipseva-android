package com.equipseva.app.features.repair.directory

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
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
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.Verified
import androidx.compose.material.icons.outlined.FilterList
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import coil3.compose.AsyncImage
import com.equipseva.app.core.data.engineers.EngineerDirectoryRepository
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.designsystem.components.EsBottomSheet
import com.equipseva.app.designsystem.components.EsBtn
import com.equipseva.app.designsystem.components.EsBtnKind
import com.equipseva.app.designsystem.components.EsBtnSize
import com.equipseva.app.designsystem.components.EsChip
import com.equipseva.app.designsystem.components.InlineStars
import com.equipseva.app.designsystem.components.EsField
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.Paper2
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaGreen500
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaInk300
import com.equipseva.app.designsystem.theme.SevaInk400
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk600
import com.equipseva.app.designsystem.theme.SevaInk700
import com.equipseva.app.designsystem.theme.SevaInk900
import com.equipseva.app.designsystem.theme.SevaWarning500
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.FlowPreview
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.debounce
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.drop
import kotlinx.coroutines.flow.filter
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
        val district: String = "All Telangana",
        val specialization: String? = null,
        val rows: List<EngineerDirectoryRepository.DirectoryRow> = emptyList(),
    ) {
        val filteredRows: List<EngineerDirectoryRepository.DirectoryRow>
            get() = rows.filter { row ->
                val matchesDistrict = district == "All Telangana" ||
                    row.city?.equals(district, ignoreCase = true) == true
                val matchesSpec = specialization == null ||
                    row.specializations.orEmpty().any { it.equals(specialization, ignoreCase = true) }
                matchesDistrict && matchesSpec
            }
    }

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init {
        refresh()
        _state
            .map { it.query.trim() }
            .distinctUntilChanged()
            .drop(1)
            // Skip 1-char queries: a single letter matches half the
            // directory and burns a server round-trip per keystroke.
            // Empty string is the "cleared search" reset, so let it pass.
            .filter { it.isEmpty() || it.length >= 2 }
            .debounce(300L)
            .onEach { refresh() }
            .launchIn(viewModelScope)
    }

    fun onQueryChange(v: String) = _state.update { it.copy(query = v) }
    fun onDistrictChange(d: String) = _state.update { it.copy(district = d) }
    fun onSpecializationChange(s: String?) = _state.update { it.copy(specialization = s) }

    private fun refresh() {
        _state.update { it.copy(loading = true, error = null) }
        viewModelScope.launch {
            // Trim before sending — leading/trailing whitespace silently
            // missed real matches under server-side ILIKE / FTS rules.
            repo.search(query = _state.value.query.trim().takeIf { it.isNotEmpty() })
                .onSuccess { rows ->
                    _state.update { it.copy(loading = false, rows = rows) }
                }
                .onFailure { ex ->
                    _state.update {
                        it.copy(loading = false, rows = emptyList(), error = ex.toUserMessage())
                    }
                }
        }
    }
}

// Telangana districts the design's directory chip row enumerates.
private val DEFAULT_DISTRICTS = listOf(
    "All Telangana",
    "Hyderabad",
    "Nalgonda",
    "Suryapet",
    "Warangal",
    "Khammam",
)

private val DEFAULT_SPECS = listOf(
    "Imaging",
    "Patient monitoring",
    "Life support",
    "Surgical",
    "Laboratory",
    "Dental",
    "Ophthalmology",
    "Sterilization",
    "Dialysis",
)

@Composable
fun EngineerDirectoryScreen(
    onBack: () -> Unit,
    onOpenProfile: (engineerId: String) -> Unit,
    @Suppress("UNUSED_PARAMETER") onAnyEngineer: () -> Unit,
    viewModel: EngineerDirectoryViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsState()
    val visibleRows = state.filteredRows
    var showFilters by remember { mutableStateOf(false) }
    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(
                title = "Find an engineer",
                subtitle = "${visibleRows.size} verified · near ${state.district}",
                onBack = onBack,
            )
            // Sticky search + district chip strip — paper bg, padding 8/16/4
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(PaperDefault)
                    .padding(start = 16.dp, end = 16.dp, top = 8.dp, bottom = 4.dp),
            ) {
                EsField(
                    value = state.query,
                    onChange = viewModel::onQueryChange,
                    placeholder = "Search by name, brand, specialization",
                    leading = {
                        Icon(
                            Icons.Outlined.Search,
                            contentDescription = null,
                            tint = SevaInk500,
                            modifier = Modifier.size(18.dp),
                        )
                    },
                    trailing = {
                        Box(
                            modifier = Modifier
                                .size(28.dp)
                                .clickable { showFilters = true },
                            contentAlignment = Alignment.Center,
                        ) {
                            Icon(
                                Icons.Outlined.FilterList,
                                contentDescription = "Filters",
                                tint = SevaGreen700,
                                modifier = Modifier.size(18.dp),
                            )
                        }
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
                Spacer(Modifier.height(4.dp))
            }
            Box(modifier = Modifier.fillMaxSize()) {
                when {
                    state.loading && state.rows.isEmpty() -> Box(
                        Modifier.fillMaxSize(),
                        contentAlignment = Alignment.Center,
                    ) { CircularProgressIndicator() }
                    visibleRows.isEmpty() -> EmptyEngineers()
                    else -> LazyColumn(
                        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
                        verticalArrangement = Arrangement.spacedBy(10.dp),
                    ) {
                        items(visibleRows, key = { it.engineerId }) { row ->
                            EngCard(row = row, onClick = { onOpenProfile(row.engineerId) })
                        }
                    }
                }
            }
        }
        if (showFilters) {
            FilterSheet(
                current = state.specialization,
                onPick = { viewModel.onSpecializationChange(it) },
                onClose = { showFilters = false },
            )
        }
    }
}

@Composable
private fun EmptyEngineers() {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(40.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Icon(
            Icons.Outlined.Search,
            contentDescription = null,
            tint = SevaInk300,
            modifier = Modifier.size(32.dp),
        )
        Spacer(Modifier.height(12.dp))
        Text(
            "No engineers match",
            color = SevaInk700,
            fontSize = 14.sp,
            fontWeight = FontWeight.SemiBold,
        )
        Spacer(Modifier.height(4.dp))
        Text(
            "Try a wider district or fewer filters",
            color = SevaInk500,
            fontSize = 12.sp,
        )
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun FilterSheet(
    current: String?,
    onPick: (String?) -> Unit,
    onClose: () -> Unit,
) {
    EsBottomSheet(onClose = onClose, title = "Filters") {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                "Specialization",
                color = SevaInk700,
                fontSize = 13.sp,
                fontWeight = FontWeight.SemiBold,
            )
            Spacer(Modifier.height(8.dp))
            FlowRow(
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                verticalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                EsChip(text = "Any", active = current == null, onClick = { onPick(null) })
                DEFAULT_SPECS.forEach { s ->
                    EsChip(text = s, active = current == s, onClick = { onPick(s) })
                }
            }
            Spacer(Modifier.height(20.dp))
            EsBtn(
                text = "Apply",
                onClick = onClose,
                kind = EsBtnKind.Primary,
                size = EsBtnSize.Lg,
                full = true,
            )
            Spacer(Modifier.height(8.dp))
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun EngCard(
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
        AvatarBlock(
            initials = row.fullName.take(2).uppercase(),
            avatarUrl = row.avatarUrl,
            size = 48.dp,
            online = row.isAvailable,
        )
        Column(modifier = Modifier.weight(1f)) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Text(
                    row.fullName,
                    color = SevaInk900,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.SemiBold,
                )
                InlineVerifiedBadge(small = true)
            }
            Spacer(Modifier.height(2.dp))
            val locLine = formatDirectoryRowLocationLine(
                city = row.city,
                distanceKm = row.distanceKm,
                hourlyRate = row.hourlyRate,
            )
            if (locLine != null) {
                Text(
                    locLine,
                    color = SevaInk500,
                    fontSize = 12.sp,
                )
            }
            val specs = row.specializations.orEmpty().take(3)
            if (specs.isNotEmpty()) {
                Spacer(Modifier.height(8.dp))
                FlowRow(
                    horizontalArrangement = Arrangement.spacedBy(4.dp),
                    verticalArrangement = Arrangement.spacedBy(4.dp),
                ) {
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
            Spacer(Modifier.height(8.dp))
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                InlineStars(rating = row.ratingAvg, count = row.totalJobs, small = true)
                val completionPct = row.completionPctOverride ?: computeCompletion(row.totalJobs)
                Text(
                    "$completionPct% complete",
                    color = SevaInk400,
                    fontSize = 11.sp,
                )
            }
        }
    }
}

@Composable
internal fun AvatarBlock(
    initials: String,
    avatarUrl: String?,
    size: Dp,
    online: Boolean,
) {
    Box(modifier = Modifier.size(size)) {
        Box(
            modifier = Modifier
                .size(size)
                .clip(CircleShape)
                .background(
                    Brush.linearGradient(listOf(SevaGreen700, SevaGreen500)),
                ),
            contentAlignment = Alignment.Center,
        ) {
            if (!avatarUrl.isNullOrBlank()) {
                AsyncImage(
                    model = avatarUrl,
                    contentDescription = null,
                    modifier = Modifier.fillMaxSize().clip(CircleShape),
                    contentScale = androidx.compose.ui.layout.ContentScale.Crop,
                )
            } else {
                Text(
                    initials,
                    color = Color.White,
                    fontWeight = FontWeight.SemiBold,
                    fontSize = (size.value * 0.36f).sp,
                )
            }
        }
        if (online) {
            val dot = (size.value * 0.28f).coerceAtLeast(10f).dp
            Box(
                modifier = Modifier
                    .align(Alignment.BottomEnd)
                    .size(dot)
                    .clip(CircleShape)
                    .background(Color.White),
                contentAlignment = Alignment.Center,
            ) {
                Box(
                    modifier = Modifier
                        .size(dot - 4.dp)
                        .clip(CircleShape)
                        .background(SevaGreen500),
                )
            }
        }
    }
}

@Composable
internal fun InlineVerifiedBadge(small: Boolean = false) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Icon(
            Icons.Filled.Verified,
            contentDescription = "Verified",
            tint = SevaGreen700,
            modifier = Modifier.size(if (small) 11.dp else 13.dp),
        )
        Text(
            "Verified",
            color = SevaGreen700,
            fontSize = if (small) 10.sp else 11.sp,
            fontWeight = FontWeight.SemiBold,
        )
    }
}

// InlineStars promoted to a shared component so the new
// EngineerRatingCard + ReviewItem render the same glyph without a fork.
// See app/src/main/kotlin/com/equipseva/app/designsystem/components/InlineStars.kt

private fun prettyKey(k: String): String = prettyKeyLabel(k)

private fun computeCompletion(totalJobs: Int): Int = computeFallbackCompletionPct(totalJobs)

/**
 * Title-case a snake/kebab-cased token for chip labels (`patient_monitor`
 * → "Patient Monitor"). Used by the directory card chips and the public
 * profile specialization chip flow — both rendered the exact same
 * transform privately so they stay in lock-step.
 */
internal fun prettyKeyLabel(k: String): String =
    k.split('_', '-').joinToString(" ") { it.replaceFirstChar { c -> c.uppercase() } }

/**
 * Fallback completion percentage for engineers without a server-side
 * override. Curve: 90% + (min(jobs, 20) / 2) clamped to 100. So 0 jobs →
 * 90%, 20+ jobs → 100%. Locked inside the EngCard composable; pulled out
 * so the curve can be pinned and tweaked without standing up Compose.
 */
internal fun computeFallbackCompletionPct(totalJobs: Int): Int =
    (90 + (totalJobs.coerceAtMost(20) / 2)).coerceAtMost(100)

/**
 * Build the second line of the directory card: "city · X.Y km · ₹R/hr".
 * Any null/blank component is dropped, separators collapse. Returns null
 * when nothing is renderable so the caller can skip the Text node.
 */
internal fun formatDirectoryRowLocationLine(
    city: String?,
    distanceKm: Double?,
    hourlyRate: Double?,
): String? {
    val parts = listOfNotNull(
        city?.takeIf { it.isNotBlank() },
        distanceKm?.let { "${"%.1f".format(it)} km" },
        hourlyRate?.let { "₹${it.toInt()}/hr" },
    )
    return if (parts.isEmpty()) null else parts.joinToString(" · ")
}
