package com.equipseva.app.features.marketplace

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.ExpandMore
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Share
import androidx.compose.material.icons.filled.ShoppingCart
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.outlined.FavoriteBorder
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.core.data.parts.SparePart
import com.equipseva.app.core.util.formatRupees
import com.equipseva.app.designsystem.components.ErrorBanner
import com.equipseva.app.designsystem.components.GradientTile
import com.equipseva.app.designsystem.components.QuantityStepper
import com.equipseva.app.designsystem.components.SectionHeader
import com.equipseva.app.designsystem.components.StatusChip
import com.equipseva.app.designsystem.theme.BrandGreen
import com.equipseva.app.designsystem.theme.BrandGreenDark
import com.equipseva.app.designsystem.theme.Ink500
import com.equipseva.app.designsystem.theme.Ink700
import com.equipseva.app.designsystem.theme.Ink900
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.designsystem.theme.Success
import com.equipseva.app.designsystem.theme.SuccessBg
import com.equipseva.app.designsystem.theme.Surface0
import com.equipseva.app.designsystem.theme.Surface200
import com.equipseva.app.features.marketplace.components.categoryHue
import com.equipseva.app.features.marketplace.components.categoryIcon
import com.equipseva.app.features.marketplace.components.stockStatus

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

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Surface0),
    ) {
        Box(modifier = Modifier.weight(1f).fillMaxWidth()) {
            when {
                state.loading -> Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center,
                ) { CircularProgressIndicator() }

                state.notFound -> NotFoundState(onBack)
                state.errorMessage != null -> ErrorState(
                    message = state.errorMessage!!,
                    onRetry = viewModel::retry,
                )
                state.part != null -> PartBody(
                    part = state.part!!,
                    isFavorite = state.isFavorite,
                    onBack = onBack,
                    onOpenCart = onOpenCart,
                    onToggleFavorite = viewModel::onToggleFavorite,
                )
            }
        }

        if (state.part != null) {
            BottomCtaBar(
                part = state.part!!,
                addingToCart = state.addingToCart,
                onAddToCart = viewModel::onAddToCart,
                onBuyNow = viewModel::onAddToCart,
            )
        }
    }
}

/* ------------------------------------------------------------------ */
/* Body                                                               */
/* ------------------------------------------------------------------ */

@Composable
private fun PartBody(
    part: SparePart,
    isFavorite: Boolean,
    onBack: () -> Unit,
    onOpenCart: () -> Unit,
    onToggleFavorite: () -> Unit,
) {
    var quantity by remember { mutableStateOf(1) }
    var specsOpen by remember { mutableStateOf(true) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState()),
    ) {
        Hero(
            part = part,
            isFavorite = isFavorite,
            onBack = onBack,
            onOpenCart = onOpenCart,
            onToggleFavorite = onToggleFavorite,
        )

        // Title block
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(start = 20.dp, end = 20.dp, top = 16.dp, bottom = 20.dp),
            verticalArrangement = Arrangement.spacedBy(2.dp),
        ) {
            val brand = part.compatibleBrands.firstOrNull().orEmpty()
            if (brand.isNotBlank()) {
                Text(
                    text = brand,
                    fontSize = 12.sp,
                    lineHeight = 16.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = Ink500,
                )
            }
            Text(
                text = part.name,
                fontSize = 20.sp,
                lineHeight = 26.sp,
                fontWeight = FontWeight.Bold,
                color = Ink900,
                letterSpacing = (-0.3).sp,
                modifier = Modifier.padding(top = 2.dp),
            )

            Spacer(Modifier.height(8.dp))
            RatingAndStockRow(part = part)

            Spacer(Modifier.height(14.dp))
            PriceRow(part = part)

            Text(
                text = "Inclusive of ${part.gstRatePercent.toInt()}% GST \u00b7 Free delivery on orders above ₹999",
                fontSize = 12.sp,
                lineHeight = 16.sp,
                color = Ink500,
                modifier = Modifier.padding(top = 4.dp),
            )
        }

        // Compatible models
        val models = part.compatibleModels
        if (models.isNotEmpty()) {
            CompatibilitySection(models = models)
        }

        // Quantity
        QuantitySection(
            value = quantity,
            onIncrement = { if (quantity < 99) quantity += 1 },
            onDecrement = { if (quantity > 1) quantity -= 1 },
        )

        // Specifications expander
        SpecificationsSection(
            part = part,
            open = specsOpen,
            onToggle = { specsOpen = !specsOpen },
        )

        // Related parts rail (placeholder — no related-parts endpoint yet)
        SectionHeader(title = "Related parts")
        RelatedPartsRail(part = part)

        Spacer(Modifier.height(Spacing.xl))
    }
}

/* ------------------------------------------------------------------ */
/* Hero                                                               */
/* ------------------------------------------------------------------ */

@Composable
private fun Hero(
    part: SparePart,
    isFavorite: Boolean,
    onBack: () -> Unit,
    onOpenCart: () -> Unit,
    onToggleFavorite: () -> Unit,
) {
    Box(modifier = Modifier.fillMaxWidth()) {
        GradientTile(
            icon = categoryIcon(part.category),
            hue = categoryHue(part.category),
            size = 390.dp,
            modifier = Modifier.align(Alignment.Center),
        )

        // Left overlay: back
        Row(
            modifier = Modifier
                .align(Alignment.TopStart)
                .padding(8.dp),
            horizontalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            OverlayIconButton(onClick = onBack) {
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                    contentDescription = "Back",
                    tint = Ink900,
                    modifier = Modifier.size(20.dp),
                )
            }
        }

        // Right overlays: favorite + share
        Row(
            modifier = Modifier
                .align(Alignment.TopEnd)
                .padding(8.dp),
            horizontalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            OverlayIconButton(onClick = onToggleFavorite) {
                Icon(
                    imageVector = if (isFavorite) Icons.Filled.Favorite else Icons.Outlined.FavoriteBorder,
                    contentDescription = if (isFavorite) "Remove from favorites" else "Add to favorites",
                    tint = if (isFavorite) BrandGreen else Ink900,
                    modifier = Modifier.size(20.dp),
                )
            }
            OverlayIconButton(onClick = onOpenCart) {
                Icon(
                    imageVector = Icons.Filled.Share,
                    contentDescription = "Share",
                    tint = Ink900,
                    modifier = Modifier.size(20.dp),
                )
            }
        }
    }
}

@Composable
private fun OverlayIconButton(
    onClick: () -> Unit,
    content: @Composable () -> Unit,
) {
    Box(
        modifier = Modifier
            .size(40.dp)
            .clip(CircleShape)
            .background(Color.White.copy(alpha = 0.9f))
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) { content() }
}

/* ------------------------------------------------------------------ */
/* Rating + stock chip                                                */
/* ------------------------------------------------------------------ */

@Composable
private fun RatingAndStockRow(part: SparePart) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(3.dp),
        ) {
            Icon(
                imageVector = Icons.Filled.Star,
                contentDescription = null,
                tint = Color(0xFFF5A623),
                modifier = Modifier.size(14.dp),
            )
            // Ratings not in schema yet — static placeholder.
            Text(
                text = "4.7",
                fontSize = 13.sp,
                lineHeight = 16.sp,
                fontWeight = FontWeight.Bold,
                color = Ink900,
            )
            Text(
                text = "(241)",
                fontSize = 12.sp,
                lineHeight = 15.sp,
                color = Ink500,
            )
        }
        Box(
            modifier = Modifier
                .size(4.dp)
                .clip(CircleShape)
                .background(Ink500.copy(alpha = 0.5f)),
        )
        val (tone, icon, label) = stockStatus(part)
        StatusChip(label = label, tone = tone, icon = icon)
    }
}

/* ------------------------------------------------------------------ */
/* Price row                                                          */
/* ------------------------------------------------------------------ */

@Composable
private fun PriceRow(part: SparePart) {
    Row(
        verticalAlignment = Alignment.Bottom,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Text(
            text = formatRupees(part.priceRupees),
            fontSize = 28.sp,
            lineHeight = 32.sp,
            fontWeight = FontWeight.Bold,
            color = BrandGreenDark,
            letterSpacing = (-0.6).sp,
        )
        if (part.mrpRupees != null && part.mrpRupees > part.priceRupees) {
            Text(
                text = formatRupees(part.mrpRupees),
                fontSize = 13.sp,
                lineHeight = 16.sp,
                color = Ink500,
                textDecoration = TextDecoration.LineThrough,
                modifier = Modifier.padding(bottom = 4.dp),
            )
            if (part.discountPercent > 0) {
                Box(
                    modifier = Modifier
                        .padding(bottom = 4.dp)
                        .clip(RoundedCornerShape(50))
                        .background(SuccessBg)
                        .padding(horizontal = 8.dp, vertical = 2.dp),
                ) {
                    Text(
                        text = "${part.discountPercent}% OFF",
                        fontSize = 12.sp,
                        lineHeight = 14.sp,
                        fontWeight = FontWeight.Bold,
                        color = Success,
                    )
                }
            }
        }
    }
}

/* ------------------------------------------------------------------ */
/* Compatibility (FlowRow chips)                                      */
/* ------------------------------------------------------------------ */

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun CompatibilitySection(models: List<String>) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(start = 20.dp, end = 20.dp, bottom = 12.dp),
    ) {
        Text(
            text = "Compatible with",
            fontSize = 13.sp,
            lineHeight = 16.sp,
            fontWeight = FontWeight.Bold,
            color = Ink900,
            modifier = Modifier.padding(bottom = 8.dp),
        )
        FlowRow(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            models.forEach { model ->
                NeutralChip(label = model)
            }
        }
    }
}

@Composable
private fun NeutralChip(label: String) {
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(50))
            .background(Surface0)
            .border(1.dp, Surface200, RoundedCornerShape(50))
            .padding(horizontal = 12.dp, vertical = 6.dp),
    ) {
        Text(
            text = label,
            fontSize = 12.sp,
            lineHeight = 15.sp,
            fontWeight = FontWeight.SemiBold,
            color = Ink700,
        )
    }
}

/* ------------------------------------------------------------------ */
/* Quantity                                                           */
/* ------------------------------------------------------------------ */

@Composable
private fun QuantitySection(
    value: Int,
    onIncrement: () -> Unit,
    onDecrement: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(start = 20.dp, end = 20.dp, bottom = 12.dp),
    ) {
        Text(
            text = "Quantity",
            fontSize = 13.sp,
            lineHeight = 16.sp,
            fontWeight = FontWeight.Bold,
            color = Ink900,
            modifier = Modifier.padding(bottom = 8.dp),
        )
        QuantityStepper(
            value = value,
            onDecrement = onDecrement,
            onIncrement = onIncrement,
        )
    }
}

/* ------------------------------------------------------------------ */
/* Specifications                                                     */
/* ------------------------------------------------------------------ */

@Composable
private fun SpecificationsSection(
    part: SparePart,
    open: Boolean,
    onToggle: () -> Unit,
) {
    val rotation by animateFloatAsState(
        targetValue = if (open) 180f else 0f,
        label = "spec-chev",
    )

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(start = 20.dp, end = 20.dp, bottom = 20.dp),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .border(1.dp, Surface200, RoundedCornerShape(0.dp))
                .clickable(onClick = onToggle)
                .padding(vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = "Specifications",
                fontSize = 14.sp,
                lineHeight = 18.sp,
                fontWeight = FontWeight.Bold,
                color = Ink900,
                modifier = Modifier.weight(1f),
            )
            Icon(
                imageVector = Icons.Filled.ExpandMore,
                contentDescription = if (open) "Collapse" else "Expand",
                tint = Ink700,
                modifier = Modifier
                    .size(20.dp)
                    .rotate(rotation),
            )
        }
        if (open) {
            val rows = buildList {
                if (part.partNumber.isNotBlank()) add("Part number" to part.partNumber)
                if (part.sku.isNotBlank()) add("SKU" to part.sku)
                add("Category" to part.category.displayName)
                add("Genuine" to if (part.isGenuine) "Yes" else "No")
                add("OEM" to if (part.isOem) "Yes" else "No")
                if (part.warrantyMonths > 0) add("Warranty" to "${part.warrantyMonths} months")
                add("Min order" to "${part.minimumOrderQuantity} ${part.unit}")
                add("GST" to "${part.gstRatePercent.toInt()}%")
            }
            Column(
                modifier = Modifier.padding(top = 8.dp, bottom = 8.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                rows.forEach { (k, v) ->
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                    ) {
                        Text(text = k, fontSize = 13.sp, lineHeight = 16.sp, color = Ink500)
                        Text(
                            text = v,
                            fontSize = 13.sp,
                            lineHeight = 16.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = Ink700,
                        )
                    }
                }
            }
            if (part.description.isNotBlank()) {
                Text(
                    text = part.description,
                    fontSize = 13.sp,
                    lineHeight = 18.sp,
                    color = Ink700,
                    modifier = Modifier.padding(top = Spacing.sm, bottom = 8.dp),
                )
            }
        }
    }
}

/* ------------------------------------------------------------------ */
/* Related rail (placeholder tiles)                                   */
/* ------------------------------------------------------------------ */

@Composable
private fun RelatedPartsRail(part: SparePart) {
    // We don't have a related-parts API yet; render three hue-shifted tiles using
    // the current part's data so the rail looks alive.
    val seeds = listOf(200, 280, 330)
    LazyRow(
        contentPadding = PaddingValues(start = Spacing.lg, end = Spacing.lg, bottom = Spacing.lg),
        horizontalArrangement = Arrangement.spacedBy(Spacing.md),
    ) {
        items(items = seeds, key = { it }) { hue ->
            Column(modifier = Modifier.width(130.dp)) {
                GradientTile(
                    icon = categoryIcon(part.category),
                    hue = hue,
                    size = 130.dp,
                )
                Text(
                    text = part.name,
                    fontSize = 12.sp,
                    lineHeight = 15.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = Ink900,
                    maxLines = 2,
                    modifier = Modifier.padding(top = 6.dp),
                )
                Text(
                    text = formatRupees(part.priceRupees),
                    fontSize = 13.sp,
                    lineHeight = 16.sp,
                    fontWeight = FontWeight.Bold,
                    color = BrandGreenDark,
                )
            }
        }
    }
}

/* ------------------------------------------------------------------ */
/* Sticky bottom CTA                                                  */
/* ------------------------------------------------------------------ */

@Composable
private fun BottomCtaBar(
    part: SparePart,
    addingToCart: Boolean,
    onAddToCart: () -> Unit,
    onBuyNow: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(Surface0)
            .border(1.dp, Surface200, RoundedCornerShape(0.dp)),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            horizontalArrangement = Arrangement.spacedBy(10.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            OutlinedButton(
                onClick = onAddToCart,
                enabled = part.inStock && !addingToCart,
                modifier = Modifier
                    .weight(1f)
                    .height(56.dp),
                shape = RoundedCornerShape(50),
                border = BorderStroke(1.5.dp, Surface200),
            ) {
                Icon(
                    imageVector = Icons.Filled.ShoppingCart,
                    contentDescription = null,
                    modifier = Modifier.size(18.dp),
                )
                Spacer(Modifier.width(8.dp))
                Text(
                    text = if (addingToCart) "Adding…" else "Add to cart",
                    fontWeight = FontWeight.SemiBold,
                    fontSize = 15.sp,
                )
            }
            Button(
                onClick = onBuyNow,
                enabled = part.inStock && !addingToCart,
                modifier = Modifier
                    .weight(1f)
                    .height(56.dp),
                shape = RoundedCornerShape(50),
                colors = ButtonDefaults.buttonColors(containerColor = BrandGreen),
            ) {
                Text(
                    text = if (!part.inStock) "Notify me" else "Buy now",
                    fontWeight = FontWeight.SemiBold,
                    fontSize = 16.sp,
                )
            }
        }
    }
}

/* ------------------------------------------------------------------ */
/* Fallback states                                                    */
/* ------------------------------------------------------------------ */

@Composable
private fun NotFoundState(onBack: () -> Unit) {
    Column(
        modifier = Modifier.fillMaxSize().padding(Spacing.xl),
        verticalArrangement = Arrangement.spacedBy(Spacing.md, Alignment.CenterVertically),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            text = "This part isn't available anymore.",
            style = MaterialTheme.typography.titleMedium,
        )
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
