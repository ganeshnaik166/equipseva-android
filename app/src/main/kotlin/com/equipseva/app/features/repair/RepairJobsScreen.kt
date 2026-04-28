package com.equipseva.app.features.repair

import androidx.compose.foundation.background
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
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.outlined.Build
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
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.core.data.repair.RepairBidStatus
import com.equipseva.app.core.data.repair.RepairJob
import com.equipseva.app.core.data.repair.RepairJobStatus
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.ErrorBanner
import com.equipseva.app.designsystem.components.EsChip
import com.equipseva.app.designsystem.components.EsField
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.components.ShimmerListItem
import com.equipseva.app.designsystem.maxContentWidth
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk900
import com.equipseva.app.features.repair.components.EngineerRepairHeroCard
import com.equipseva.app.features.repair.components.EngineerTipCard
import com.equipseva.app.features.repair.components.MapJob
import com.equipseva.app.features.repair.components.NearbyJobsMap
import com.equipseva.app.features.repair.components.RepairJobCard

/**
 * Engineer-facing feed of open repair jobs. Pull-to-refresh and paged list,
 * with optional ILIKE search against issue/brand/model.
 */
private enum class EngineerJobsTab(val label: String) {
    Available("Available"),
    Mine("My jobs"),
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RepairJobsScreen(
    onJobClick: (jobId: String) -> Unit = {},
    onTuneProfile: () -> Unit = {},
    onViewEarnings: () -> Unit = {},
    viewModel: RepairJobsViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val listState = rememberLazyListState()
    var selectedTab by rememberSaveable { mutableStateOf(EngineerJobsTab.Available) }

    val reachedEnd by remember {
        derivedStateOf {
            val last = listState.layoutInfo.visibleItemsInfo.lastOrNull()
            val total = listState.layoutInfo.totalItemsCount
            last != null && total > 0 && last.index >= total - 3
        }
    }

    LaunchedEffect(reachedEnd, state.items.size, selectedTab) {
        if (reachedEnd && selectedTab == EngineerJobsTab.Available) viewModel.onReachEnd()
    }

    val filtered: List<RepairJob> = remember(state.items, state.mineItems, selectedTab) {
        when (selectedTab) {
            EngineerJobsTab.Available -> state.items.filter { it.status == RepairJobStatus.Requested }
            EngineerJobsTab.Mine -> state.mineItems
        }
    }

    val showLoading = when (selectedTab) {
        EngineerJobsTab.Available -> state.initialLoading
        EngineerJobsTab.Mine -> state.mineLoading
    }
    val bannerMessage = when (selectedTab) {
        EngineerJobsTab.Available -> state.errorMessage
        EngineerJobsTab.Mine -> state.mineErrorMessage
    }

    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            val nearbyCount = state.items.count { it.status == RepairJobStatus.Requested }
            EsTopBar(
                title = "Repair",
                subtitle = if (selectedTab == EngineerJobsTab.Available) "$nearbyCount jobs nearby" else null,
            )
            EngineerTabBar(selected = selectedTab, onSelect = { selectedTab = it })
            if (selectedTab == EngineerJobsTab.Available) {
                // Hero stats card — sources counts straight from current state
                // so no extra queries: nearby = items.size (open feed already
                // filtered to verified-near jobs by the VM); pending bids =
                // count of own bids still in Pending status.
                val pendingBidCount = remember(state.ownBidsByJob) {
                    state.ownBidsByJob.values.count { it.status == RepairBidStatus.Pending }
                }
                EngineerRepairHeroCard(
                    nearbyCount = state.items.count { it.status == RepairJobStatus.Requested },
                    pendingBidCount = pendingBidCount,
                    radiusKm = state.radiusKm,
                    hasBase = state.baseLatitude != null && state.baseLongitude != null,
                    onViewEarnings = onViewEarnings,
                    onTuneProfile = onTuneProfile,
                )
                EngineerTipCard()
                SearchHeader(
                    query = state.query,
                    onQueryChange = viewModel::onQueryChange,
                )
                RadiusFilterRow(
                    selected = state.radiusKm,
                    onSelect = viewModel::onRadiusChange,
                    modifier = Modifier.padding(horizontal = 16.dp),
                )
                NearbyJobsMap(
                    baseLatitude = state.baseLatitude,
                    baseLongitude = state.baseLongitude,
                    radiusKm = state.radiusKm,
                    jobs = remember(state.items, state.coordsByJobId, state.distanceByJobId) {
                        state.items.mapNotNull { job ->
                            val coord = state.coordsByJobId[job.id] ?: return@mapNotNull null
                            MapJob(
                                id = job.id,
                                title = job.title,
                                latitude = coord.first,
                                longitude = coord.second,
                                distanceKm = state.distanceByJobId[job.id] ?: 0.0,
                            )
                        }
                    },
                )
            }
            ErrorBanner(message = bannerMessage)

            PullToRefreshBox(
                isRefreshing = state.refreshing,
                onRefresh = viewModel::onRefresh,
                modifier = Modifier.weight(1f).fillMaxWidth(),
            ) {
                when {
                    showLoading -> InitialShimmerList()
                    filtered.isEmpty() -> EmptyState(query = state.query, tab = selectedTab)
                    else -> LazyColumn(
                        state = listState,
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 12.dp),
                        verticalArrangement = Arrangement.spacedBy(10.dp),
                    ) {
                        items(items = filtered, key = { it.id }) { job ->
                            Box(
                                modifier = Modifier.fillMaxWidth(),
                                contentAlignment = Alignment.TopCenter,
                            ) {
                                RepairJobCard(
                                    job = job,
                                    onClick = { onJobClick(job.id) },
                                    ownBid = state.ownBidsByJob[job.id],
                                    modifier = Modifier.maxContentWidth(),
                                )
                            }
                        }
                        if (selectedTab == EngineerJobsTab.Available) {
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
                            } else if (state.endReached && state.items.isNotEmpty()) {
                                item("end") {
                                    Text(
                                        text = "That's all the open jobs we have right now.",
                                        style = EsType.Caption,
                                        color = SevaInk500,
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
}

@Composable
private fun EngineerTabBar(
    selected: EngineerJobsTab,
    onSelect: (EngineerJobsTab) -> Unit,
) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .background(Color.White)
            .padding(horizontal = 16.dp),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .horizontalScroll(rememberScrollState()),
            horizontalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            EngineerJobsTab.entries.forEach { tab ->
                JobsTabPill(
                    label = tab.label,
                    selected = tab == selected,
                    onClick = { onSelect(tab) },
                )
            }
        }
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(1.dp)
                .background(BorderDefault)
                .align(Alignment.BottomCenter),
        )
    }
}

@Composable
private fun JobsTabPill(
    label: String,
    selected: Boolean,
    onClick: () -> Unit,
) {
    Column(
        modifier = Modifier
            .clickable(onClick = onClick)
            .padding(horizontal = 12.dp, vertical = 10.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            text = label,
            style = EsType.Label.copy(fontWeight = FontWeight.SemiBold),
            color = if (selected) SevaInk900 else SevaInk500,
        )
        Box(
            modifier = Modifier
                .padding(top = 8.dp)
                .height(2.dp)
                .fillMaxWidth()
                .background(if (selected) SevaGreen700 else Color.Transparent),
        )
    }
}

@Composable
private fun SearchHeader(query: String, onQueryChange: (String) -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp),
    ) {
        EsField(
            value = query,
            onChange = onQueryChange,
            placeholder = "Search by issue, brand, model",
            leading = {
                Icon(Icons.Filled.Search, contentDescription = null, tint = SevaInk500, modifier = Modifier.size(18.dp))
            },
        )
    }
}

@Composable
private fun InitialShimmerList() {
    Column(modifier = Modifier.fillMaxSize()) {
        repeat(4) { ShimmerListItem() }
    }
}

@Composable
private fun EmptyState(query: String, tab: EngineerJobsTab) {
    when {
        query.isNotBlank() -> EmptyStateView(
            icon = Icons.Outlined.Build,
            title = "No jobs matched \"$query\".",
            subtitle = "Try a different search or clear the filter.",
        )
        tab == EngineerJobsTab.Mine -> EmptyStateView(
            icon = Icons.Outlined.Build,
            title = "No jobs assigned yet",
            subtitle = "Jobs you accept will show up here.",
        )
        else -> EmptyStateView(
            icon = Icons.Outlined.Build,
            title = "No open jobs nearby",
            subtitle = "Posted jobs will show up here.",
        )
    }
}

@Composable
private fun RadiusFilterRow(
    selected: Int?,
    onSelect: (Int?) -> Unit,
    modifier: Modifier = Modifier,
) {
    val options = listOf(10, 25, 50, 100)
    Row(
        modifier = modifier
            .fillMaxWidth()
            .horizontalScroll(rememberScrollState())
            .padding(bottom = 8.dp),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        options.forEach { km ->
            EsChip(
                text = "${km} km",
                active = selected == km,
                onClick = { onSelect(km) },
            )
        }
        EsChip(text = "All", active = selected == null, onClick = { onSelect(null) })
    }
}
