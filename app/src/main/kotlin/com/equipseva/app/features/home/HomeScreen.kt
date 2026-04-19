package com.equipseva.app.features.home

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Analytics
import androidx.compose.material.icons.filled.Assignment
import androidx.compose.material.icons.filled.Build
import androidx.compose.material.icons.filled.ChevronRight
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
)

private fun cardsFor(role: UserRole?): List<HomeCardEntry> = when (role) {
    UserRole.HOSPITAL -> listOf(
        HomeCardEntry("browse_parts", Icons.Filled.Search, "Browse parts", "Find compatible parts for your equipment"),
        HomeCardEntry("active_jobs", Icons.Filled.Build, "Active repair jobs", "Track ongoing repairs"),
        HomeCardEntry("order_history", Icons.Filled.History, "Order history", "Review past purchases and invoices"),
        HomeCardEntry("request_service", Icons.Filled.Assignment, "Request a service", "Post a new repair request"),
    )
    UserRole.ENGINEER -> listOf(
        HomeCardEntry("jobs_nearby", Icons.Filled.LocationOn, "Open jobs near me", "Jobs posted in your area"),
        HomeCardEntry("my_bids", Icons.Filled.Description, "My bids", "Track bids you've placed"),
        HomeCardEntry("active_work", Icons.Filled.Work, "Active work", "Jobs you're currently on"),
        HomeCardEntry("earnings", Icons.Filled.Paid, "Earnings summary", "Payouts and pending amounts"),
    )
    UserRole.SUPPLIER -> listOf(
        HomeCardEntry("incoming_orders", Icons.Filled.ShoppingCart, "Incoming orders", "New and pending orders"),
        HomeCardEntry("my_listings", Icons.Filled.Store, "My listings", "Manage parts you sell"),
        HomeCardEntry("stock_alerts", Icons.Filled.Warning, "Stock alerts", "Low or out-of-stock items"),
        HomeCardEntry("rfqs", Icons.Filled.Description, "RFQs", "Requests for quotation"),
    )
    UserRole.MANUFACTURER -> listOf(
        HomeCardEntry("rfqs_assigned", Icons.Filled.Assignment, "RFQs assigned", "Quotation requests for you"),
        HomeCardEntry("lead_pipeline", Icons.Filled.TrendingUp, "Lead pipeline", "Leads in progress"),
        HomeCardEntry("analytics", Icons.Filled.Analytics, "Analytics", "Performance and trends"),
    )
    UserRole.LOGISTICS -> listOf(
        HomeCardEntry("pickup_queue", Icons.Filled.Inventory2, "Pickup queue", "Shipments awaiting pickup"),
        HomeCardEntry("active_deliveries", Icons.Filled.LocalShipping, "Active deliveries", "Currently on the road"),
        HomeCardEntry("completed_today", Icons.Filled.Inventory, "Completed today", "Deliveries closed today"),
    )
    null -> emptyList()
}

@Composable
private fun HomeActionCard(
    icon: ImageVector,
    title: String,
    subtitle: String,
    onClick: () -> Unit,
) {
    Card(
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
        modifier = Modifier
            .fillMaxWidth()
            .height(IntrinsicSize.Min)
            .clickable(onClick = onClick),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(IntrinsicSize.Min),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                modifier = Modifier
                    .width(4.dp)
                    .fillMaxHeight()
                    .background(MaterialTheme.colorScheme.primary),
            )
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(Spacing.lg),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(Spacing.md),
            ) {
                Icon(
                    imageVector = icon,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(32.dp),
                )
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
