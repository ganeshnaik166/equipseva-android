package com.equipseva.app.features.marketplace

import androidx.compose.foundation.BorderStroke
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
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Apps
import androidx.compose.material.icons.filled.Biotech
import androidx.compose.material.icons.filled.Build
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.MonitorHeart
import androidx.compose.material.icons.filled.Radar
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.outlined.Inventory2
import androidx.compose.material.icons.outlined.MedicalServices
import androidx.compose.material.icons.outlined.ShoppingCart
import androidx.compose.material3.Badge
import androidx.compose.material3.BadgedBox
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
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
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.core.data.parts.MarketplaceSort
import com.equipseva.app.core.data.parts.PartCategory
import com.equipseva.app.core.data.parts.SparePart
import com.equipseva.app.core.util.formatRupees
import com.equipseva.app.designsystem.adaptiveGridColumns
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.ErrorBanner
import com.equipseva.app.designsystem.components.GradientTile
import com.equipseva.app.designsystem.components.SectionHeader
import com.equipseva.app.designsystem.components.ShimmerBox
import com.equipseva.app.designsystem.maxContentWidth
import com.equipseva.app.designsystem.theme.BrandGreen
import com.equipseva.app.designsystem.theme.BrandGreenDark
import com.equipseva.app.designsystem.theme.Ink500
import com.equipseva.app.designsystem.theme.Ink700
import com.equipseva.app.designsystem.theme.Ink900
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.designsystem.theme.Surface0
import com.equipseva.app.designsystem.theme.Surface200
import com.equipseva.app.designsystem.theme.Surface50
import com.equipseva.app.features.marketplace.components.PartCard
import com.equipseva.app.features.marketplace.components.categoryHue
import com.equipseva.app.features.marketplace.components.categoryIcon

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
    val favorites by viewModel.favorites.collectAsStateWithLifecycle()

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

    val isFilteringOrSearching = state.query.isNotBlank() || state.selectedCategory != null

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Surface50),
    ) {
        MarketplaceHeader(
            query = state.query,
            onQueryChange = viewModel::onQueryChange,
            cartCount = cartCount,
            onOpenCart = onOpenCart,
        )
        CategoryRow(
            selected = state.selectedCategory,
            onCategorySelected = viewModel::onCategorySelected,
        )
        SortRow(
            selected = state.sort,
            onSortSelected = viewModel::onSortSelected,
        )
        ErrorBanner(
            message = state.errorMessage,
            modifier = Modifier.padding(horizontal = Spacing.lg, vertical = Spacing.xs),
        )

        PullToRefreshBox(
            isRefreshing = state.refreshing,
            onRefresh = viewModel::onRefresh,
            modifier = Modifier.weight(1f).fillMaxWidth(),
        ) {
            when {
                state.initialLoading && state.items.isEmpty() -> MarketplaceShimmerList()
                state.items.isEmpty() -> EmptyState()
                isFilteringOrSearching -> SearchResultsList(
                    state = state,
                    listState = listState,
                    favorites = favorites,
                    onToggleFavorite = viewModel::onToggleFavorite,
                    onPartClick = onPartClick,
                )
                else -> MarketplaceHome(
                    items = state.items,
                    onPartClick = onPartClick,
                )
            }
        }
    }
}

/* ------------------------------------------------------------------ */
/* Header with title + cart + search pill                             */
/* ------------------------------------------------------------------ */

@Composable
private fun MarketplaceHeader(
    query: String,
    onQueryChange: (String) -> Unit,
    cartCount: Int,
    onOpenCart: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(Surface0)
            .padding(start = Spacing.lg, end = Spacing.lg, top = Spacing.sm, bottom = Spacing.lg),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = "Marketplace",
                fontSize = 20.sp,
                lineHeight = 24.sp,
                fontWeight = FontWeight.Bold,
                color = Ink900,
                modifier = Modifier.weight(1f),
            )
            Box(
                modifier = Modifier
                    .size(40.dp)
                    .clip(CircleShape)
                    .background(Surface50)
                    .clickable(onClick = onOpenCart),
                contentAlignment = Alignment.Center,
            ) {
                if (cartCount > 0) {
                    BadgedBox(badge = { Badge { Text(cartCount.toString()) } }) {
                        Icon(
                            imageVector = Icons.Outlined.ShoppingCart,
                            contentDescription = "Cart",
                            tint = Ink700,
                        )
                    }
                } else {
                    Icon(
                        imageVector = Icons.Outlined.ShoppingCart,
                        contentDescription = "Cart",
                        tint = Ink700,
                    )
                }
            }
        }
        Spacer(Modifier.height(Spacing.md))
        SearchPill(query = query, onQueryChange = onQueryChange)
    }
}

@Composable
private fun SearchPill(query: String, onQueryChange: (String) -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(48.dp)
            .clip(RoundedCornerShape(50))
            .background(Surface50)
            .border(1.dp, Surface200, RoundedCornerShape(50))
            .padding(horizontal = 16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Icon(
            imageVector = Icons.Filled.Search,
            contentDescription = null,
            tint = Ink500,
            modifier = Modifier.size(20.dp),
        )
        // We render the live query as text; the field behaves as a live filter
        // because the ViewModel fires on every character via `onQueryChange`.
        androidx.compose.foundation.text.BasicTextField(
            value = query,
            onValueChange = onQueryChange,
            singleLine = true,
            textStyle = MaterialTheme.typography.bodyMedium.copy(
                color = Ink900,
                fontSize = 14.sp,
            ),
            modifier = Modifier.weight(1f),
            decorationBox = { inner ->
                Box(contentAlignment = Alignment.CenterStart) {
                    if (query.isEmpty()) {
                        Text(
                            text = "Search parts, brands, models…",
                            fontSize = 14.sp,
                            color = Ink500,
                        )
                    }
                    inner()
                }
            },
        )
        Icon(
            imageVector = Icons.Filled.Mic,
            contentDescription = null,
            tint = Ink500,
            modifier = Modifier.size(18.dp),
        )
    }
}

/* ------------------------------------------------------------------ */
/* Category chip row                                                  */
/* ------------------------------------------------------------------ */

private data class CatEntry(val category: PartCategory?, val label: String, val icon: ImageVector)

@Composable
private fun CategoryRow(
    selected: PartCategory?,
    onCategorySelected: (PartCategory?) -> Unit,
) {
    // Design: All / Imaging / Monitoring / Surgical / Consumables / Lab.
    // Android categories we actually have: Cardiology, ImagingRadiology, LifeSupport,
    // PatientMonitoring, Sterilization, Other. We map the visible labels onto our keys
    // and show the remaining DB categories as-is.
    val entries = listOf(
        CatEntry(null, "All", Icons.Filled.Apps),
        CatEntry(PartCategory.ImagingRadiology, "Imaging", Icons.Filled.Radar),
        CatEntry(PartCategory.PatientMonitoring, "Monitoring", Icons.Filled.MonitorHeart),
        CatEntry(PartCategory.Cardiology, "Cardiology", Icons.Filled.Favorite),
        CatEntry(PartCategory.Sterilization, "Sterilization", Icons.Outlined.MedicalServices),
        CatEntry(PartCategory.LifeSupport, "Life support", Icons.Filled.Build),
        CatEntry(PartCategory.Other, "Lab", Icons.Filled.Biotech),
    )

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(Surface0)
            .horizontalScroll(rememberScrollState())
            .padding(horizontal = Spacing.lg, vertical = Spacing.sm),
        horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
    ) {
        entries.forEach { entry ->
            CategoryChip(
                label = entry.label,
                icon = entry.icon,
                selected = selected == entry.category,
                onClick = {
                    if (entry.category == null || selected == entry.category) {
                        onCategorySelected(null)
                    } else {
                        onCategorySelected(entry.category)
                    }
                },
            )
        }
    }
}

@Composable
private fun CategoryChip(
    label: String,
    icon: ImageVector,
    selected: Boolean,
    onClick: () -> Unit,
) {
    val bg = if (selected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.surface
    val fg = if (selected) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSurfaceVariant
    val border = if (selected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.outlineVariant

    Row(
        modifier = Modifier
            .height(32.dp)
            .clip(RoundedCornerShape(50))
            .background(bg)
            .border(1.dp, border, RoundedCornerShape(50))
            .clickable(onClick = onClick)
            .padding(horizontal = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = fg,
            modifier = Modifier.size(16.dp),
        )
        Text(
            text = label,
            fontSize = 13.sp,
            lineHeight = 16.sp,
            fontWeight = FontWeight.SemiBold,
            color = fg,
        )
    }
}

/* ------------------------------------------------------------------ */
/* Home layout: featured rail, recent rail, manufacturer grid         */
/* ------------------------------------------------------------------ */

@Composable
private fun MarketplaceHome(
    items: List<SparePart>,
    onPartClick: (String) -> Unit,
) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(bottom = Spacing.xl),
        verticalArrangement = Arrangement.spacedBy(0.dp),
    ) {
        item("featured_header") {
            SectionHeader(title = "Featured parts")
        }
        item("featured_rail") {
            val featured = items.take(6)
            if (featured.isEmpty()) return@item
            LazyRow(
                contentPadding = PaddingValues(horizontal = Spacing.lg),
                horizontalArrangement = Arrangement.spacedBy(Spacing.md),
            ) {
                items(items = featured, key = { "f-${it.id}" }) { part ->
                    FeaturedCard(part = part, onClick = { onPartClick(part.id) })
                }
            }
        }

        item("brands_header") {
            SectionHeader(title = "Shop by manufacturer")
        }
        item("brands_grid") {
            ManufacturerGrid(items = items)
        }
    }
}

@Composable
private fun FeaturedCard(part: SparePart, onClick: () -> Unit) {
    Column(
        modifier = Modifier
            .width(170.dp)
            .clip(RoundedCornerShape(5.dp))
            .background(Surface0)
            .border(1.dp, Surface200, RoundedCornerShape(5.dp))
            .clickable(onClick = onClick),
    ) {
        GradientTile(
            icon = categoryIcon(part.category),
            hue = categoryHue(part.category),
            size = 170.dp,
        )
        Column(
            modifier = Modifier.padding(12.dp),
            verticalArrangement = Arrangement.spacedBy(2.dp),
        ) {
            val brand = part.compatibleBrands.firstOrNull().orEmpty()
            if (brand.isNotBlank()) {
                Text(
                    text = brand,
                    fontSize = 11.sp,
                    lineHeight = 14.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = Ink500,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            Text(
                text = part.name,
                fontSize = 13.sp,
                lineHeight = 16.sp,
                fontWeight = FontWeight.SemiBold,
                color = Ink900,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                text = formatRupees(part.priceRupees),
                fontSize = 14.sp,
                lineHeight = 18.sp,
                fontWeight = FontWeight.Bold,
                color = BrandGreenDark,
                modifier = Modifier.padding(top = 4.dp),
            )
        }
    }
}

@Composable
private fun ManufacturerGrid(items: List<SparePart>) {
    // Adaptive column count: 2 on phones, 3 on small tablets, 4 on large tablets.
    val cols = adaptiveGridColumns(compact = 2, medium = 3, expanded = 4)
    // Derive brand list strictly from the data — no fabricated fallback names.
    val brands = items
        .flatMap { it.compatibleBrands }
        .filter { it.isNotBlank() }
        .distinct()
        .take(cols * 2)

    if (brands.isEmpty()) {
        // Real catalogue hasn't been seeded with brand-tagged parts yet. Show a
        // neutral note rather than fake brand tiles so the user isn't misled.
        Text(
            text = "Brand tiles will appear here once parts with compatible-brand tags are listed.",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = Spacing.lg, vertical = Spacing.md),
        )
        return
    }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = Spacing.lg, vertical = Spacing.sm),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        brands.chunked(cols).forEach { row ->
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                row.forEach { brand ->
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .aspectRatio(1.4f)
                            .clip(RoundedCornerShape(5.dp))
                            .background(Surface0)
                            .border(1.dp, Surface200, RoundedCornerShape(5.dp)),
                        contentAlignment = Alignment.Center,
                    ) {
                        Text(
                            text = brand,
                            fontSize = 13.sp,
                            lineHeight = 16.sp,
                            fontWeight = FontWeight.Bold,
                            color = Ink700,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                        )
                    }
                }
                // fill the row so remaining slots keep alignment if fewer than cols
                repeat(cols - row.size) { Spacer(Modifier.weight(1f)) }
            }
        }
    }
}

/* ------------------------------------------------------------------ */
/* Search results list                                                */
/* ------------------------------------------------------------------ */

@Composable
private fun SearchResultsList(
    state: com.equipseva.app.features.marketplace.state.MarketplaceUiState,
    listState: androidx.compose.foundation.lazy.LazyListState,
    favorites: Set<String>,
    onToggleFavorite: (String) -> Unit,
    onPartClick: (String) -> Unit,
) {
    LazyColumn(
        state = listState,
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(horizontal = Spacing.lg, vertical = Spacing.md),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        item("count") {
            Text(
                text = "${state.items.size} results",
                fontSize = 12.sp,
                lineHeight = 15.sp,
                fontWeight = FontWeight.SemiBold,
                color = Ink500,
                modifier = Modifier.padding(bottom = Spacing.xs),
            )
        }
        items(items = state.items, key = { it.id }) { part ->
            Box(
                modifier = Modifier.fillMaxWidth(),
                contentAlignment = Alignment.TopCenter,
            ) {
                PartCard(
                    part = part,
                    isFavorite = part.id in favorites,
                    onToggleFavorite = { onToggleFavorite(part.id) },
                    onClick = { onPartClick(part.id) },
                    modifier = Modifier.maxContentWidth(),
                )
            }
        }
        if (state.loadingMore) {
            item("loading_more") {
                Box(
                    modifier = Modifier.fillMaxWidth().padding(Spacing.md),
                    contentAlignment = Alignment.Center,
                ) {
                    CircularProgressIndicator(modifier = Modifier.size(24.dp), strokeWidth = 2.dp)
                }
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

/* ------------------------------------------------------------------ */
/* Shimmer + empty state                                              */
/* ------------------------------------------------------------------ */

@Composable
private fun MarketplaceShimmerList() {
    Column(modifier = Modifier.fillMaxSize()) {
        repeat(4) {
            ShimmerBox(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 6.dp)
                    .height(120.dp),
                shape = RoundedCornerShape(5.dp),
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

@Composable
private fun SortRow(
    selected: MarketplaceSort,
    onSortSelected: (MarketplaceSort) -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(Surface0)
            .horizontalScroll(rememberScrollState())
            .padding(horizontal = Spacing.lg, vertical = Spacing.xs),
        horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = "Sort",
            style = MaterialTheme.typography.labelMedium,
            color = Ink500,
        )
        MarketplaceSort.entries.forEach { sort ->
            FilterChip(
                selected = selected == sort,
                onClick = { onSortSelected(sort) },
                label = { Text(sort.displayName) },
            )
        }
    }
}
