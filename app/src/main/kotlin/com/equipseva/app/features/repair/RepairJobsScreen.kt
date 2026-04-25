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
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.outlined.Build
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
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
import com.equipseva.app.core.data.repair.RepairJob
import com.equipseva.app.core.data.repair.RepairJobStatus
import com.equipseva.app.designsystem.components.ESTopBar
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.ErrorBanner
import com.equipseva.app.designsystem.components.ShimmerListItem
import com.equipseva.app.designsystem.maxContentWidth
import com.equipseva.app.designsystem.theme.BrandGreen
import com.equipseva.app.designsystem.theme.BrandGreenDark
import com.equipseva.app.designsystem.theme.Ink500
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.designsystem.theme.Surface200
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

    Scaffold(topBar = { ESTopBar(title = "Jobs") }) { inner ->
        Column(modifier = Modifier.fillMaxSize().padding(inner)) {
            EngineerTabBar(selected = selectedTab, onSelect = { selectedTab = it })
            if (selectedTab == EngineerJobsTab.Available) {
                SearchHeader(
                    query = state.query,
                    onQueryChange = viewModel::onQueryChange,
                )
            }
            ErrorBanner(
                message = bannerMessage,
                modifier = Modifier.padding(horizontal = Spacing.lg),
            )

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
                        contentPadding = PaddingValues(horizontal = Spacing.lg, vertical = Spacing.md),
                        verticalArrangement = Arrangement.spacedBy(Spacing.md),
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
                                        modifier = Modifier.fillMaxWidth().padding(Spacing.md),
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
                                        style = MaterialTheme.typography.bodySmall,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .padding(Spacing.md),
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
            .background(MaterialTheme.colorScheme.surface)
            .border(1.dp, Surface200)
            .padding(horizontal = Spacing.lg),
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
            fontSize = 13.sp,
            fontWeight = FontWeight.SemiBold,
            color = if (selected) BrandGreenDark else Ink500,
        )
        Box(
            modifier = Modifier
                .padding(top = 8.dp)
                .height(2.dp)
                .fillMaxWidth()
                .background(if (selected) BrandGreen else Color.Transparent),
        )
    }
}

@Composable
private fun SearchHeader(query: String, onQueryChange: (String) -> Unit) {
    OutlinedTextField(
        value = query,
        onValueChange = onQueryChange,
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = Spacing.lg, vertical = Spacing.md),
        placeholder = { Text("Search by issue, brand, model") },
        leadingIcon = { Icon(Icons.Filled.Search, contentDescription = null) },
        trailingIcon = if (query.isNotEmpty()) {
            {
                IconButton(onClick = { onQueryChange("") }) {
                    Icon(Icons.Filled.Close, contentDescription = "Clear search")
                }
            }
        } else null,
        singleLine = true,
        keyboardOptions = KeyboardOptions(
            keyboardType = KeyboardType.Text,
            imeAction = ImeAction.Search,
        ),
    )
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
