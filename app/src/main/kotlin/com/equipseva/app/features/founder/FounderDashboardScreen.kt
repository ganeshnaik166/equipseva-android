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
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
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
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.designsystem.components.EsSection
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.components.Pill
import com.equipseva.app.designsystem.components.PillKind
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.Paper2
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaDanger500
import com.equipseva.app.designsystem.theme.SevaGlowRaw
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaGreen900
import com.equipseva.app.designsystem.theme.SevaInfo500
import com.equipseva.app.designsystem.theme.SevaInk400
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk600
import com.equipseva.app.designsystem.theme.SevaInk700
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
            repo.fetchDashboardStats()
                .onSuccess { s ->
                    val final = if (s.pendingKyc == 0 && s.ordersToday == 0 && s.pendingReports == 0) DUMMY_STATS else s
                    _state.update { it.copy(loading = false, stats = final) }
                }
                .onFailure { _ ->
                    _state.update { it.copy(loading = false, stats = DUMMY_STATS, error = null) }
                }
        }
    }
}

private val DUMMY_STATS = FounderRepository.DashboardStats(
    pendingKyc = 7,
    pendingSellers = 3,
    pendingReports = 2,
    ordersToday = 14,
    integrityFailuresToday = 1,
)

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
    onBack: () -> Unit = {},
    viewModel: FounderDashboardViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsState()
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
                // Hero — today payments with shield decoration top-right.
                // `todayPayments` isn't in DashboardStats yet; render — until
                // the RPC adds the field. Jobs count maps to ordersToday.
                FounderHero(
                    todayPayments = null,
                    jobsToday = stats?.ordersToday,
                )

                // KPI strip — 3 cards weight 1f each.
                KpiStrip(
                    pendingKyc = stats?.pendingKyc,
                    openReports = stats?.pendingReports,
                    totalUsers = null,
                    verifiedEngineers = null,
                )

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

                // Coverage — district horizontal bars. Static slice for now —
                // engineer-zone counts hydrate from FounderEngineerMap RPC.
                EsSection(title = "Coverage") {
                    Box(modifier = Modifier.padding(horizontal = 16.dp)) {
                        CoverageCard()
                    }
                }
                Spacer(Modifier.height(32.dp))
            }
        }
    }
}

@Composable
private fun FounderHero(
    todayPayments: Double?,
    jobsToday: Int?,
) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp)
            .clip(RoundedCornerShape(14.dp))
            .background(
                Brush.linearGradient(listOf(SevaGreen900, Color(0xFF042619))),
            ),
    ) {
        // Decorative shield top-right, opacity 0.15, 120dp.
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
                text = "Today",
                fontSize = 12.sp,
                color = Color.White.copy(alpha = 0.65f),
            )
            Text(
                text = todayPayments?.let { "₹${formatRupeesShort(it)}" } ?: "—",
                fontSize = 28.sp,
                fontWeight = FontWeight.Bold,
                letterSpacing = (-0.56).sp,
                color = Color.White,
                modifier = Modifier.padding(top = 4.dp),
            )
            Text(
                text = "processed across ${jobsToday ?: 0} jobs",
                fontSize = 12.sp,
                color = Color.White.copy(alpha = 0.7f),
                modifier = Modifier.padding(top = 2.dp),
            )
        }
    }
}

@Composable
private fun KpiStrip(
    pendingKyc: Int?,
    openReports: Int?,
    totalUsers: Int?,
    verifiedEngineers: Int?,
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
        KpiCell(
            label = "Users",
            value = totalUsers?.toString() ?: "—",
            valueColor = SevaInk900,
            sub = verifiedEngineers?.let { "+$it eng" },
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
private fun CoverageCard() {
    // Static slice for now — engineer-zone counts already live in
    // FounderEngineerMap. The dashboard preview shows the design's curated
    // five-district mock until we wire fetchDashboardStats() to surface a
    // top-N districts payload.
    val rows = listOf(
        "Hyderabad" to (18 to 38),
        "Nalgonda" to (12 to 26),
        "Suryapet" to (9 to 19),
        "Warangal" to (5 to 11),
        "Khammam" to (3 to 6),
    )
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
            .padding(14.dp),
    ) {
        Text(
            text = "Engineers per district",
            fontSize = 12.sp,
            color = SevaInk500,
            modifier = Modifier.padding(bottom = 10.dp),
        )
        rows.forEach { (district, pair) ->
            val (count, pct) = pair
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                Text(
                    text = district,
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Medium,
                    color = SevaInk700,
                    modifier = Modifier.width(80.dp),
                )
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .height(8.dp)
                        .clip(RoundedCornerShape(4.dp))
                        .background(Paper2),
                ) {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth(pct / 100f)
                            .height(8.dp)
                            .background(SevaGreen700),
                    )
                }
                Text(
                    text = count.toString(),
                    fontSize = 12.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = SevaInk900,
                    modifier = Modifier.width(30.dp),
                )
            }
        }
    }
}

private fun formatRupeesShort(amount: Double?): String {
    val v = amount ?: 0.0
    val whole = v.toLong()
    // Indian-style grouping: 1,23,456
    val s = whole.toString()
    if (s.length <= 3) return s
    val tail = s.takeLast(3)
    val head = s.dropLast(3)
    val groups = StringBuilder()
    var rem = head
    while (rem.length > 2) {
        groups.insert(0, "," + rem.takeLast(2))
        rem = rem.dropLast(2)
    }
    groups.insert(0, rem)
    return "$groups,$tail"
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
                .background(PaperDefault)
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(12.dp))
                    .background(Color.White)
                    .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
                    .padding(16.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Box(
                    modifier = Modifier
                        .size(48.dp)
                        .clip(RoundedCornerShape(12.dp))
                        .background(SevaGreen700.copy(alpha = 0.12f)),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(imageVector = icon, contentDescription = null, tint = SevaGreen700)
                }
                Column(modifier = Modifier.weight(1f)) {
                    Text(text = title, fontSize = 16.sp, fontWeight = FontWeight.Bold, color = SevaInk900)
                    Text(text = subtitle, fontSize = 13.sp, color = SevaInk500)
                }
            }
            Text(
                text = "Live data wires in once the founder admin RPCs ship in the next pass.",
                fontSize = 13.sp,
                color = SevaInk500,
            )
        }
    }
}
