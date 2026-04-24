package com.equipseva.app.features.supplier

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.CheckCircle
import androidx.compose.material.icons.outlined.Warning
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.core.data.parts.SparePart
import com.equipseva.app.core.util.formatRupees
import com.equipseva.app.designsystem.components.ESBackTopBar
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.ErrorBanner
import com.equipseva.app.designsystem.components.GradientTile
import com.equipseva.app.designsystem.components.SectionHeader
import com.equipseva.app.designsystem.components.StatusChip
import com.equipseva.app.designsystem.components.StatusTone
import com.equipseva.app.designsystem.theme.BrandGreenDark
import com.equipseva.app.designsystem.theme.Ink500
import com.equipseva.app.designsystem.theme.Ink900
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.designsystem.theme.Surface0
import com.equipseva.app.designsystem.theme.Surface200
import com.equipseva.app.designsystem.theme.Surface50
import com.equipseva.app.features.marketplace.components.categoryArt
import com.equipseva.app.features.marketplace.components.categoryHue

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun StockAlertsScreen(
    onBack: () -> Unit,
    onPartClick: (String) -> Unit,
    viewModel: StockAlertsViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    Scaffold(
        topBar = { ESBackTopBar(title = "Stock alerts", onBack = onBack) },
        containerColor = Surface50,
    ) { inner ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(inner)
                .background(Surface50),
        ) {
            ErrorBanner(
                message = state.errorMessage,
                modifier = Modifier.padding(horizontal = Spacing.lg),
            )
            PullToRefreshBox(
                isRefreshing = state.refreshing,
                onRefresh = viewModel::onRefresh,
                modifier = Modifier.fillMaxSize(),
            ) {
                when {
                    state.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator()
                    }
                    state.noOrgWarning -> EmptyStateView(
                        icon = Icons.Outlined.Warning,
                        title = "Organization not linked",
                        subtitle = "Ask your admin to link your account.",
                    )
                    state.outOfStock.isEmpty() && state.lowStock.isEmpty() -> EmptyStateView(
                        icon = Icons.Outlined.CheckCircle,
                        title = "All stock healthy",
                        subtitle = "No parts are out of stock or below threshold.",
                    )
                    else -> LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(
                            bottom = Spacing.lg,
                        ),
                        verticalArrangement = Arrangement.spacedBy(Spacing.sm),
                    ) {
                        if (state.outOfStock.isNotEmpty()) {
                            item("out_header") { SectionHeader(title = "Out of stock") }
                            items(items = state.outOfStock, key = { "o-${it.id}" }) { part ->
                                AlertRow(
                                    part = part,
                                    tone = StatusTone.Danger,
                                    onClick = { onPartClick(part.id) },
                                )
                            }
                        }
                        if (state.lowStock.isNotEmpty()) {
                            item("low_header") { SectionHeader(title = "Low stock") }
                            items(items = state.lowStock, key = { "l-${it.id}" }) { part ->
                                AlertRow(
                                    part = part,
                                    tone = StatusTone.Warn,
                                    onClick = { onPartClick(part.id) },
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
private fun AlertRow(
    part: SparePart,
    tone: StatusTone,
    onClick: () -> Unit,
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = Spacing.lg)
            .clickable { onClick() },
        shape = RoundedCornerShape(8.dp),
        colors = CardDefaults.cardColors(containerColor = Surface0),
        border = BorderStroke(1.dp, Surface200),
        elevation = CardDefaults.cardElevation(defaultElevation = 0.dp),
    ) {
        Row(
            modifier = Modifier.padding(Spacing.md),
            horizontalArrangement = Arrangement.spacedBy(Spacing.md),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            GradientTile(
                art = categoryArt(part.category),
                hue = categoryHue(part.category),
                size = 48.dp,
            )
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(2.dp),
            ) {
                Text(
                    text = part.name,
                    fontSize = 14.sp,
                    lineHeight = 18.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = Ink900,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
                Text(
                    text = "#${part.partNumber}",
                    fontSize = 11.sp,
                    lineHeight = 14.sp,
                    color = Ink500,
                )
            }
            Column(
                horizontalAlignment = Alignment.End,
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                Text(
                    text = formatRupees(part.priceRupees),
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = BrandGreenDark,
                )
                StatusChip(
                    label = if (part.stockQuantity <= 0) "Out" else "${part.stockQuantity} left",
                    tone = tone,
                )
            }
        }
    }
}
