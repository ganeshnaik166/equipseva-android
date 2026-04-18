package com.equipseva.app.features.marketplace

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
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.outlined.Inventory2
import androidx.compose.material.icons.outlined.ShoppingCart
import androidx.compose.material3.Badge
import androidx.compose.material3.BadgedBox
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
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
import com.equipseva.app.core.data.parts.PartCategory
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.ErrorBanner
import com.equipseva.app.designsystem.components.ShimmerBox
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.features.marketplace.components.PartCard

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MarketplaceScreen(
    onPartClick: (partId: String) -> Unit,
    onOpenCart: () -> Unit = {},
    viewModel: MarketplaceViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val listState = rememberLazyListState()
    val cartCount by viewModel.cartCount.collectAsStateWithLifecycle()

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

    Column(modifier = Modifier.fillMaxSize()) {
        SearchHeader(
            query = state.query,
            onQueryChange = viewModel::onQueryChange,
            cartCount = cartCount,
            onOpenCart = onOpenCart,
        )
        CategoryRow(
            selected = state.selectedCategory,
            onCategorySelected = viewModel::onCategorySelected,
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
                state.initialLoading && state.items.isEmpty() -> MarketplaceShimmerList()
                state.items.isEmpty() -> EmptyState()
                else -> LazyColumn(
                    state = listState,
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(horizontal = Spacing.lg, vertical = Spacing.md),
                    verticalArrangement = Arrangement.spacedBy(Spacing.md),
                ) {
                    items(items = state.items, key = { it.id }) { part ->
                        PartCard(part = part, onClick = { onPartClick(part.id) })
                    }
                    if (state.loadingMore) {
                        item("loading_more") {
                            Box(
                                modifier = Modifier.fillMaxWidth().padding(Spacing.md),
                                contentAlignment = Alignment.Center,
                            ) { CircularProgressIndicator(modifier = Modifier.size(24.dp), strokeWidth = 2.dp) }
                        }
                    } else if (state.endReached && state.items.isNotEmpty()) {
                        item("end") {
                            Text(
                                text = "That's all we have for this filter.",
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

@Composable
private fun SearchHeader(
    query: String,
    onQueryChange: (String) -> Unit,
    cartCount: Int,
    onOpenCart: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = Spacing.lg, vertical = Spacing.md),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
    ) {
        OutlinedTextField(
            value = query,
            onValueChange = onQueryChange,
            modifier = Modifier.weight(1f),
            placeholder = { Text("Search parts, part numbers") },
            leadingIcon = { Icon(Icons.Filled.Search, contentDescription = null) },
            trailingIcon = if (query.isNotEmpty()) {
                { IconButton(onClick = { onQueryChange("") }) {
                    Icon(Icons.Filled.Close, contentDescription = "Clear search")
                } }
            } else null,
            singleLine = true,
            keyboardOptions = KeyboardOptions(
                keyboardType = KeyboardType.Text,
                imeAction = ImeAction.Search,
            ),
        )
        IconButton(onClick = onOpenCart) {
            if (cartCount > 0) {
                BadgedBox(badge = { Badge { Text(cartCount.toString()) } }) {
                    Icon(Icons.Outlined.ShoppingCart, contentDescription = "Cart")
                }
            } else {
                Icon(Icons.Outlined.ShoppingCart, contentDescription = "Cart")
            }
        }
    }
}

@Composable
private fun CategoryRow(
    selected: PartCategory?,
    onCategorySelected: (PartCategory?) -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .horizontalScroll(rememberScrollState())
            .padding(horizontal = Spacing.lg, vertical = Spacing.xs),
        horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
    ) {
        FilterChip(
            selected = selected == null,
            onClick = { onCategorySelected(null) },
            label = { Text("All") },
            colors = FilterChipDefaults.filterChipColors(),
        )
        PartCategory.UserVisible.forEach { cat ->
            FilterChip(
                selected = selected == cat,
                onClick = { onCategorySelected(if (selected == cat) null else cat) },
                label = { Text(cat.displayName) },
            )
        }
    }
}

@Composable
private fun MarketplaceShimmerList() {
    Column(modifier = Modifier.fillMaxSize()) {
        repeat(4) {
            ShimmerBox(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 6.dp)
                    .height(120.dp),
                shape = MaterialTheme.shapes.medium,
            )
        }
    }
}

@Composable
private fun EmptyState() {
    EmptyStateView(
        icon = Icons.Outlined.Inventory2,
        title = "No parts found",
        subtitle = "Try clearing filters or searching a different term.",
    )
}
