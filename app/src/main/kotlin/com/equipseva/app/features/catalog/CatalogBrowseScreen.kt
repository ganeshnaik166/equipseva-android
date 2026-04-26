package com.equipseva.app.features.catalog

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.ui.layout.ContentScale
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.remember
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Image
import androidx.compose.material.icons.outlined.Inbox
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.equipseva.app.core.data.catalog.CatalogReferenceRepository
import com.equipseva.app.designsystem.components.ESBackTopBar
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.theme.BrandGreen
import com.equipseva.app.designsystem.theme.Ink500
import com.equipseva.app.designsystem.theme.Ink700
import com.equipseva.app.designsystem.theme.Ink900
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.designsystem.theme.Surface0
import com.equipseva.app.designsystem.theme.Surface200
import com.equipseva.app.designsystem.theme.Surface50
import java.text.NumberFormat
import java.util.Locale

@Composable
fun CatalogBrowseScreen(
    onBack: () -> Unit,
    onOpenDetail: (CatalogReferenceRepository.Item) -> Unit,
    onRequestQuote: (CatalogReferenceRepository.Item) -> Unit,
    viewModel: CatalogBrowseViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsState()
    val context = LocalContext.current
    val listState = rememberLazyListState()

    // Trigger load-more when the user is within ~5 cards of the end of the list.
    // Compose recomputes this whenever visible-items change, so it auto-fires on scroll.
    val reachedEnd by remember {
        derivedStateOf {
            val last = listState.layoutInfo.visibleItemsInfo.lastOrNull()
            val total = listState.layoutInfo.totalItemsCount
            last != null && total > 0 && last.index >= total - 5
        }
    }
    LaunchedEffect(reachedEnd, state.items.size) {
        if (reachedEnd && !state.loading && !state.loadingMore && !state.endReached) {
            viewModel.loadMore()
        }
    }

    Scaffold(topBar = { ESBackTopBar(title = "Hospital catalogue", onBack = onBack) }) { padding ->
        Column(modifier = Modifier.fillMaxSize().padding(padding).background(Surface50)) {
            OutlinedTextField(
                value = state.query,
                onValueChange = viewModel::onQueryChange,
                placeholder = { Text("Search 25,000+ items…") },
                singleLine = true,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = Spacing.md, vertical = Spacing.sm),
            )
            // Category chip row (department)
            LazyRow(
                contentPadding = PaddingValues(horizontal = Spacing.md),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                items(state.categories.size + 1) { i ->
                    if (i == 0) {
                        FilterChip(
                            selected = state.category == null,
                            onClick = { viewModel.onCategoryChange(null) },
                            label = { Text("All categories") },
                        )
                    } else {
                        val cat = state.categories[i - 1]
                        FilterChip(
                            selected = state.category == cat,
                            onClick = { viewModel.onCategoryChange(cat) },
                            label = { Text(cat) },
                        )
                    }
                }
            }
            Spacer(Modifier.height(6.dp))
            // Type chip row (Capital / Implant / Consumable / Spare)
            LazyRow(
                contentPadding = PaddingValues(horizontal = Spacing.md),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                items(state.types.size + 1) { i ->
                    if (i == 0) {
                        FilterChip(
                            selected = state.type == null,
                            onClick = { viewModel.onTypeChange(null) },
                            label = { Text("All types") },
                        )
                    } else {
                        val t = state.types[i - 1]
                        FilterChip(
                            selected = state.type == t,
                            onClick = { viewModel.onTypeChange(t) },
                            label = { Text(t) },
                        )
                    }
                }
            }
            Box(modifier = Modifier.fillMaxSize()) {
                when {
                    state.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator()
                    }
                    state.error != null -> EmptyStateView(
                        icon = Icons.Outlined.Inbox,
                        title = "Couldn't load",
                        subtitle = state.error,
                    )
                    state.items.isEmpty() -> EmptyStateView(
                        icon = Icons.Outlined.Inbox,
                        title = "No matches",
                        subtitle = "Try a different keyword or clear the filter.",
                    )
                    else -> LazyColumn(
                        state = listState,
                        contentPadding = PaddingValues(Spacing.md),
                        verticalArrangement = Arrangement.spacedBy(Spacing.sm),
                    ) {
                        items(state.items, key = { it.id }) { item ->
                            CatalogRow(
                                item = item,
                                onClick = {
                                    // OpenFDA items use synthetic negative ids
                                    // and aren't in our DB, so the detail
                                    // screen can't fetch them. Send the user
                                    // straight to the RFQ form for those.
                                    if (item.id < 0) onRequestQuote(item)
                                    else onOpenDetail(item)
                                },
                                onRequestQuote = { onRequestQuote(item) },
                                onOpenImage = {
                                    item.imageSearchUrl?.let { url ->
                                        runCatching {
                                            context.startActivity(
                                                android.content.Intent(
                                                    android.content.Intent.ACTION_VIEW,
                                                    android.net.Uri.parse(url),
                                                ),
                                            )
                                        }
                                    }
                                },
                            )
                        }
                        // Footer: spinner while loading more, end-of-list marker once exhausted.
                        item(key = "footer") {
                            if (state.loadingMore) {
                                Box(
                                    modifier = Modifier.fillMaxWidth().padding(Spacing.md),
                                    contentAlignment = Alignment.Center,
                                ) {
                                    CircularProgressIndicator(
                                        modifier = Modifier.size(28.dp),
                                        strokeWidth = 2.dp,
                                    )
                                }
                            } else if (state.endReached) {
                                Text(
                                    text = "End of catalogue · ${state.totalLoaded} items",
                                    color = Ink500,
                                    fontSize = 12.sp,
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
private fun CatalogRow(
    item: CatalogReferenceRepository.Item,
    onClick: () -> Unit,
    onRequestQuote: () -> Unit,
    onOpenImage: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(Surface0)
            .border(1.dp, Surface200, RoundedCornerShape(14.dp))
            .clickable(onClick = onClick)
            .padding(Spacing.md),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        if (!item.imageUrl.isNullOrBlank()) {
            coil3.compose.AsyncImage(
                model = item.imageUrl,
                contentDescription = null,
                contentScale = ContentScale.Crop,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(160.dp)
                    .clip(RoundedCornerShape(10.dp))
                    .background(Surface200),
            )
            Spacer(Modifier.height(2.dp))
        }
        Text(item.itemName, fontWeight = FontWeight.Bold, color = Ink900, fontSize = 15.sp)
        val brandLine = listOfNotNull(item.brand, item.model).joinToString(" · ")
        if (brandLine.isNotBlank()) {
            Text(brandLine, color = Ink700, fontSize = 13.sp)
        }
        val metaLine = listOfNotNull(item.subCategory, item.type).joinToString(" · ")
        if (metaLine.isNotBlank()) {
            Text(metaLine, color = Ink500, fontSize = 11.sp)
        }
        if (!item.keySpecifications.isNullOrBlank()) {
            Text(
                item.keySpecifications,
                color = Ink700,
                fontSize = 12.sp,
                maxLines = 2,
            )
        }
        val priceText = formatPriceRange(item.priceInrLow, item.priceInrHigh, item.market)
        Text(priceText, color = BrandGreen, fontWeight = FontWeight.Bold, fontSize = 13.sp)
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            if (!item.imageSearchUrl.isNullOrBlank()) {
                OutlinedButton(onClick = onOpenImage) {
                    Icon(Icons.Filled.Image, contentDescription = null, modifier = Modifier.padding(end = 6.dp))
                    Text("Images", fontSize = 12.sp)
                }
            }
            OutlinedButton(onClick = onRequestQuote, modifier = Modifier.weight(1f)) {
                Text("Request a quote", fontSize = 12.sp)
            }
        }
    }
}

private fun formatPriceRange(low: Long?, high: Long?, market: String): String {
    if (low == null && high == null) {
        return if (market == "India") "Price on request" else "Reference (no price)"
    }
    val nf = NumberFormat.getInstance(Locale("en", "IN"))
    val lo = low?.let { "₹${nf.format(it)}" } ?: "?"
    val hi = high?.let { "₹${nf.format(it)}" } ?: "?"
    return if (lo == hi) lo else "$lo – $hi"
}
