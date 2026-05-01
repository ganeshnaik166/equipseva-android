package com.equipseva.app.features.repair

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
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.AutoAwesome
import androidx.compose.material.icons.outlined.Notifications
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.core.data.repair.RepairBidStatus
import com.equipseva.app.core.data.repair.RepairJob
import com.equipseva.app.core.data.repair.RepairJobStatus
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.ErrorBanner
import com.equipseva.app.designsystem.components.EsField
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.components.ShimmerListItem
import com.equipseva.app.designsystem.maxContentWidth
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.Paper2
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaGreen900
import com.equipseva.app.designsystem.theme.SevaGlowSoft
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk700
import com.equipseva.app.designsystem.theme.SevaInk900
import com.equipseva.app.designsystem.theme.SevaWarning50
import com.equipseva.app.designsystem.theme.SevaWarning500
import com.equipseva.app.designsystem.theme.SevaWarning700
import com.google.android.gms.maps.model.BitmapDescriptorFactory
import com.google.android.gms.maps.model.CameraPosition
import com.google.android.gms.maps.model.Dash
import com.google.android.gms.maps.model.Gap
import com.google.android.gms.maps.model.LatLng
import com.google.maps.android.compose.Circle
import com.google.maps.android.compose.GoogleMap
import com.google.maps.android.compose.MapProperties
import com.google.maps.android.compose.MapUiSettings
import com.google.maps.android.compose.Marker
import com.google.maps.android.compose.MarkerState
import com.google.maps.android.compose.rememberCameraPositionState
import com.equipseva.app.features.repair.components.EngineerJobCard
import androidx.compose.material.icons.outlined.Build

/**
 * Engineer-facing feed of open repair jobs (matches `JobBoard` in
 * `screens-engineer.jsx` lines 84-153). Pull-to-refresh + paged feed,
 * stat-strip + tip card + search + radius chips + map preview, then job
 * cards. Mine-tab and 2-tab pill-bar from earlier rounds is dropped to
 * match the new spec — engineers see only the open feed here, with
 * "My bids" / "Active work" reachable from the engineer hub.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RepairJobsScreen(
    onJobClick: (jobId: String) -> Unit = {},
    onTuneProfile: () -> Unit = {},
    onViewEarnings: () -> Unit = {},
    onOpenNotifications: () -> Unit = {},
    viewModel: RepairJobsViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val listState = rememberLazyListState()

    val reachedEnd by remember {
        derivedStateOf {
            val last = listState.layoutInfo.visibleItemsInfo.lastOrNull()
            val total = listState.layoutInfo.totalItemsCount
            last != null && total > 0 && last.index >= total - 3
        }
    }

    LaunchedEffect(reachedEnd, state.items.size) {
        if (reachedEnd) viewModel.onReachEnd()
    }

    val openJobs: List<RepairJob> = remember(state.items) {
        state.items.filter { it.status == RepairJobStatus.Requested }
    }

    val pendingBidCount = remember(state.ownBidsByJob) {
        state.ownBidsByJob.values.count { it.status == RepairBidStatus.Pending }
    }

    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(
                title = "Repair",
                subtitle = "${openJobs.size} jobs nearby",
                right = {
                    Box(
                        modifier = Modifier
                            .size(36.dp)
                            .clip(RoundedCornerShape(999.dp))
                            .clickable(onClick = onOpenNotifications),
                        contentAlignment = Alignment.Center,
                    ) {
                        Icon(
                            imageVector = Icons.Outlined.Notifications,
                            contentDescription = "Notifications",
                            tint = SevaInk700,
                            modifier = Modifier.size(20.dp),
                        )
                    }
                },
            )

            // ── Stat strip ───────────────────────────────────────────────
            StatStrip(
                nearby = openJobs.size,
                pending = pendingBidCount,
            )

            // ── Tip card ─────────────────────────────────────────────────
            TipCard()

            // ── Search + radius chips (single padded block per spec) ────
            Column(modifier = Modifier.fillMaxWidth().padding(start = 16.dp, end = 16.dp, top = 4.dp, bottom = 8.dp)) {
                EsField(
                    value = state.query,
                    onChange = viewModel::onQueryChange,
                    placeholder = "Search by issue, brand, model",
                    leading = {
                        Icon(
                            Icons.Outlined.Search,
                            contentDescription = null,
                            tint = SevaInk500,
                            modifier = Modifier.size(18.dp),
                        )
                    },
                )
                RadiusFilterRow(
                    selected = state.radiusKm,
                    onSelect = viewModel::onRadiusChange,
                )
            }

            // ── Map preview (engineer location + projected job pins) ────
            MapPreviewBox(
                baseLat = state.baseLatitude,
                baseLng = state.baseLongitude,
                jobCoords = state.coordsByJobId,
                distanceByJobId = state.distanceByJobId,
                jobs = openJobs,
                radiusKm = state.radiusKm,
            )

            ErrorBanner(message = state.errorMessage)

            PullToRefreshBox(
                isRefreshing = state.refreshing,
                onRefresh = viewModel::onRefresh,
                modifier = Modifier.weight(1f).fillMaxWidth(),
            ) {
                when {
                    state.initialLoading -> InitialShimmerList()
                    openJobs.isEmpty() -> {
                        if (state.query.isNotBlank()) {
                            EmptyStateView(
                                icon = Icons.Outlined.Build,
                                title = "No jobs matched \"${state.query}\".",
                                subtitle = "Try a different search or clear the filter.",
                            )
                        } else {
                            EmptyFeedState()
                        }
                    }
                    else -> LazyColumn(
                        state = listState,
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = 0.dp, bottom = 16.dp),
                        verticalArrangement = Arrangement.spacedBy(10.dp),
                    ) {
                        items(items = openJobs, key = { it.id }) { job ->
                            Box(
                                modifier = Modifier.fillMaxWidth(),
                                contentAlignment = Alignment.TopCenter,
                            ) {
                                EngineerJobCard(
                                    job = job,
                                    onClick = { onJobClick(job.id) },
                                    distanceKm = state.distanceByJobId[job.id],
                                    modifier = Modifier.maxContentWidth(),
                                )
                            }
                        }
                        if (state.loadingMore) {
                            item("loading_more") {
                                Box(
                                    modifier = Modifier.fillMaxWidth().padding(12.dp),
                                    contentAlignment = Alignment.Center,
                                ) {
                                    CircularProgressIndicator(
                                        modifier = Modifier.size(24.dp),
                                        strokeWidth = 2.dp,
                                    )
                                }
                            }
                        } else if (state.endReached && openJobs.isNotEmpty()) {
                            item("end") {
                                Text(
                                    text = "That's all the open jobs we have right now.",
                                    style = EsType.Caption,
                                    color = SevaInk500,
                                    textAlign = TextAlign.Center,
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .padding(12.dp),
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
private fun StatStrip(
    nearby: Int,
    pending: Int,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        StatCard(
            label = "Nearby",
            value = nearby.toString(),
            modifier = Modifier.weight(1f),
        )
        StatCard(
            label = "Pending bids",
            value = if (pending > 0) pending.toString() else "—",
            valueColor = SevaWarning500,
            modifier = Modifier.weight(1f),
        )
        StatCard(
            // Placeholder until a per-engineer monthly earnings stream is
            // injected here — we deliberately don't fake a number. Earnings
            // tab is the source of truth.
            label = "This month",
            value = "—",
            forest = true,
            modifier = Modifier.weight(1f),
        )
    }
}

@Composable
private fun StatCard(
    label: String,
    value: String,
    modifier: Modifier = Modifier,
    valueColor: Color = SevaInk900,
    forest: Boolean = false,
) {
    val shape = RoundedCornerShape(12.dp)
    Column(
        modifier = modifier
            .clip(shape)
            .background(if (forest) SevaGreen900 else Color.White)
            .let {
                if (forest) it
                else it.border(1.dp, BorderDefault, shape)
            }
            .height(96.dp)
            .padding(horizontal = 12.dp, vertical = 12.dp),
        verticalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(
            text = label.uppercase(),
            style = EsType.Caption.copy(
                fontSize = 11.sp,
                fontWeight = FontWeight.SemiBold,
                letterSpacing = 0.06.em,
            ),
            color = if (forest) Color.White.copy(alpha = 0.7f) else SevaInk500,
        )
        Text(
            text = value,
            style = EsType.H4.copy(fontSize = 24.sp, fontWeight = FontWeight.Bold),
            color = if (forest) Color.White else valueColor,
        )
    }
}

@Composable
private fun TipCard() {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(start = 16.dp, end = 16.dp, top = 0.dp, bottom = 8.dp),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(10.dp))
                .background(SevaGlowSoft)
                .padding(10.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.Top,
        ) {
            Icon(
                imageVector = Icons.Outlined.AutoAwesome,
                contentDescription = null,
                tint = SevaGreen900,
                modifier = Modifier.size(16.dp).padding(top = 1.dp),
            )
            Text(
                text = buildAnnotatedString {
                    withStyle(SpanStyle(fontWeight = FontWeight.Bold)) {
                        append("Tip: ")
                    }
                    append("bids in the first 10 min get accepted 3× more often.")
                },
                style = EsType.Caption.copy(fontSize = 12.sp, lineHeight = (12 * 1.4f).sp),
                color = SevaGreen900,
            )
        }
    }
}

@Composable
private fun RadiusFilterRow(
    selected: Int?,
    onSelect: (Int?) -> Unit,
) {
    val options = listOf(10, 25, 50, 100)
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .horizontalScroll(rememberScrollState())
            .padding(top = 10.dp, bottom = 4.dp),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        options.forEach { km ->
            FilterChipBox(
                text = "${km} km",
                active = selected == km,
                onClick = { onSelect(km) },
            )
        }
        FilterChipBox(text = "All", active = selected == null, onClick = { onSelect(null) })
    }
}

/**
 * Inline chip variant matching the spec's "Chip" primitive: 12dp radius +
 * paper2 inactive bg / green-700 active bg + 12sp/500 text. Kept private
 * here rather than upstreamed to designsystem because the round-D EsChip
 * already exists with a different visual (green-50 active fill).
 */
@Composable
private fun FilterChipBox(
    text: String,
    active: Boolean,
    onClick: () -> Unit,
) {
    val shape = RoundedCornerShape(999.dp)
    Row(
        modifier = Modifier
            .clip(shape)
            .background(if (active) SevaGreen700 else Paper2)
            .let {
                if (active) it.border(1.dp, SevaGreen700, shape) else it
            }
            .clickable(onClick = onClick)
            .padding(horizontal = 12.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = text,
            style = EsType.Caption.copy(fontSize = 12.sp, fontWeight = FontWeight.Medium),
            color = if (active) Color.White else SevaInk700,
        )
    }
}

/**
 * Real Google Maps preview. Centres on the engineer's KYC base coords with
 * a translucent radius circle matching the active filter, plus numbered
 * markers for the first few jobs that have known coords. Falls back to a
 * Hyderabad-region centre + "Set base in KYC" hint when the engineer
 * hasn't captured a location yet.
 */
@Composable
private fun MapPreviewBox(
    baseLat: Double?,
    baseLng: Double?,
    jobCoords: Map<String, Pair<Double, Double>>,
    distanceByJobId: Map<String, Double>,
    jobs: List<RepairJob>,
    radiusKm: Int?,
) {
    val effectiveRadiusKm = (radiusKm ?: 50)
    val center = LatLng(baseLat ?: 17.385, baseLng ?: 78.4867)
    val zoom = when {
        radiusKm == null -> 7f
        effectiveRadiusKm >= 100 -> 8f
        effectiveRadiusKm >= 50 -> 9f
        effectiveRadiusKm >= 25 -> 10f
        effectiveRadiusKm >= 10 -> 11f
        else -> 12f
    }
    val cameraPositionState = rememberCameraPositionState {
        position = CameraPosition.fromLatLngZoom(center, zoom)
    }
    LaunchedEffect(center.latitude, center.longitude, zoom) {
        cameraPositionState.position = CameraPosition.fromLatLngZoom(center, zoom)
    }

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(start = 16.dp, end = 16.dp, top = 0.dp, bottom = 12.dp),
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(200.dp)
                .clip(RoundedCornerShape(12.dp))
                .border(1.dp, BorderDefault, RoundedCornerShape(12.dp)),
        ) {
            GoogleMap(
                modifier = Modifier.fillMaxSize(),
                cameraPositionState = cameraPositionState,
                properties = MapProperties(isMyLocationEnabled = false),
                uiSettings = MapUiSettings(
                    zoomControlsEnabled = false,
                    mapToolbarEnabled = false,
                    scrollGesturesEnabled = true,
                    zoomGesturesEnabled = true,
                    tiltGesturesEnabled = false,
                    rotationGesturesEnabled = false,
                    compassEnabled = false,
                ),
            ) {
                if (baseLat != null && baseLng != null) {
                    Circle(
                        center = LatLng(baseLat, baseLng),
                        radius = effectiveRadiusKm * 1000.0,
                        strokeColor = SevaGreen700,
                        strokeWidth = 4f,
                        strokePattern = listOf(Dash(20f), Gap(12f)),
                        fillColor = SevaGreen700.copy(alpha = 0.06f),
                    )
                    Marker(
                        state = MarkerState(LatLng(baseLat, baseLng)),
                        title = "You",
                        icon = BitmapDescriptorFactory.defaultMarker(BitmapDescriptorFactory.HUE_GREEN),
                    )
                }
                val pinHues = listOf(
                    BitmapDescriptorFactory.HUE_RED,
                    BitmapDescriptorFactory.HUE_ORANGE,
                    BitmapDescriptorFactory.HUE_AZURE,
                )
                jobs.take(3).forEachIndexed { idx, job ->
                    val coord = jobCoords[job.id] ?: return@forEachIndexed
                    Marker(
                        state = MarkerState(LatLng(coord.first, coord.second)),
                        title = job.title,
                        snippet = distanceByJobId[job.id]?.let { "%.1f km away".format(it) },
                        icon = BitmapDescriptorFactory.defaultMarker(pinHues[idx % pinHues.size]),
                    )
                }
            }

            // Bottom-left radius chip
            Box(
                modifier = Modifier
                    .align(Alignment.BottomStart)
                    .padding(8.dp)
                    .clip(RoundedCornerShape(6.dp))
                    .background(Color.White.copy(alpha = 0.95f))
                    .border(1.dp, BorderDefault, RoundedCornerShape(6.dp))
                    .padding(horizontal = 8.dp, vertical = 4.dp),
            ) {
                Text(
                    text = "${effectiveRadiusKm} km radius",
                    style = EsType.Caption.copy(fontSize = 11.sp, fontWeight = FontWeight.Medium),
                    color = SevaInk700,
                )
            }

            if (baseLat == null || baseLng == null) {
                Box(
                    modifier = Modifier
                        .align(Alignment.TopEnd)
                        .padding(8.dp)
                        .clip(RoundedCornerShape(6.dp))
                        .background(SevaWarning50)
                        .border(1.dp, SevaWarning500.copy(alpha = 0.4f), RoundedCornerShape(6.dp))
                        .padding(horizontal = 8.dp, vertical = 4.dp),
                ) {
                    Text(
                        text = "Set base in KYC",
                        style = EsType.Caption.copy(fontSize = 11.sp, fontWeight = FontWeight.Medium),
                        color = SevaWarning700,
                    )
                }
            }
        }
    }
}

@Composable
private fun InitialShimmerList() {
    Column(modifier = Modifier.fillMaxSize()) {
        repeat(4) { ShimmerListItem() }
    }
}

@Composable
private fun EmptyFeedState() {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(40.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            text = "No jobs in this radius",
            style = EsType.Body.copy(fontWeight = FontWeight.SemiBold, fontSize = 14.sp),
            color = SevaInk700,
            textAlign = TextAlign.Center,
        )
        Box(modifier = Modifier.height(4.dp))
        Text(
            text = "Try widening the radius filter",
            style = EsType.Caption.copy(fontSize = 12.sp),
            color = SevaInk500,
            textAlign = TextAlign.Center,
        )
    }
}
