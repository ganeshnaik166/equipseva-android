package com.equipseva.app.features.founder

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.TrendingUp
import androidx.compose.material.icons.filled.AdminPanelSettings
import androidx.compose.material.icons.filled.Block
import androidx.compose.material.icons.filled.Flag
import androidx.compose.material.icons.filled.Group
import androidx.compose.material.icons.filled.Map
import androidx.compose.material.icons.filled.Payments
import androidx.compose.material.icons.filled.Security
import androidx.compose.material.icons.filled.Storefront
import androidx.compose.material.icons.filled.VerifiedUser
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.designsystem.components.ESTopBar
import com.equipseva.app.designsystem.theme.BrandGreen
import com.equipseva.app.designsystem.theme.BrandGreenDark
import com.equipseva.app.designsystem.theme.Ink500
import com.equipseva.app.designsystem.theme.Ink900
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.designsystem.theme.Surface0
import com.equipseva.app.designsystem.theme.Surface200
import com.equipseva.app.designsystem.theme.Surface50
import com.equipseva.app.features.home.dashboards.DashboardSectionHeader
import com.equipseva.app.features.home.dashboards.ListCard
import com.equipseva.app.features.home.dashboards.StatRow
import com.equipseva.app.features.home.dashboards.StatTile
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

@HiltViewModel
class FounderDashboardViewModel @Inject constructor(
    private val repo: FounderRepository,
) : ViewModel() {
    data class UiState(
        val loading: Boolean = true,
        val stats: FounderRepository.DashboardStats? = null,
        val error: String? = null,
    )
    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init { reload() }

    fun reload() {
        _state.update { it.copy(loading = true, error = null) }
        viewModelScope.launch {
            repo.fetchDashboardStats()
                .onSuccess { s -> _state.update { it.copy(loading = false, stats = s) } }
                .onFailure { e -> _state.update { it.copy(loading = false, error = e.message ?: "Failed") } }
        }
    }
}

/**
 * Founder dashboard. Email-pinned to ganesh1431.dhanavath@gmail.com via
 * `Profile.isFounder()`. Stats hydrate from `admin_dashboard_stats()` —
 * server-side `is_founder()` gate is the ultimate enforcement.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FounderDashboardScreen(
    onOpenKycQueue: () -> Unit,
    onOpenReportsQueue: () -> Unit,
    onOpenUsers: () -> Unit,
    onOpenPayments: () -> Unit,
    onOpenIntegrityFlags: () -> Unit,
    onOpenCategories: () -> Unit = {},
    onOpenBuyerKyc: () -> Unit = {},
    onOpenEngineerZones: () -> Unit = {},
    viewModel: FounderDashboardViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsState()
    val stats = state.stats
    Scaffold(topBar = { ESTopBar(title = "Founder") }) { inner ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(inner)
                .background(Surface50)
                .verticalScroll(rememberScrollState()),
        ) {
            FounderHero()

            StatRow(
                tiles = listOf(
                    StatTile(
                        icon = Icons.Filled.VerifiedUser,
                        value = stats?.pendingKyc?.toString() ?: "—",
                        label = "Pending KYC",
                        hue = 40,
                        onClick = onOpenKycQueue,
                    ),
                    StatTile(
                        icon = Icons.Filled.Flag,
                        value = stats?.pendingReports?.toString() ?: "—",
                        label = "Open reports",
                        hue = 0,
                        onClick = onOpenReportsQueue,
                    ),
                    StatTile(
                        icon = Icons.AutoMirrored.Filled.TrendingUp,
                        value = stats?.ordersToday?.toString() ?: "—",
                        label = "Orders today",
                        hue = 150,
                        onClick = onOpenPayments,
                    ),
                ),
            )

            StatRow(
                tiles = listOf(
                    StatTile(
                        icon = Icons.Filled.Storefront,
                        value = stats?.pendingSellers?.toString() ?: "—",
                        label = "Pending sellers",
                        hue = 280,
                        onClick = onOpenKycQueue,
                    ),
                    StatTile(
                        icon = Icons.Filled.Security,
                        value = stats?.integrityFailuresToday?.toString() ?: "—",
                        label = "Integrity flags today",
                        hue = 330,
                        onClick = onOpenIntegrityFlags,
                    ),
                ),
            )

            DashboardSectionHeader(title = "Moderation queues")
            ListCard(
                leadingIcon = Icons.Filled.VerifiedUser,
                leadingHue = 40,
                title = "KYC queue",
                subtitle = "Approve or reject engineer + supplier verifications.",
                onClick = onOpenKycQueue,
            )
            ListCard(
                leadingIcon = Icons.Filled.Flag,
                leadingHue = 0,
                title = "Content reports",
                subtitle = "User-flagged listings, RFQs, jobs, and chat content.",
                onClick = onOpenReportsQueue,
            )
            ListCard(
                leadingIcon = Icons.Filled.Block,
                leadingHue = 0,
                title = "Blocked users",
                subtitle = "Suspended accounts and chat-blocks across the platform.",
                onClick = onOpenUsers,
            )

            DashboardSectionHeader(title = "Operations")
            ListCard(
                leadingIcon = Icons.Filled.Group,
                leadingHue = 200,
                title = "All users",
                subtitle = "Search profiles, see roles, force role changes.",
                onClick = onOpenUsers,
            )
            ListCard(
                leadingIcon = Icons.Filled.Payments,
                leadingHue = 280,
                title = "Payments",
                subtitle = "Razorpay transactions, refunds, payout queue.",
                onClick = onOpenPayments,
            )
            ListCard(
                leadingIcon = Icons.Filled.Security,
                leadingHue = 330,
                title = "Integrity flags",
                subtitle = "Play-Integrity failures, signature mismatches, root/emulator hits.",
                onClick = onOpenIntegrityFlags,
            )
            ListCard(
                leadingIcon = Icons.Filled.AdminPanelSettings,
                leadingHue = 200,
                title = "Equipment categories",
                subtitle = "Curate the canonical category list (display name, scope, sort order, active).",
                onClick = onOpenCategories,
            )
            ListCard(
                leadingIcon = Icons.Filled.VerifiedUser,
                leadingHue = 60,
                title = "Buyer KYC queue",
                subtitle = "Approve or reject buyer trade-doc submissions before checkout.",
                onClick = onOpenBuyerKyc,
            )
            ListCard(
                leadingIcon = Icons.Filled.Map,
                leadingHue = 150,
                title = "Engineer zones",
                subtitle = "How many verified engineers are available per district — flag low-supply zones.",
                onClick = onOpenEngineerZones,
            )
            Box(modifier = Modifier.size(Spacing.xl))
        }
    }
}

@Composable
private fun FounderHero() {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = Spacing.lg, vertical = Spacing.sm)
            .clip(RoundedCornerShape(20.dp))
            .background(
                Brush.linearGradient(listOf(BrandGreen, BrandGreenDark)),
            )
            .padding(20.dp),
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Box(
                modifier = Modifier
                    .size(56.dp)
                    .clip(RoundedCornerShape(16.dp))
                    .background(Color.White.copy(alpha = 0.18f)),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector = Icons.Filled.AdminPanelSettings,
                    contentDescription = null,
                    tint = Color.White,
                )
            }
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = "Welcome, founder",
                    fontSize = 13.sp,
                    color = Color.White.copy(alpha = 0.9f),
                )
                Text(
                    text = "Run the platform.",
                    fontSize = 22.sp,
                    fontWeight = FontWeight.Bold,
                    color = Color.White,
                )
                Text(
                    text = "KYC reviews, reports, users, payments, integrity.",
                    fontSize = 12.sp,
                    color = Color.White.copy(alpha = 0.85f),
                    modifier = Modifier.padding(top = 4.dp),
                )
            }
        }
    }
}

/**
 * Generic placeholder rendered by founder sub-routes until the live
 * SECURITY DEFINER RPCs ship. Keeps the UI shell discoverable so we can
 * design + iterate on the layouts before backend work lands.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun FounderPlaceholderScreen(
    title: String,
    subtitle: String,
    icon: ImageVector,
    onBack: () -> Unit,
) {
    Scaffold(
        topBar = {
            com.equipseva.app.designsystem.components.ESBackTopBar(
                title = title,
                onBack = onBack,
            )
        },
    ) { inner ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(inner)
                .background(Surface50)
                .padding(Spacing.lg),
            verticalArrangement = Arrangement.spacedBy(Spacing.md),
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(16.dp))
                    .background(Surface0)
                    .border(1.dp, Surface200, RoundedCornerShape(16.dp))
                    .padding(Spacing.lg),
                horizontalArrangement = Arrangement.spacedBy(Spacing.md),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Box(
                    modifier = Modifier
                        .size(48.dp)
                        .clip(RoundedCornerShape(12.dp))
                        .background(BrandGreen.copy(alpha = 0.12f)),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(imageVector = icon, contentDescription = null, tint = BrandGreen)
                }
                Column(modifier = Modifier.weight(1f)) {
                    Text(text = title, fontSize = 16.sp, fontWeight = FontWeight.Bold, color = Ink900)
                    Text(text = subtitle, fontSize = 13.sp, color = Ink500)
                }
            }
            Text(
                text = "Live data wires in once the founder admin RPCs ship in the next pass.",
                fontSize = 13.sp,
                color = Ink500,
            )
        }
    }
}
