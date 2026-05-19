package com.equipseva.app.features.founder

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.KeyboardArrowRight
import androidx.compose.material.icons.outlined.Apartment
import androidx.compose.material.icons.outlined.Bolt
import androidx.compose.material.icons.outlined.CurrencyRupee
import androidx.compose.material.icons.outlined.Person
import androidx.compose.material.icons.outlined.Shield
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.lifecycle.compose.collectAsStateWithLifecycle
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
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.core.util.formatRupees
import com.equipseva.app.designsystem.components.EsSection
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.components.Pill
import com.equipseva.app.designsystem.components.PillKind
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaDanger500
import com.equipseva.app.designsystem.theme.SevaGlowRaw
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaGreen900
import com.equipseva.app.designsystem.theme.SevaInfo500
import com.equipseva.app.designsystem.theme.SevaInk400
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk600
import com.equipseva.app.designsystem.theme.SevaInk900
import com.equipseva.app.designsystem.theme.SevaWarning500
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.filterIsInstance
import kotlinx.coroutines.flow.firstOrNull
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

@HiltViewModel
class FounderDashboardViewModel @Inject constructor(
    private val repo: FounderRepository,
    private val authRepository: com.equipseva.app.core.auth.AuthRepository,
) : ViewModel() {
    data class UiState(
        val loading: Boolean = true,
        val stats: FounderRepository.DashboardStats? = null,
        val error: String? = null,
        val founderEmail: String? = null,
        val topEngineers: List<FounderRepository.TopEngineerRow> = emptyList(),
    )
    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init {
        reload()
        viewModelScope.launch {
            val signedIn = authRepository.sessionState
                .filterIsInstance<com.equipseva.app.core.auth.AuthSession.SignedIn>()
                .firstOrNull() ?: return@launch
            _state.update { it.copy(founderEmail = signedIn.email) }
        }
    }

    fun reload() {
        _state.update { it.copy(loading = true, error = null) }
        viewModelScope.launch {
            // Round 349 — top engineers fetched in parallel; failure is
            // non-fatal (card hides, dashboard still loads).
            val leaderboardJob = launch {
                repo.fetchTopEngineers(windowDays = 30, limit = 5)
                    .onSuccess { rows -> _state.update { it.copy(topEngineers = rows) } }
            }
            repo.fetchDashboardStats()
                .onSuccess { s ->
                    // No more DUMMY_STATS substitution — an empty platform
                    // is a real signal (no pending KYC / no orders today),
                    // not a query failure to paper over. Founder needs to
                    // see honest zeros, not a fake "7 / 3 / 14" tile that
                    // implies operational load that doesn't exist.
                    _state.update { it.copy(loading = false, stats = s) }
                }
                .onFailure { err ->
                    _state.update {
                        it.copy(
                            loading = false,
                            stats = FounderRepository.DashboardStats(),
                            error = err.toUserMessage(),
                        )
                    }
                }
            leaderboardJob.join()
        }
    }
}

/**
 * Founder dashboard. Round 10 (admin) re-skin to match newdesign.zip:
 * AdminDashboard — gradient hero (Today payments) + KPI strip + Queues
 * card (6 rows) + Coverage (engineers per district horizontal-bar list).
 *
 * Email-pinned to ganesh1431.dhanavath@gmail.com via `Profile.isFounder()`.
 * Server-side `is_founder()` gate is the ultimate enforcement.
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
    onOpenEscrowDisputes: () -> Unit = {},
    onOpenAmcEscalations: () -> Unit = {},
    onOpenCashSuspended: () -> Unit = {},
    onOpenPartsOutliers: () -> Unit = {},
    onOpenResolvedDisputes: () -> Unit = {},
    onOpenSpotAudits: () -> Unit = {},
    // Round 364 — drill-down for r352 "Expiring 30d" KPI.
    onOpenAmcExpiring: () -> Unit = {},
    onBack: () -> Unit = {},
    viewModel: FounderDashboardViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val stats = state.stats

    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(
                title = "Admin dashboard",
                subtitle = state.founderEmail?.let { "Founder · $it" } ?: "Founder",
                onBack = onBack,
            )
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState()),
            ) {
                // Hero — jobs posted today. The earlier copy led with a
                // "₹—" payments figure (admin_dashboard_stats RPC has no
                // payments-today field) which read as a missing value, not
                // a placeholder; reframe around the field we actually have.
                FounderHero(jobsToday = stats?.ordersToday)

                // KPI strip — 2 cards. The earlier 3rd "Users" card always
                // showed "—" because admin_dashboard_stats RPC has no
                // users-count field; restore once the count ships.
                KpiStrip(
                    pendingKyc = stats?.pendingKyc,
                    openReports = stats?.pendingReports,
                )

                // Round 343 — growth metrics row. 4 cards: new signups
                // today, active repair jobs, AMC active, AMC expired.
                GrowthKpiStrip(
                    newSignupsToday = stats?.newSignupsToday,
                    activeRepairJobs = stats?.activeRepairJobs,
                    amcContractsActive = stats?.amcContractsActive,
                    amcContractsExpired = stats?.amcContractsExpired,
                    amcContractsExpiringSoon = stats?.amcContractsExpiringSoon,
                    amcContractsPaused = stats?.amcContractsPaused,
                    onOpenExpiring = onOpenAmcExpiring,
                )

                // Round 349 — Top engineers (last 30d) by released-escrow
                // revenue. Only shown when at least one engineer has been
                // paid out in the window; otherwise hidden so the dashboard
                // doesn't render an empty card on a cold platform.
                if (state.topEngineers.isNotEmpty()) {
                    EsSection(title = "Top engineers (30d)") {
                        Box(modifier = Modifier.padding(horizontal = 16.dp)) {
                            TopEngineersCard(rows = state.topEngineers)
                        }
                    }
                }

                // Queues card — 6 stacked rows.
                EsSection(title = "Queues") {
                    Box(modifier = Modifier.padding(horizontal = 16.dp)) {
                        QueuesCard(
                            pendingKyc = stats?.pendingKyc ?: 0,
                            openReports = stats?.pendingReports ?: 0,
                            pendingSellers = stats?.pendingSellers ?: 0,
                            totalUsers = 0,
                            onOpenKyc = onOpenKycQueue,
                            onOpenBuyerKyc = onOpenBuyerKyc,
                            onOpenReports = onOpenReportsQueue,
                            onOpenUsers = onOpenUsers,
                            onOpenPayments = onOpenPayments,
                            onOpenIntegrity = onOpenIntegrityFlags,
                        )
                    }
                }

                // Operations — extra rows the design doesn't ship but our app
                // already exposes. Keep them in a second card so the queue
                // section stays pixel-aligned with screens-admin.jsx.
                EsSection(title = "Operations") {
                    Box(modifier = Modifier.padding(horizontal = 16.dp)) {
                        QueuesCardOps(
                            onOpenCategories = onOpenCategories,
                            onOpenZones = onOpenEngineerZones,
                        )
                    }
                }

                // v2.1 PR-D21 — anti-disintermediation ops queues. These
                // surface admin RPCs that previously had no UI: escrow
                // disputes, AMC rotation escalations, cash-flag
                // auto-suspensions, parts-cost outliers.
                EsSection(title = "Anti-leak ops") {
                    Box(modifier = Modifier.padding(horizontal = 16.dp)) {
                        QueuesCardAntiLeak(
                            onOpenEscrowDisputes = onOpenEscrowDisputes,
                            onOpenAmcEscalations = onOpenAmcEscalations,
                            onOpenCashSuspended = onOpenCashSuspended,
                            onOpenPartsOutliers = onOpenPartsOutliers,
                            onOpenResolvedDisputes = onOpenResolvedDisputes,
                            onOpenSpotAudits = onOpenSpotAudits,
                        )
                    }
                }

                // CoverageCard removed 2026-05-10: hard-coded
                // Hyd/Nalg/Sury/Wgl/Khm rows contradicted live data and
                // had been gated behind `if (false)` for two days.
                // Engineer Zones tile in Operations exposes the live
                // counts when the RPC ships.
                Spacer(Modifier.height(32.dp))
            }
        }
    }
}

@Composable
private fun FounderHero(jobsToday: Int?) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp)
            .clip(RoundedCornerShape(14.dp))
            .background(
                Brush.linearGradient(listOf(SevaGreen900, Color(0xFF042619))),
            ),
    ) {
        Icon(
            imageVector = Icons.Outlined.Shield,
            contentDescription = null,
            tint = SevaGlowRaw.copy(alpha = 0.15f),
            modifier = Modifier
                .align(Alignment.TopEnd)
                .offset(x = 10.dp, y = (-10).dp)
                .size(120.dp),
        )
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                text = "Jobs posted today",
                fontSize = 12.sp,
                color = Color.White.copy(alpha = 0.65f),
            )
            Text(
                text = (jobsToday ?: 0).toString(),
                fontSize = 28.sp,
                fontWeight = FontWeight.Bold,
                letterSpacing = (-0.56).sp,
                color = Color.White,
                modifier = Modifier.padding(top = 4.dp),
            )
        }
    }
}

@Composable
private fun KpiStrip(
    pendingKyc: Int?,
    openReports: Int?,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 4.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        KpiCell(
            label = "Pending KYC",
            value = pendingKyc?.toString() ?: "—",
            valueColor = SevaWarning500,
            sub = "needs review",
            modifier = Modifier.weight(1f),
        )
        KpiCell(
            label = "Reports",
            value = openReports?.toString() ?: "—",
            valueColor = SevaDanger500,
            sub = "open",
            modifier = Modifier.weight(1f),
        )
    }
    Spacer(Modifier.height(4.dp))
}

// Round 343 — second KPI row covering growth metrics. Same visual
// shape as KpiStrip (4 cards, 8.dp spacing) so the dashboard reads
// as one connected band.
@Composable
private fun GrowthKpiStrip(
    newSignupsToday: Int?,
    activeRepairJobs: Int?,
    amcContractsActive: Int?,
    amcContractsExpired: Int?,
    amcContractsExpiringSoon: Int?,
    amcContractsPaused: Int?,
    onOpenExpiring: () -> Unit = {},
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 4.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        KpiCell(
            label = "New signups",
            value = newSignupsToday?.toString() ?: "—",
            valueColor = SevaGreen700,
            sub = "today",
            modifier = Modifier.weight(1f),
        )
        KpiCell(
            label = "Active jobs",
            value = activeRepairJobs?.toString() ?: "—",
            valueColor = SevaInfo500,
            sub = "in pipeline",
            modifier = Modifier.weight(1f),
        )
    }
    Spacer(Modifier.height(4.dp))
    // Row 2 — AMC healthy lifecycle: active + forward-looking expiry.
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 4.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        KpiCell(
            label = "AMC active",
            value = amcContractsActive?.toString() ?: "—",
            valueColor = SevaGreen700,
            sub = "contracts",
            modifier = Modifier.weight(1f),
        )
        // Round 352 — forward-looking renewal signal. Warn-color to nudge
        // outreach before the contract lapses (vs r343 "AMC expired"
        // which is reactive). Round 364 — tappable drill-down to the
        // full list when count > 0.
        KpiCell(
            label = "Expiring 30d",
            value = amcContractsExpiringSoon?.toString() ?: "—",
            valueColor = SevaWarning500,
            sub = "renew now",
            modifier = Modifier
                .weight(1f)
                .then(
                    if ((amcContractsExpiringSoon ?: 0) > 0)
                        Modifier.clickable(onClick = onOpenExpiring)
                    else Modifier
                ),
        )
    }
    Spacer(Modifier.height(4.dp))
    // Round 366 — Row 3: AMC problem states. Paused = silent service
    // stop (payment pool negative, visits not firing). Expired = lapsed,
    // already churned. Keeping in their own row keeps the forward-looking
    // row 2 visually distinct from the trouble row 3.
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 4.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        KpiCell(
            label = "AMC paused",
            value = amcContractsPaused?.toString() ?: "—",
            valueColor = SevaDanger500,
            sub = "visits stopped",
            modifier = Modifier.weight(1f),
        )
        KpiCell(
            label = "AMC expired",
            value = amcContractsExpired?.toString() ?: "—",
            valueColor = SevaInk500,
            sub = "lapsed",
            modifier = Modifier.weight(1f),
        )
    }
    Spacer(Modifier.height(4.dp))
}

@Composable
private fun KpiCell(
    label: String,
    value: String,
    valueColor: Color,
    sub: String?,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
            .padding(12.dp),
    ) {
        Text(
            text = label.uppercase(),
            fontSize = 10.sp,
            fontWeight = FontWeight.SemiBold,
            color = SevaInk500,
            letterSpacing = 0.5.sp,
        )
        Text(
            text = value,
            fontSize = 22.sp,
            fontWeight = FontWeight.Bold,
            color = valueColor,
            letterSpacing = (-0.22).sp,
            modifier = Modifier.padding(top = 4.dp),
        )
        if (sub != null) {
            Text(
                text = sub,
                fontSize = 10.sp,
                color = SevaInk400,
                modifier = Modifier.padding(top = 2.dp),
            )
        }
    }
}

@Composable
private fun QueuesCard(
    pendingKyc: Int,
    openReports: Int,
    pendingSellers: Int,
    totalUsers: Int,
    onOpenKyc: () -> Unit,
    onOpenBuyerKyc: () -> Unit,
    onOpenReports: () -> Unit,
    onOpenUsers: () -> Unit,
    onOpenPayments: () -> Unit,
    onOpenIntegrity: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp)),
    ) {
        QueueRow(
            icon = Icons.Outlined.Shield,
            iconTint = SevaWarning500,
            title = "Engineer KYC",
            subtitle = "$pendingKyc pending",
            trailingPill = pendingKyc.takeIf { it > 0 }?.toString() to PillKind.Warn,
            onClick = onOpenKyc,
            showDivider = true,
        )
        QueueRow(
            icon = Icons.Outlined.Apartment,
            iconTint = SevaInfo500,
            title = "Buyer KYC",
            subtitle = "Trade docs",
            trailingPill = pendingSellers.takeIf { it > 0 }?.toString() to PillKind.Info,
            onClick = onOpenBuyerKyc,
            showDivider = true,
        )
        QueueRow(
            icon = Icons.Outlined.Bolt,
            iconTint = SevaDanger500,
            title = "Reports",
            subtitle = "$openReports open",
            trailingPill = openReports.takeIf { it > 0 }?.toString() to PillKind.Danger,
            onClick = onOpenReports,
            showDivider = true,
        )
        QueueRow(
            icon = Icons.Outlined.Person,
            iconTint = SevaInk600,
            title = "Users",
            subtitle = if (totalUsers > 0) "$totalUsers total" else "Search profiles",
            trailingPill = null,
            onClick = onOpenUsers,
            showDivider = true,
        )
        QueueRow(
            icon = Icons.Outlined.CurrencyRupee,
            iconTint = SevaGreen700,
            title = "Payments",
            subtitle = "Read-only",
            trailingPill = null,
            onClick = onOpenPayments,
            showDivider = true,
        )
        QueueRow(
            icon = Icons.Outlined.Shield,
            iconTint = SevaDanger500,
            title = "Integrity flags",
            subtitle = "Play Integrity alerts",
            trailingPill = null,
            onClick = onOpenIntegrity,
            showDivider = false,
        )
    }
}

@Composable
private fun QueuesCardOps(
    onOpenCategories: () -> Unit,
    onOpenZones: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp)),
    ) {
        QueueRow(
            icon = Icons.Outlined.Apartment,
            iconTint = SevaInk600,
            title = "Equipment categories",
            subtitle = "Curate the canonical list",
            trailingPill = null,
            onClick = onOpenCategories,
            showDivider = true,
        )
        QueueRow(
            icon = Icons.Outlined.Person,
            iconTint = SevaGreen700,
            title = "Engineer zones",
            subtitle = "Verified engineers per district",
            trailingPill = null,
            onClick = onOpenZones,
            showDivider = false,
        )
    }
}

@Composable
private fun QueuesCardAntiLeak(
    onOpenEscrowDisputes: () -> Unit,
    onOpenAmcEscalations: () -> Unit,
    onOpenCashSuspended: () -> Unit,
    onOpenPartsOutliers: () -> Unit,
    onOpenResolvedDisputes: () -> Unit,
    onOpenSpotAudits: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp)),
    ) {
        QueueRow(
            icon = Icons.Outlined.CurrencyRupee,
            iconTint = SevaDanger500,
            title = "Escrow disputes",
            subtitle = "Hospital opened a dispute",
            trailingPill = null,
            onClick = onOpenEscrowDisputes,
            showDivider = true,
        )
        QueueRow(
            icon = Icons.Outlined.Bolt,
            iconTint = SevaWarning500,
            title = "AMC escalations",
            subtitle = "Rotation exhausted / no engineer",
            trailingPill = null,
            onClick = onOpenAmcEscalations,
            showDivider = true,
        )
        QueueRow(
            icon = Icons.Outlined.Shield,
            iconTint = SevaDanger500,
            title = "Cash-flag suspensions",
            subtitle = "Engineers auto-paused for off-platform",
            trailingPill = null,
            onClick = onOpenCashSuspended,
            showDivider = true,
        )
        QueueRow(
            icon = Icons.Outlined.CurrencyRupee,
            iconTint = SevaWarning500,
            title = "Parts-cost outliers",
            subtitle = "Charges >5× category average",
            trailingPill = null,
            onClick = onOpenPartsOutliers,
            showDivider = true,
        )
        QueueRow(
            icon = Icons.AutoMirrored.Outlined.KeyboardArrowRight,
            iconTint = SevaInk600,
            title = "Resolved disputes",
            subtitle = "Last 30 days · audit ledger",
            trailingPill = null,
            onClick = onOpenResolvedDisputes,
            showDivider = true,
        )
        QueueRow(
            icon = Icons.Outlined.Person,
            iconTint = SevaInfo500,
            title = "Spot-audit responses",
            subtitle = "1-in-20 random sweep",
            trailingPill = null,
            onClick = onOpenSpotAudits,
            showDivider = false,
        )
    }
}

@Composable
private fun QueueRow(
    icon: ImageVector,
    iconTint: Color,
    title: String,
    subtitle: String,
    trailingPill: Pair<String?, PillKind>?,
    onClick: () -> Unit,
    showDivider: Boolean,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = iconTint,
            modifier = Modifier.size(20.dp),
        )
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = title,
                fontSize = 14.sp,
                fontWeight = FontWeight.SemiBold,
                color = SevaInk900,
            )
            Text(
                text = subtitle,
                fontSize = 12.sp,
                color = SevaInk500,
                modifier = Modifier.padding(top = 2.dp),
            )
        }
        val pillText = trailingPill?.first
        if (pillText != null) {
            Pill(text = pillText, kind = trailingPill.second)
            Spacer(Modifier.width(8.dp))
        }
        Icon(
            imageVector = Icons.AutoMirrored.Outlined.KeyboardArrowRight,
            contentDescription = null,
            tint = SevaInk400,
            modifier = Modifier.size(18.dp),
        )
    }
    if (showDivider) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(1.dp)
                .padding(start = 14.dp, end = 14.dp)
                .background(BorderDefault),
        )
    }
}


@Composable
private fun TopEngineersCard(rows: List<FounderRepository.TopEngineerRow>) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp)),
    ) {
        rows.forEachIndexed { index, row ->
            TopEngineerRow(rank = index + 1, row = row)
            if (index < rows.lastIndex) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(1.dp)
                        .background(BorderDefault),
                )
            }
        }
    }
}

@Composable
private fun TopEngineerRow(rank: Int, row: FounderRepository.TopEngineerRow) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 14.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Text(
            text = "#$rank",
            color = SevaInk500,
            fontSize = 12.sp,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier.width(28.dp),
        )
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = row.fullName,
                fontSize = 14.sp,
                fontWeight = FontWeight.SemiBold,
                color = SevaInk900,
            )
            Text(
                text = "${row.jobsCompleted} job${if (row.jobsCompleted == 1L) "" else "s"} released",
                fontSize = 12.sp,
                color = SevaInk500,
            )
        }
        Text(
            text = formatRupees(row.revenueInr),
            fontSize = 14.sp,
            fontWeight = FontWeight.Bold,
            color = SevaGreen700,
        )
    }
}
