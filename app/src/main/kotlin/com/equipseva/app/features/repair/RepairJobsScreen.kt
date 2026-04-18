package com.equipseva.app.features.repair

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
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
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.designsystem.components.ESTopBar
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.ErrorBanner
import com.equipseva.app.designsystem.components.ShimmerListItem
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.features.repair.components.RepairJobCard

/**
 * Engineer-facing feed of open repair jobs. Pull-to-refresh and paged list,
 * with optional ILIKE search against issue/brand/model. Card taps are a stub
 * today — the detail / bidding screens land in a later phase.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RepairJobsScreen(
    onJobClick: (jobId: String) -> Unit = {},
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

    Scaffold(topBar = { ESTopBar(title = "Repair jobs") }) { inner ->
        Column(modifier = Modifier.fillMaxSize().padding(inner)) {
            SearchHeader(
                query = state.query,
                onQueryChange = viewModel::onQueryChange,
            )
            ErrorBanner(
                message = state.errorMessage,
                modifier = Modifier.padding(horizontal = Spacing.lg),
            )

            PullToRefreshBox(
                isRefreshing = state.refreshing,
                onRefresh = viewModel::onRefresh,
                modifier = Modifier.weight(1f).fillMaxWidth(),
            ) {
                when {
                    state.initialLoading -> InitialShimmerList()
                    state.items.isEmpty() -> EmptyState(query = state.query)
                    else -> LazyColumn(
                        state = listState,
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(horizontal = Spacing.lg, vertical = Spacing.md),
                        verticalArrangement = Arrangement.spacedBy(Spacing.md),
                    ) {
                        items(items = state.items, key = { it.id }) { job ->
                            RepairJobCard(job = job, onClick = { onJobClick(job.id) })
                        }
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
private fun EmptyState(query: String) {
    if (query.isBlank()) {
        EmptyStateView(
            icon = Icons.Outlined.Build,
            title = "No repair jobs yet",
            subtitle = "Posted jobs will show up here.",
        )
    } else {
        EmptyStateView(
            icon = Icons.Outlined.Build,
            title = "No jobs matched \"$query\".",
            subtitle = "Try a different search or clear the filter.",
        )
    }
}
