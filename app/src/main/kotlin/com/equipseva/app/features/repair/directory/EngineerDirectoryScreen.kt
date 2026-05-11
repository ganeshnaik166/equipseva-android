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
import androidx.compose.material.icons.filled.Verified
import androidx.compose.material.icons.outlined.FilterList
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material.icons.outlined.WifiOff
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.lifecycle.compose.collectAsStateWithLifecycle
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
import android.app.Application
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import coil3.compose.AsyncImage
import com.equipseva.app.core.data.engineers.DirectorySortMode
import com.equipseva.app.core.data.engineers.EngineerDirectoryRepository
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.core.util.fetchCurrentLocation
import com.equipseva.app.core.util.formatRupees
import com.equipseva.app.core.util.initialsOf
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
    private val app: Application,
) : ViewModel() {
    data class UiState(
        val loading: Boolean = true,
        val error: String? = null,
        val query: String = "",
        val district: String = "All Telangana",
        val specialization: String? = null,
        val rows: List<EngineerDirectoryRepository.DirectoryRow> = emptyList(),
        // Hospital location — null until either GPS resolves or we give
        // up. When null, sortMode falls back to Rating regardless of
        // user pick (no coords ⇒ no nearest sort).
        val hospitalLat: Double? = null,
        val hospitalLng: Double? = null,
        // True while a fresh GPS fetch is in flight. Used to dim the
        // "Nearest" sort chip until coords land so the user doesn't see
        // it as a no-op tap.
        val resolvingLocation: Boolean = false,
        val sortMode: DirectorySortMode = DirectorySortMode.Rating,
    ) {
        val filteredRows: List<EngineerDirectoryRepository.DirectoryRow>
            get() = rows.filter { row ->
                val matchesDistrict = district == "All Telangana" ||
                    row.city?.equals(district, ignoreCase = true) == true
                val matchesSpec = specialization == null ||
                    row.specializations.orEmpty().any { it.equals(specialization, ignoreCase = true) }
                matchesDistrict && matchesSpec
            }

        /** True iff the server can return real distance values + a
         * Nearest sort makes sense. */
        val hasLocation: Boolean
            get() = hospitalLat != null && hospitalLng != null
    }

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init {
        // Fetch GPS in parallel with the first directory load. Either
        // races to completion: if location lands first, the next refresh
        // (debounced query change OR explicit sort flip) picks it up.
        // If the directory loads first with rating-sort, we re-sort on
        // the next interaction once coords arrive — no UX flicker.
        resolveLocationThenMaybeRefresh()
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
    fun onSortModeChange(mode: DirectorySortMode) {
        _state.update { it.copy(sortMode = mode) }
        refresh()
    }

    private fun resolveLocationThenMaybeRefresh() {
        _state.update { it.copy(resolvingLocation = true) }
        viewModelScope.launch {
            val loc = fetchCurrentLocation(app)
            val hadCoords = _state.value.hasLocation
            _state.update {
                it.copy(
                    resolvingLocation = false,
                    hospitalLat = loc?.latitude ?: it.hospitalLat,
                    hospitalLng = loc?.longitude ?: it.hospitalLng,
                    // Auto-flip default to Nearest the first time coords
                    // arrive — only if user hasn't already picked a sort.
                    sortMode = if (loc != null && !hadCoords && it.sortMode == DirectorySortMode.Rating) {
                        DirectorySortMode.Nearest
                    } else {
                        it.sortMode
                    },
                )
            }
            // Re-fetch with coords now that we have them — the first
            // search() call went out without lat/lng, so distance
            // chips would be missing on the cards.
            if (loc != null) refresh()
        }
    }

    fun onRefresh() = refresh()

    private fun refresh() {
        _state.update { it.copy(loading = true, error = null) }
        viewModelScope.launch {
            val s = _state.value
            // Effective sort: if caller picked Nearest but we have no
            // coords, fall back to Rating server-side (the SQL handles
            // the null-coord case gracefully but this keeps the request
            // explicit + cacheable).
            val effectiveSort = if (s.sortMode == DirectorySortMode.Nearest && !s.hasLocation) {
                DirectorySortMode.Rating
            } else {
                s.sortMode
            }
            // Trim before sending — leading/trailing whitespace silently
            // missed real matches under server-side ILIKE / FTS rules.
            repo.search(
                query = s.query.trim().takeIf { it.isNotEmpty() },
                hospitalLat = s.hospitalLat,
                hospitalLng = s.hospitalLng,
                sortMode = effectiveSort,
            )
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
    viewModel: EngineerDirectoryViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val visibleRows = state.filteredRows
    var showFilters by remember { mutableStateOf(false) }
    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(
                title = "Find an engineer",
                // "Near All Telangana" reads awkwardly when the user
                // hasn't picked a district — "near" implies proximity
                // to a point, not a whole state. Phrase as scope instead.
                subtitle = if (state.district == "All Telangana")
                    "${visibleRows.size} verified · across Telangana"
                else
                    "${visibleRows.size} verified · near ${state.district}",
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
                    // Network error path: distinguish "RPC failed" from
                    // "filter narrowed to zero." Without this the
                    // hospital sees "No engineers match — try a wider
                    // district" when actually wifi is off and supply
                    // exists, falsely signalling no platform liquidity.
                    state.error != null && state.rows.isEmpty() -> EmptyEngineersError(
                        message = state.error!!,
                        onRetry = { viewModel.onRefresh() },
                    )
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
                sortMode = state.sortMode,
                hasLocation = state.hasLocation,
                resolvingLocation = state.resolvingLocation,
                onPick = { viewModel.onSpecializationChange(it) },
                onSortPick = { viewModel.onSortModeChange(it) },
                onClose = { showFilters = false },
            )
        }
    }
}

@Composable
private fun EmptyEngineersError(message: String, onRetry: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(40.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Icon(
            Icons.Outlined.WifiOff,
            contentDescription = null,
            tint = SevaInk500,
            modifier = Modifier.size(32.dp),
        )
        Spacer(Modifier.height(12.dp))
        Text(
            "Couldn't load engineers",
            color = SevaInk900,
            fontSize = 14.sp,
            fontWeight = FontWeight.SemiBold,
        )
        Spacer(Modifier.height(4.dp))
        Text(
            text = message,
            color = SevaInk500,
            fontSize = 12.sp,
            textAlign = androidx.compose.ui.text.style.TextAlign.Center,
        )
        Spacer(Modifier.height(12.dp))
        EsBtn(
            text = "Try again",
            onClick = onRetry,
            kind = EsBtnKind.Secondary,
            size = EsBtnSize.Md,
        )
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
    sortMode: DirectorySortMode,
    hasLocation: Boolean,
    resolvingLocation: Boolean,
    onPick: (String?) -> Unit,
    onSortPick: (DirectorySortMode) -> Unit,
    onClose: () -> Unit,
) {
    EsBottomSheet(onClose = onClose, title = "Filters") {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                "Sort by",
                color = SevaInk700,
                fontSize = 13.sp,
                fontWeight = FontWeight.SemiBold,
            )
            Spacer(Modifier.height(8.dp))
            FlowRow(
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                verticalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                // Nearest is offered always but greyed out + disabled
                // when we have no coords — clearer than hiding it.
                EsChip(
                    text = if (resolvingLocation && !hasLocation) "Nearest…" else "Nearest",
                    active = sortMode == DirectorySortMode.Nearest && hasLocation,
                    onClick = {
                        if (hasLocation) onSortPick(DirectorySortMode.Nearest)
                    },
                )
                EsChip(
                    text = "Top rated",
                    active = sortMode == DirectorySortMode.Rating,
                    onClick = { onSortPick(DirectorySortMode.Rating) },
                )
                EsChip(
                    text = "Lowest price",
                    active = sortMode == DirectorySortMode.PriceAsc,
                    onClick = { onSortPick(DirectorySortMode.PriceAsc) },
                )
            }
            if (!hasLocation && !resolvingLocation) {
                Spacer(Modifier.height(6.dp))
                Text(
                    "Enable location for distance-based sort",
                    color = SevaInk500,
                    fontSize = 11.sp,
                )
            }
            Spacer(Modifier.height(16.dp))
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
            initials = initialsOf(row.fullName),
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
            val locParts = listOfNotNull(
                row.city,
                row.distanceKm?.let { "${"%.1f".format(it)} km" },
                row.hourlyRate?.let { "${formatRupees(it)}/hr" },
            )
            if (locParts.isNotEmpty()) {
                Text(
                    locParts.joinToString(" · "),
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
                // completionPctOverride is the only honest source — the
                // earlier fallback used a 90-100% formula seeded off
                // totalJobs, so a hospital scanning the directory saw
                // every engineer at "100% complete" once they crossed
                // 20 jobs. Hide the field when no real number exists.
                row.completionPctOverride?.let { pct ->
                    Text(
                        "$pct% complete",
                        color = SevaInk400,
                        fontSize = 11.sp,
                    )
                }
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

private fun prettyKey(k: String): String =
    k.split('_', '-').joinToString(" ") { it.replaceFirstChar { c -> c.uppercase() } }

