package com.equipseva.app.features.founder

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk900

/** A founder key-value metric dashboard: friendly title + the backing RPC. */
data class FounderDashboardEntry(val title: String, val rpc: String, val subtitle: String)

/**
 * Curated founder key-value dashboards — each backed by a founder_* RPC that
 * returns (metric, value_text, ...). RPC names are code-listed here (never user
 * input), so passing them to FounderMetricRepository.fetch is safe.
 */
internal val FOUNDER_METRIC_DASHBOARDS: List<FounderDashboardEntry> = listOf(
    FounderDashboardEntry("Platform pulse", "founder_platform_pulse", "Top-line platform metrics"),
    FounderDashboardEntry("AMC renewals", "founder_amc_renewal_attempts_summary", "Renewal attempts + outcomes"),
    FounderDashboardEntry("AMC SLA breaches", "founder_amc_sla_breaches_summary", "SLA breach counts + credits"),
    FounderDashboardEntry("AMC subscriptions", "founder_amc_subscription_charges_summary", "Auto-charge activity"),
    FounderDashboardEntry("Catalog coverage", "founder_catalog_coverage_summary", "Reference-catalog completeness"),
)

/**
 * Founder business cockpit (r1420): a hub of read-only key-value metric
 * dashboards for the founder on mobile, each opening a generic
 * [FounderMetricListScreen] backed by a founder_* summary RPC. Reachable from
 * the Profile founder section (founder-gated).
 */
@Composable
fun FounderCockpitScreen(
    onBack: () -> Unit,
    onOpenDashboard: (title: String, rpc: String) -> Unit,
    onOpenRefundApprovals: () -> Unit = {},
) {
    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(title = "Business cockpit", onBack = onBack)
            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(12.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                item(key = "actions-header") {
                    Text(
                        "Actions",
                        style = EsType.H5,
                        color = SevaInk900,
                        modifier = Modifier.padding(horizontal = 4.dp, vertical = 4.dp),
                    )
                }
                item(key = "refund-approvals") {
                    CockpitRow(
                        title = "Refund approvals",
                        subtitle = "Approve or reject pending refund requests",
                        onClick = onOpenRefundApprovals,
                    )
                }
                item(key = "dashboards-header") {
                    Text(
                        "Dashboards",
                        style = EsType.H5,
                        color = SevaInk900,
                        modifier = Modifier.padding(horizontal = 4.dp, vertical = 4.dp),
                    )
                }
                items(FOUNDER_METRIC_DASHBOARDS, key = { it.rpc }) { entry ->
                    CockpitRow(
                        title = entry.title,
                        subtitle = entry.subtitle,
                        onClick = { onOpenDashboard(entry.title, entry.rpc) },
                    )
                }
            }
        }
    }
}

@Composable
private fun CockpitRow(title: String, subtitle: String, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
            .clickable(onClick = onClick)
            .padding(14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(title, style = EsType.Body.copy(fontWeight = FontWeight.Medium), color = SevaInk900)
            Text(subtitle, style = EsType.Caption, color = SevaInk500)
        }
        Text("›", style = EsType.H5, color = SevaInk500)
    }
}
