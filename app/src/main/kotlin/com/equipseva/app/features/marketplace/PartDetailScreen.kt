package com.equipseva.app.features.marketplace

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.outlined.Inventory2
import androidx.compose.material.icons.outlined.ShoppingCart
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import coil3.compose.AsyncImage
import com.equipseva.app.core.data.parts.SparePart
import com.equipseva.app.core.util.formatRupees
import com.equipseva.app.designsystem.components.ErrorBanner
import com.equipseva.app.designsystem.components.PrimaryButton
import com.equipseva.app.designsystem.theme.Spacing

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PartDetailScreen(
    onBack: () -> Unit,
    onShowMessage: (String) -> Unit,
    onOpenCart: () -> Unit = {},
    viewModel: PartDetailViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    LaunchedEffect(viewModel) {
        viewModel.messages.collect { onShowMessage(it) }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(state.part?.name ?: "Part details") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
                    IconButton(onClick = onOpenCart) {
                        Icon(Icons.Outlined.ShoppingCart, contentDescription = "Cart")
                    }
                },
            )
        },
    ) { padding ->
        Box(modifier = Modifier.padding(padding).fillMaxSize()) {
            when {
                state.loading -> Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }
                state.notFound -> NotFoundState(onBack)
                state.errorMessage != null -> ErrorState(message = state.errorMessage!!, onRetry = viewModel::retry)
                state.part != null -> PartBody(
                    part = state.part!!,
                    addingToCart = state.addingToCart,
                    onAddToCart = viewModel::onAddToCart,
                )
            }
        }
    }
}

@Composable
private fun PartBody(part: SparePart, addingToCart: Boolean, onAddToCart: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(Spacing.lg),
        verticalArrangement = Arrangement.spacedBy(Spacing.md),
    ) {
        ImageCarousel(part.imageUrls)

        Text(part.name, style = MaterialTheme.typography.headlineSmall)
        Text(
            text = "Part #${part.partNumber} · SKU ${part.sku.ifBlank { "—" }}",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )

        PriceBlock(part)
        StockChip(part)

        if (part.description.isNotBlank()) {
            SectionTitle("Description")
            Text(part.description, style = MaterialTheme.typography.bodyMedium)
        }

        SectionTitle("Compatibility")
        SpecRow("Brands", part.compatibleBrands.takeIf { it.isNotEmpty() }?.joinToString(", ") ?: "—")
        SpecRow("Models", part.compatibleModels.takeIf { it.isNotEmpty() }?.joinToString(", ") ?: "—")

        SectionTitle("Details")
        SpecRow("Category", part.category.displayName)
        SpecRow("Genuine", if (part.isGenuine) "Yes" else "No")
        SpecRow("OEM", if (part.isOem) "Yes" else "No")
        SpecRow("Warranty", if (part.warrantyMonths > 0) "${part.warrantyMonths} months" else "Not covered")
        SpecRow("Min order", "${part.minimumOrderQuantity} ${part.unit}")
        SpecRow("GST", "${part.gstRatePercent.toInt()}%")

        PrimaryButton(
            label = when {
                !part.inStock -> "Out of stock"
                addingToCart -> "Adding…"
                else -> "Add to cart"
            },
            onClick = onAddToCart,
            enabled = part.inStock && !addingToCart,
        )
    }
}

@Composable
private fun ImageCarousel(urls: List<String>) {
    val shape = RoundedCornerShape(Spacing.md)
    if (urls.isEmpty()) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .aspectRatio(16f / 9f)
                .clip(shape)
                .background(MaterialTheme.colorScheme.surfaceVariant),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = Icons.Outlined.Inventory2,
                contentDescription = null,
                modifier = Modifier.size(64.dp),
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        return
    }
    LazyRow(
        modifier = Modifier.fillMaxWidth(),
        contentPadding = PaddingValues(end = Spacing.md),
        horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
    ) {
        itemsIndexed(items = urls, key = { i, url -> "$i-$url" }) { i, url ->
            AsyncImage(
                model = url,
                contentDescription = "Photo ${i + 1} of ${urls.size}",
                contentScale = ContentScale.Crop,
                modifier = Modifier
                    .fillParentMaxWidth(0.88f)
                    .aspectRatio(16f / 9f)
                    .clip(shape)
                    .background(MaterialTheme.colorScheme.surfaceVariant),
            )
        }
    }
}

@Composable
private fun PriceBlock(part: SparePart) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Spacing.md),
    ) {
        Text(
            text = formatRupees(part.priceRupees),
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.SemiBold,
        )
        if (part.mrpRupees != null && part.mrpRupees > part.priceRupees) {
            Text(
                text = formatRupees(part.mrpRupees),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textDecoration = TextDecoration.LineThrough,
            )
            if (part.discountPercent > 0) {
                Surface(
                    color = MaterialTheme.colorScheme.tertiaryContainer,
                    contentColor = MaterialTheme.colorScheme.onTertiaryContainer,
                    shape = RoundedCornerShape(Spacing.xs),
                ) {
                    Text(
                        text = "${part.discountPercent}% off",
                        style = MaterialTheme.typography.labelMedium,
                        modifier = Modifier.padding(horizontal = Spacing.sm, vertical = Spacing.xxs),
                    )
                }
            }
        }
    }
}

@Composable
private fun StockChip(part: SparePart) {
    val (text, color) = when {
        !part.inStock -> "Out of stock" to MaterialTheme.colorScheme.error
        part.stockQuantity < 10 -> "Only ${part.stockQuantity} left in stock" to MaterialTheme.colorScheme.tertiary
        else -> "${part.stockQuantity} in stock" to MaterialTheme.colorScheme.primary
    }
    Text(text = text, style = MaterialTheme.typography.titleSmall, color = color)
}

@Composable
private fun SectionTitle(text: String) {
    Text(
        text = text,
        style = MaterialTheme.typography.titleMedium,
        modifier = Modifier.padding(top = Spacing.sm),
    )
}

@Composable
private fun SpecRow(label: String, value: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(Spacing.md),
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.weight(1f),
        )
        Text(
            text = value,
            style = MaterialTheme.typography.bodyMedium,
            modifier = Modifier.weight(2f),
        )
    }
}

@Composable
private fun NotFoundState(onBack: () -> Unit) {
    Column(
        modifier = Modifier.fillMaxSize().padding(Spacing.xl),
        verticalArrangement = Arrangement.spacedBy(Spacing.md, Alignment.CenterVertically),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text("This part isn't available anymore.", style = MaterialTheme.typography.titleMedium)
        Button(onClick = onBack) { Text("Back to parts") }
    }
}

@Composable
private fun ErrorState(message: String, onRetry: () -> Unit) {
    Column(
        modifier = Modifier.fillMaxSize().padding(Spacing.xl),
        verticalArrangement = Arrangement.spacedBy(Spacing.md, Alignment.CenterVertically),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        ErrorBanner(message = message)
        Button(onClick = onRetry) { Text("Retry") }
    }
}

