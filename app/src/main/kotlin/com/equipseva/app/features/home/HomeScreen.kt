package com.equipseva.app.features.home

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Analytics
import androidx.compose.material.icons.filled.Assignment
import androidx.compose.material.icons.filled.Build
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.DocumentScanner
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.Inventory
import androidx.compose.material.icons.filled.Inventory2
import androidx.compose.material.icons.filled.LocalShipping
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.Paid
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.ShoppingCart
import androidx.compose.material.icons.filled.Store
import androidx.compose.material.icons.filled.TrendingUp
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material.icons.filled.Work
import androidx.compose.material.icons.outlined.Badge
import androidx.compose.material.icons.outlined.RequestQuote
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.designsystem.components.ESTopBar
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.GradientTile
import com.equipseva.app.designsystem.components.HeroBanner
import com.equipseva.app.designsystem.components.SectionHeader
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.features.auth.UserRole

@Composable
fun HomeScreen(
    onShowMessage: (String) -> Unit,
    onCardClick: (String) -> Unit = {},
    viewModel: HomeViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    LaunchedEffect(viewModel) {
        viewModel.effects.collect { effect ->
            when (effect) {
                is HomeViewModel.Effect.ShowMessage -> onShowMessage(effect.text)
            }
        }
    }

    Scaffold(topBar = { ESTopBar(title = "Home") }) { inner ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(inner),
        ) {
            when {
                state.loading -> {
                    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator()
                    }
                }
                state.errorMessage != null -> {
                    HomeErrorView(
                        message = state.errorMessage!!,
                        onRetry = viewModel::onRetry,
                    )
                }
                else -> {
                    HomeContent(
                        greetingName = state.greetingName,
                        role = state.role,
                        onCardClick = onCardClick,
                    )
                }
            }
        }
    }
}

@Composable
private fun HomeContent(
    greetingName: String,
    role: UserRole?,
    onCardClick: (String) -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(Spacing.lg),
        verticalArrangement = Arrangement.spacedBy(Spacing.md),
    ) {
        HeroBanner(
            headline = "Hello, $greetingName",
            eyebrow = "Welcome back",
            subline = role?.displayName ?: "Pick a role in Profile to personalise this dashboard.",
        )

        Spacer(Modifier.size(Spacing.sm))

        val cards = cardsFor(role)
        if (cards.isEmpty()) {
            EmptyStateView(
                icon = Icons.Outlined.Badge,
                title = "No role selected",
                subtitle = "Choose a role in Profile to see personalised actions.",
            )
        } else {
            SectionHeader(title = "Quick actions")
            cards.forEach { entry ->
                HomeActionCard(
                    icon = entry.icon,
                    title = entry.title,
                    subtitle = entry.subtitle,
                    hue = entry.hue,
                    onClick = { onCardClick(entry.key) },
                )
            }
        }
    }
}

private data class HomeCardEntry(
    val key: String,
    val icon: ImageVector,
    val title: String,
    val subtitle: String,
    val hue: Int,
)

private fun cardsFor(role: UserRole?): List<HomeCardEntry> = when (role) {
    UserRole.HOSPITAL -> listOf(
        HomeCardEntry("scan_equipment", Icons.Filled.DocumentScanner, "Scan equipment", "Identify equipment with AI and find matching parts", hue = 260),
        HomeCardEntry("browse_parts", Icons.Filled.Search, "Browse parts", "Find compatible parts for your equipment", hue = 200),
        HomeCardEntry("active_jobs", Icons.Filled.Build, "Active repair jobs", "Track ongoing repairs", hue = 150),
        HomeCardEntry("order_history", Icons.Filled.History, "Order history", "Review past purchases and invoices", hue = 40),
        HomeCardEntry("request_service", Icons.Filled.Assignment, "Request a service", "Post a new repair request", hue = 280),
        HomeCardEntry("hospital_create_rfq", Icons.Filled.Description, "Create an RFQ", "Request quotations from suppliers", hue = 330),
        HomeCardEntry("my_rfqs", Icons.Outlined.RequestQuote, "My RFQs", "Track your open and past quotation requests", hue = 200),
    )
    UserRole.ENGINEER -> listOf(
        HomeCardEntry("scan_equipment", Icons.Filled.DocumentScanner, "Scan equipment", "Identify equipment on-site and look up parts", hue = 260),
        HomeCardEntry("jobs_nearby", Icons.Filled.LocationOn, "Open jobs near me", "Jobs posted in your area", hue = 150),
        HomeCardEntry("my_bids", Icons.Filled.Description, "My bids", "Track bids you've placed", hue = 40),
        HomeCardEntry("active_work", Icons.Filled.Work, "Active work", "Jobs you're currently on", hue = 200),
        HomeCardEntry("earnings", Icons.Filled.Paid, "Earnings summary", "Payouts and pending amounts", hue = 280),
        HomeCardEntry("engineer_profile", Icons.Outlined.Badge, "My engineer profile", "Rates, service areas, specializations", hue = 330),
    )
    UserRole.SUPPLIER -> listOf(
        HomeCardEntry("incoming_orders", Icons.Filled.ShoppingCart, "Incoming orders", "New and pending orders", hue = 150),
        HomeCardEntry("my_listings", Icons.Filled.Store, "My listings", "Manage parts you sell", hue = 200),
        HomeCardEntry("supplier_add_listing", Icons.Filled.Inventory2, "Add a listing", "Publish a new spare part", hue = 40),
        HomeCardEntry("stock_alerts", Icons.Filled.Warning, "Stock alerts", "Low or out-of-stock items", hue = 0),
        HomeCardEntry("rfqs", Icons.Filled.Description, "RFQs", "Requests for quotation", hue = 280),
    )
    UserRole.MANUFACTURER -> listOf(
        HomeCardEntry("rfqs_assigned", Icons.Filled.Assignment, "RFQs assigned", "Quotation requests for you", hue = 280),
        HomeCardEntry("lead_pipeline", Icons.Filled.TrendingUp, "Lead pipeline", "Leads in progress", hue = 200),
        HomeCardEntry("analytics", Icons.Filled.Analytics, "Analytics", "Performance and trends", hue = 150),
    )
    UserRole.LOGISTICS -> listOf(
        HomeCardEntry("pickup_queue", Icons.Filled.Inventory2, "Pickup queue", "Shipments awaiting pickup", hue = 40),
        HomeCardEntry("active_deliveries", Icons.Filled.LocalShipping, "Active deliveries", "Currently on the road", hue = 200),
        HomeCardEntry("completed_today", Icons.Filled.Inventory, "Completed today", "Deliveries closed today", hue = 150),
    )
    null -> emptyList()
}

@Composable
private fun HomeActionCard(
    icon: ImageVector,
    title: String,
    subtitle: String,
    hue: Int,
    onClick: () -> Unit,
) {
    Card(
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(Spacing.lg),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(Spacing.md),
        ) {
            GradientTile(icon = icon, hue = hue, size = 48.dp)
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(Spacing.xxs),
            ) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                )
                Text(
                    text = subtitle,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            Icon(
                imageVector = Icons.Filled.ChevronRight,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Composable
private fun HomeErrorView(
    message: String,
    onRetry: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(Spacing.lg),
        verticalArrangement = Arrangement.spacedBy(Spacing.md, Alignment.CenterVertically),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Icon(
            imageVector = Icons.Filled.Warning,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.error,
            modifier = Modifier.size(48.dp),
        )
        Text(message, style = MaterialTheme.typography.bodyLarge)
        Button(onClick = onRetry) {
            Icon(Icons.Filled.Refresh, contentDescription = null)
            Spacer(Modifier.size(Spacing.sm))
            Text("Retry")
        }
    }
}
