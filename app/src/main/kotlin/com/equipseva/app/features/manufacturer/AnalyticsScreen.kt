package com.equipseva.app.features.manufacturer

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.BarChart
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.core.util.formatRupees
import com.equipseva.app.designsystem.components.ESBackTopBar
import com.equipseva.app.designsystem.components.ErrorBanner
import com.equipseva.app.designsystem.components.PremiumGradientSurfaceDark
import com.equipseva.app.designsystem.components.SectionHeader
import com.equipseva.app.designsystem.components.StatusBanner
import com.equipseva.app.designsystem.components.StatusBannerTone
import com.equipseva.app.designsystem.theme.BrandGreenDark
import com.equipseva.app.designsystem.theme.Ink500
import com.equipseva.app.designsystem.theme.Ink900
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.designsystem.theme.Surface0
import com.equipseva.app.designsystem.theme.Surface200
import com.equipseva.app.designsystem.theme.Surface50

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AnalyticsScreen(
    onBack: () -> Unit,
    viewModel: AnalyticsViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    Scaffold(
        topBar = { ESBackTopBar(title = "Analytics", onBack = onBack) },
        containerColor = Surface50,
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
                state.noManufacturerWarning -> Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(Spacing.lg),
                ) {
                    StatusBanner(
                        title = "Manufacturer not linked",
                        message = "Register your organization as a manufacturer to see your bidding analytics.",
                        tone = StatusBannerTone.Warn,
                        leadingIcon = Icons.Outlined.BarChart,
                    )
                }
                else -> Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .verticalScroll(rememberScrollState())
                        .padding(bottom = Spacing.xl),
                ) {
                    // Hero summary — gradient brand surface w/ headline win rate.
                    AnalyticsHero(
                        winRatePercent = state.winRatePercent,
                        bidsAwarded = state.bidsAwarded,
                        bidsSubmitted = state.bidsSubmitted,
                        modifier = Modifier
                            .padding(start = Spacing.lg, end = Spacing.lg, top = Spacing.lg),
                    )

                    SectionHeader(title = "Bidding activity")
                    MetricGrid2(
                        modifier = Modifier.padding(horizontal = Spacing.lg),
                        tiles = listOf(
                            MetricSpec(label = "Submitted bids", value = state.bidsSubmitted.toString()),
                            MetricSpec(label = "Awarded bids", value = state.bidsAwarded.toString()),
                            MetricSpec(label = "Open bids", value = state.bidsOpen.toString()),
                            MetricSpec(label = "Win rate", value = "${state.winRatePercent}%"),
                        ),
                    )

                    SectionHeader(title = "Revenue")
                    MetricGrid2(
                        modifier = Modifier.padding(horizontal = Spacing.lg),
                        tiles = listOf(
                            MetricSpec(label = "Awarded value", value = "₹${formatRupees(state.awardedValueRupees)}"),
                            MetricSpec(label = "Pipeline value", value = "₹${formatRupees(state.pipelineValueRupees)}"),
                        ),
                    )
                }
            }
        }
    }
}

// ---- Hero ----

@Composable
private fun AnalyticsHero(
    winRatePercent: Int,
    bidsAwarded: Int,
    bidsSubmitted: Int,
    modifier: Modifier = Modifier,
) {
    PremiumGradientSurfaceDark(
        modifier = modifier
            .fillMaxWidth()
            .clip(MaterialTheme.shapes.large),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(Spacing.lg),
        ) {
            Text(
                text = "Win rate",
                style = MaterialTheme.typography.labelMedium,
                color = Color.White.copy(alpha = 0.70f),
            )
            Spacer(Modifier.height(Spacing.xs))
            Text(
                text = "$winRatePercent%",
                fontSize = 40.sp,
                lineHeight = 44.sp,
                fontWeight = FontWeight.SemiBold,
                color = Color.White,
            )
            Spacer(Modifier.height(Spacing.md))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(Spacing.lg),
            ) {
                HeroStat(label = "Awarded", value = bidsAwarded.toString(), modifier = Modifier.weight(1f))
                Box(
                    modifier = Modifier
                        .height(28.dp)
                        .background(Color.White.copy(alpha = 0.20f))
                        .padding(horizontal = 0.5.dp),
                )
                HeroStat(label = "Submitted", value = bidsSubmitted.toString(), modifier = Modifier.weight(1f))
            }
        }
    }
}

@Composable
private fun HeroStat(label: String, value: String, modifier: Modifier = Modifier) {
    Column(modifier = modifier) {
        Text(
            text = label,
            style = MaterialTheme.typography.labelMedium,
            color = Color.White.copy(alpha = 0.70f),
        )
        Text(
            text = value,
            fontSize = 18.sp,
            fontWeight = FontWeight.SemiBold,
            color = Color.White,
        )
    }
}

// ---- Metric grid ----

private data class MetricSpec(val label: String, val value: String)

@Composable
private fun MetricGrid2(
    modifier: Modifier = Modifier,
    tiles: List<MetricSpec>,
) {
    Column(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(Spacing.sm),
    ) {
        tiles.chunked(2).forEach { rowTiles ->
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
            ) {
                rowTiles.forEach { spec ->
                    MetricTile(
                        spec = spec,
                        modifier = Modifier.weight(1f),
                    )
                }
                // Filler if last row has only one tile, keeping equal sizing.
                if (rowTiles.size == 1) {
                    Spacer(Modifier.weight(1f))
                }
            }
        }
    }
}

@Composable
private fun MetricTile(
    spec: MetricSpec,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .clip(MaterialTheme.shapes.large)
            .background(Surface0)
            .border(1.dp, Surface200, MaterialTheme.shapes.large)
            .padding(Spacing.md),
        verticalArrangement = Arrangement.spacedBy(Spacing.xs),
    ) {
        Text(
            text = spec.label.uppercase(),
            fontSize = 11.sp,
            letterSpacing = 0.4.sp,
            fontWeight = FontWeight.SemiBold,
            color = Ink500,
        )
        Text(
            text = spec.value,
            fontSize = 22.sp,
            lineHeight = 26.sp,
            fontWeight = FontWeight.SemiBold,
            color = if (spec.label.contains("value", ignoreCase = true)) BrandGreenDark else Ink900,
        )
    }
}
