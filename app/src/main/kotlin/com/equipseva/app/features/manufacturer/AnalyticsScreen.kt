package com.equipseva.app.features.manufacturer

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.outlined.BarChart
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.core.util.formatRupees
import com.equipseva.app.designsystem.components.ESBackTopBar
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.ErrorBanner
import com.equipseva.app.designsystem.components.SectionHeader
import com.equipseva.app.designsystem.theme.Spacing

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AnalyticsScreen(
    onBack: () -> Unit,
    viewModel: AnalyticsViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    Scaffold(
        topBar = { ESBackTopBar(title = "Analytics", onBack = onBack) },
    ) { inner ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(inner),
        ) {
            ErrorBanner(
                message = state.errorMessage,
                modifier = Modifier.padding(horizontal = Spacing.lg),
            )
            when {
                state.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }
                state.noManufacturerWarning -> EmptyStateView(
                    icon = Icons.Outlined.BarChart,
                    title = "Manufacturer not linked",
                    subtitle = "Register as a manufacturer to see your bidding analytics.",
                )
                else -> Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .verticalScroll(rememberScrollState())
                        .padding(vertical = Spacing.md),
                    verticalArrangement = Arrangement.spacedBy(Spacing.sm),
                ) {
                    SectionHeader(title = "Bidding activity")
                    Row(
                        modifier = Modifier.padding(horizontal = Spacing.lg).fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
                    ) {
                        MetricTile(
                            modifier = Modifier.weight(1f),
                            label = "Submitted",
                            value = state.bidsSubmitted.toString(),
                            accent = MaterialTheme.colorScheme.primary,
                        )
                        MetricTile(
                            modifier = Modifier.weight(1f),
                            label = "Awarded",
                            value = state.bidsAwarded.toString(),
                            accent = MaterialTheme.colorScheme.tertiary,
                        )
                        MetricTile(
                            modifier = Modifier.weight(1f),
                            label = "Open",
                            value = state.bidsOpen.toString(),
                            accent = MaterialTheme.colorScheme.secondary,
                        )
                    }
                    SectionHeader(title = "Performance")
                    Row(
                        modifier = Modifier.padding(horizontal = Spacing.lg).fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
                    ) {
                        MetricTile(
                            modifier = Modifier.weight(1f),
                            label = "Win rate",
                            value = "${state.winRatePercent}%",
                            accent = MaterialTheme.colorScheme.primary,
                        )
                        MetricTile(
                            modifier = Modifier.weight(1f),
                            label = "Awarded value",
                            value = formatRupees(state.awardedValueRupees),
                            accent = MaterialTheme.colorScheme.primary,
                        )
                    }
                    Row(
                        modifier = Modifier.padding(horizontal = Spacing.lg).fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
                    ) {
                        MetricTile(
                            modifier = Modifier.weight(1f),
                            label = "Pipeline value",
                            value = formatRupees(state.pipelineValueRupees),
                            accent = MaterialTheme.colorScheme.tertiary,
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun MetricTile(
    modifier: Modifier = Modifier,
    label: String,
    value: String,
    accent: Color,
) {
    Card(
        modifier = modifier,
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp),
    ) {
        Column(modifier = Modifier.padding(Spacing.md)) {
            Text(
                text = label,
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Text(
                text = value,
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
                color = accent,
            )
        }
    }
}
