package com.equipseva.app.features.founder

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Engineering
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.foundation.layout.Spacer
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaGreen900
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk900
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.designsystem.theme.AccentLime
import com.google.android.gms.maps.model.CameraPosition
import com.google.android.gms.maps.model.LatLng
import com.google.maps.android.compose.GoogleMap
import com.google.maps.android.compose.MapProperties
import com.google.maps.android.compose.MapUiSettings
import com.google.maps.android.compose.Marker
import com.google.maps.android.compose.rememberCameraPositionState
import com.google.maps.android.compose.rememberMarkerState
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

@HiltViewModel
class FounderEngineerMapViewModel @Inject constructor(
    private val founderRepository: FounderRepository,
) : ViewModel() {

    data class UiState(
        val loading: Boolean = true,
        val rows: List<FounderRepository.EngineerZoneRow> = emptyList(),
        val error: String? = null,
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init {
        refresh()
    }

    fun refresh() {
        _state.update { it.copy(loading = true, error = null) }
        viewModelScope.launch {
            founderRepository.fetchEngineersByDistrict()
                .onSuccess { rows ->
                    _state.update { it.copy(loading = false, rows = rows) }
                }
                .onFailure { ex ->
                    _state.update { it.copy(loading = false, error = ex.toUserMessage()) }
                }
        }
    }
}

@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
fun FounderEngineerMapScreen(
    onBack: () -> Unit,
    viewModel: FounderEngineerMapViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    // Round 443 — refresh on return so newly-verified engineers (admin
    // approves KYC in another tab, comes back here) appear in the zone
    // counts without a manual back+forward dance.
    com.equipseva.app.designsystem.util.RefreshOnReturn { viewModel.refresh() }
    var selected by remember { mutableStateOf<String?>(null) }

    androidx.compose.material3.Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(title = "Engineer zones", onBack = onBack)
            Box(modifier = Modifier.fillMaxSize()) {
            when {
                state.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }
                state.error != null -> Column(
                    modifier = Modifier.fillMaxSize().padding(16.dp),
                    verticalArrangement = Arrangement.Center,
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Text(state.error!!, color = MaterialTheme.colorScheme.error)
                    Spacer(modifier = Modifier.size(12.dp))
                    TextButton(onClick = { viewModel.refresh() }) {
                        Text("Retry")
                    }
                }
                state.rows.isEmpty() -> Column(
                    modifier = Modifier.fillMaxSize().padding(16.dp),
                    verticalArrangement = Arrangement.Center,
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Icon(
                        imageVector = Icons.Filled.Engineering,
                        contentDescription = null,
                        tint = SevaInk500,
                        modifier = Modifier.size(48.dp),
                    )
                    Text(
                        "No verified engineers available yet.",
                        fontSize = 14.sp,
                        color = SevaInk500,
                    )
                }
                else -> Column(modifier = Modifier.fillMaxSize()) {
                    ZoneMap(rows = state.rows, selected = selected)
                    // Round 434 — memoize the zone/engineer count walk so the
                    // sumOf doesn't re-fire on every recomposition (realtime
                    // ticks, selected-zone change, etc.). Keyed on rows so the
                    // cache invalidates when the list itself changes.
                    val summaryText = androidx.compose.runtime.remember(state.rows) {
                        val zones = state.rows.size
                        val engineers = state.rows.sumOf { it.engineerCount }
                        val zoneLabel = if (zones == 1) "1 zone" else "$zones zones"
                        val engLabel = if (engineers == 1) "1 verified engineer" else "$engineers verified engineers"
                        "$zoneLabel · $engLabel"
                    }
                    Text(
                        text = summaryText,
                        fontSize = 12.sp,
                        color = SevaInk500,
                        fontWeight = FontWeight.SemiBold,
                        modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp),
                    )
                    LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(12.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        items(state.rows, key = { it.district }) { row ->
                            ZoneRow(
                                row = row,
                                selected = selected == row.district,
                                onClick = {
                                    selected = if (selected == row.district) null else row.district
                                },
                            )
                        }
                    }
                }
            }
            }
        }
    }
}

@Composable
private fun ZoneMap(
    rows: List<FounderRepository.EngineerZoneRow>,
    selected: String?,
) {
    // Memoize the lat/lng filter so it doesn't re-fire every parent
    // recomposition (founder dashboard ticks every realtime event).
    val pinned = androidx.compose.runtime.remember(rows) {
        rows.mapNotNull { row ->
            val lat = row.sampleLat ?: return@mapNotNull null
            val lng = row.sampleLng ?: return@mapNotNull null
            Triple(row, lat, lng)
        }
    }
    if (pinned.isEmpty()) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(220.dp)
                .padding(horizontal = 16.dp, vertical = 8.dp)
                .clip(RoundedCornerShape(12.dp))
                .background(BorderDefault),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                "No coordinates pinned yet — engineers haven't dropped service-area pins.",
                fontSize = 12.sp,
                color = SevaInk500,
            )
        }
        return
    }

    val center = androidx.compose.runtime.remember(pinned, selected) {
        pinned
            .firstOrNull { it.first.district == selected }
            ?.let { LatLng(it.second, it.third) }
            ?: pinned.maxBy { it.first.engineerCount }.let { LatLng(it.second, it.third) }
    }

    val cameraPositionState = rememberCameraPositionState {
        position = CameraPosition.fromLatLngZoom(center, 9f)
    }
    androidx.compose.runtime.LaunchedEffect(selected) {
        cameraPositionState.position = CameraPosition.fromLatLngZoom(center, 11f)
    }

    GoogleMap(
        modifier = Modifier
            .fillMaxWidth()
            .height(280.dp)
            .padding(horizontal = 16.dp, vertical = 8.dp)
            .clip(RoundedCornerShape(12.dp)),
        cameraPositionState = cameraPositionState,
        properties = MapProperties(isMyLocationEnabled = false),
        uiSettings = MapUiSettings(
            zoomControlsEnabled = false,
            mapToolbarEnabled = false,
            scrollGesturesEnabled = true,
            zoomGesturesEnabled = true,
            tiltGesturesEnabled = false,
            rotationGesturesEnabled = false,
        ),
    ) {
        pinned.forEach { (row, lat, lng) ->
            val isSel = row.district == selected
            Marker(
                state = rememberMarkerState(key = row.district, position = LatLng(lat, lng)),
                title = row.district,
                snippet = "${row.engineerCount} verified engineer${if (row.engineerCount == 1) "" else "s"}",
                alpha = if (selected == null || isSel) 1f else 0.45f,
            )
        }
    }
}

@Composable
private fun ZoneRow(
    row: FounderRepository.EngineerZoneRow,
    selected: Boolean,
    onClick: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(if (selected) AccentLime else androidx.compose.ui.graphics.Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
            .clickable { onClick() }
            .padding(horizontal = 12.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Box(
            modifier = Modifier
                .size(40.dp)
                .clip(RoundedCornerShape(10.dp))
                .background(if (selected) SevaGreen900 else SevaGreen700),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = row.engineerCount.toString(),
                color = androidx.compose.ui.graphics.Color.White,
                fontSize = 13.sp,
                fontWeight = FontWeight.Bold,
            )
        }
        Column(modifier = Modifier.fillMaxWidth()) {
            Text(
                text = row.district,
                fontSize = 14.sp,
                color = SevaInk900,
                fontWeight = FontWeight.SemiBold,
            )
            Text(
                text = zoneRowSampleCoordinateLine(row.sampleLat, row.sampleLng),
                fontSize = 11.sp,
                color = SevaInk500,
            )
        }
    }
}

/**
 * Sample-coordinate caption on the founder engineer-zone row.
 *
 * "Avg pin: LAT, LNG" with Locale.US-stable 4-decimal precision when
 * BOTH coords are present; falls back to "No coordinates pinned"
 * when EITHER is null.
 *
 * Critical regions:
 *   - Locale.US — hi-IN / German would render "17,3850, 78,4567"
 *     (commas as decimals + comma separator becomes ambiguous).
 *   - %.4f precision — distinct from formatSavedServiceLocation's
 *     %.5f. 4 decimals ≈ 11m, sufficient for a district-level
 *     averaged pin where the engineer's actual location is one
 *     of many; %.5f would suggest false precision on an average
 *     coordinate.
 *   - "Avg pin:" prefix — load-bearing context ("Pin:" would
 *     imply this is the engineer's actual pin, not the district
 *     average).
 *   - "No coordinates pinned" fallback — clearer than "—" or "N/A".
 */
internal fun zoneRowSampleCoordinateLine(sampleLat: Double?, sampleLng: Double?): String =
    if (sampleLat != null && sampleLng != null) {
        "Avg pin: ${"%.4f".format(java.util.Locale.US, sampleLat)}, ${"%.4f".format(java.util.Locale.US, sampleLng)}"
    } else {
        "No coordinates pinned"
    }
