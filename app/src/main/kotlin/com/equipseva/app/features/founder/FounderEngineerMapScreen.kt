package com.equipseva.app.features.founder

import androidx.compose.foundation.background
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
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Engineering
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
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
import com.equipseva.app.designsystem.theme.BrandGreen
import com.equipseva.app.designsystem.theme.BrandGreenDark
import com.equipseva.app.designsystem.theme.Ink500
import com.equipseva.app.designsystem.theme.Ink900
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.designsystem.theme.Surface0
import com.equipseva.app.designsystem.theme.Surface50
import com.equipseva.app.designsystem.theme.Surface200
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
    var selected by remember { mutableStateOf<String?>(null) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Engineer zones") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.primary,
                    titleContentColor = MaterialTheme.colorScheme.onPrimary,
                    navigationIconContentColor = MaterialTheme.colorScheme.onPrimary,
                ),
            )
        },
        containerColor = Surface50,
    ) { inner ->
        Box(modifier = Modifier.fillMaxSize().padding(inner)) {
            when {
                state.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }
                state.error != null -> Column(
                    modifier = Modifier.fillMaxSize().padding(Spacing.lg),
                    verticalArrangement = Arrangement.Center,
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Text(state.error!!, color = MaterialTheme.colorScheme.error)
                }
                state.rows.isEmpty() -> Column(
                    modifier = Modifier.fillMaxSize().padding(Spacing.lg),
                    verticalArrangement = Arrangement.Center,
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Icon(
                        imageVector = Icons.Filled.Engineering,
                        contentDescription = null,
                        tint = Ink500,
                        modifier = Modifier.size(48.dp),
                    )
                    Text(
                        "No verified engineers available yet.",
                        fontSize = 14.sp,
                        color = Ink500,
                    )
                }
                else -> Column(modifier = Modifier.fillMaxSize()) {
                    ZoneMap(rows = state.rows, selected = selected)
                    Text(
                        text = "${state.rows.size} zones · ${state.rows.sumOf { it.engineerCount }} verified engineers",
                        fontSize = 12.sp,
                        color = Ink500,
                        fontWeight = FontWeight.SemiBold,
                        modifier = Modifier.padding(horizontal = Spacing.lg, vertical = 4.dp),
                    )
                    LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(Spacing.md),
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

@Composable
private fun ZoneMap(
    rows: List<FounderRepository.EngineerZoneRow>,
    selected: String?,
) {
    val pinned = rows.mapNotNull { row ->
        val lat = row.sampleLat ?: return@mapNotNull null
        val lng = row.sampleLng ?: return@mapNotNull null
        Triple(row, lat, lng)
    }
    if (pinned.isEmpty()) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(220.dp)
                .padding(horizontal = Spacing.lg, vertical = Spacing.sm)
                .clip(RoundedCornerShape(12.dp))
                .background(Surface200),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                "No coordinates pinned yet — engineers haven't dropped service-area pins.",
                fontSize = 12.sp,
                color = Ink500,
            )
        }
        return
    }

    val center = pinned
        .firstOrNull { it.first.district == selected }
        ?.let { LatLng(it.second, it.third) }
        ?: pinned.maxBy { it.first.engineerCount }.let { LatLng(it.second, it.third) }

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
            .padding(horizontal = Spacing.lg, vertical = Spacing.sm)
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
            .background(if (selected) AccentLime else Surface0)
            .clickable { onClick() }
            .padding(horizontal = Spacing.md, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Box(
            modifier = Modifier
                .size(40.dp)
                .clip(RoundedCornerShape(10.dp))
                .background(if (selected) BrandGreenDark else BrandGreen),
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
                color = Ink900,
                fontWeight = FontWeight.SemiBold,
            )
            Text(
                text = if (row.sampleLat != null && row.sampleLng != null) {
                    "Avg pin: ${"%.4f".format(row.sampleLat)}, ${"%.4f".format(row.sampleLng)}"
                } else {
                    "No coordinates pinned"
                },
                fontSize = 11.sp,
                color = Ink500,
            )
        }
    }
}
