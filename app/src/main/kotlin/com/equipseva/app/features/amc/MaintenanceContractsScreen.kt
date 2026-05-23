package com.equipseva.app.features.amc

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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.CalendarMonth
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.util.formatRupees
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.amc.AmcRepository
import com.equipseva.app.core.data.prefs.UserPrefs
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.components.Pill
import com.equipseva.app.designsystem.components.PillKind
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk700
import com.equipseva.app.designsystem.theme.SevaInk900
import com.equipseva.app.features.auth.UserRole
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.filterIsInstance
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.firstOrNull
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/**
 * Unified AMC list row used by both hospital + engineer surfaces.
 * Hospital sees engineer name + auto-renew chip; engineer sees hospital
 * name + primary/fallback chip. We project both server shapes into this
 * common type so the list composable doesn't fork.
 */
data class AmcListItem(
    val id: String,
    val title: String,           // engineer name OR hospital name
    val titleSubtitle: String,   // "Primary" / "Fallback" / "₹X / month"
    val status: String,
    val visitFrequency: String,
    val monthlyFeeRupees: Double,
    val nextVisitAt: String?,
    val endDate: String,         // round 314 — drives "Expires in X days" pill
    val visitsCompleted: Int,
    val visitsPerYear: Int,
    val autoRenew: Boolean,
)

@HiltViewModel
class MaintenanceContractsViewModel @Inject constructor(
    private val repo: AmcRepository,
    private val userPrefs: UserPrefs,
    private val auth: AuthRepository,
) : ViewModel() {

    data class UiState(
        val loading: Boolean = true,
        // Round 388 — pull-to-refresh inline indicator distinct from cold-load.
        val refreshing: Boolean = false,
        val error: String? = null,
        val role: UserRole? = null,
        val items: List<AmcListItem> = emptyList(),
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init {
        refresh(initial = true)
    }

    fun onPullToRefresh() = refresh(initial = false)

    fun refresh(initial: Boolean = false) {
        _state.update {
            it.copy(
                loading = initial || it.items.isEmpty(),
                refreshing = !initial && it.items.isNotEmpty(),
                error = null,
            )
        }
        viewModelScope.launch {
            // Wait for an authenticated session — list_amc_contracts_*
            // RPCs are auth-scoped via auth.uid() and would return [] for
            // anon callers. If user is signed-out, the screen renders
            // the empty-state CTA pointing at the engineer directory.
            val session = auth.sessionState
                .filterIsInstance<AuthSession.SignedIn>()
                .firstOrNull()
            if (session == null) {
                _state.update { it.copy(loading = false, refreshing = false, items = emptyList()) }
                return@launch
            }

            val role = runCatching { userPrefs.activeRole.first() }.getOrNull()
                ?.let { UserRole.fromKey(it) }

            when (role) {
                UserRole.HOSPITAL -> repo.listForHospital().fold(
                    onSuccess = { rows ->
                        _state.update {
                            it.copy(
                                loading = false,
                                refreshing = false,
                                role = role,
                                items = rows.map(::toItemHospital),
                            )
                        }
                    },
                    onFailure = { e ->
                        _state.update { it.copy(loading = false, refreshing = false, role = role, error = e.toUserMessage()) }
                    },
                )
                else -> repo.listForEngineer().fold(
                    onSuccess = { rows ->
                        _state.update {
                            it.copy(
                                loading = false,
                                refreshing = false,
                                role = role,
                                items = rows.map(::toItemEngineer),
                            )
                        }
                    },
                    onFailure = { e ->
                        _state.update { it.copy(loading = false, refreshing = false, role = role, error = e.toUserMessage()) }
                    },
                )
            }
        }
    }

    private fun toItemHospital(c: AmcRepository.HospitalContract) = AmcListItem(
        id = c.id,
        title = c.primaryEngineerName,
        titleSubtitle = "${formatRupees(c.monthlyFeeRupees)} / month",
        status = c.status,
        visitFrequency = c.visitFrequency,
        monthlyFeeRupees = c.monthlyFeeRupees,
        nextVisitAt = c.nextVisitAt,
        endDate = c.endDate,
        visitsCompleted = c.visitsCompleted,
        visitsPerYear = c.visitsPerYear,
        autoRenew = c.autoRenew,
    )

    private fun toItemEngineer(c: AmcRepository.EngineerContract) = AmcListItem(
        id = c.id,
        title = c.hospitalName,
        titleSubtitle = if (c.isPrimary) "Primary" else "Fallback",
        status = c.status,
        visitFrequency = c.visitFrequency,
        monthlyFeeRupees = c.monthlyFeeRupees,
        nextVisitAt = c.nextVisitAt,
        endDate = c.endDate,
        visitsCompleted = c.visitsCompleted,
        visitsPerYear = c.visitsPerYear,
        autoRenew = false, // not exposed for the engineer view
    )
}

@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
fun MaintenanceContractsScreen(
    onBack: () -> Unit,
    onOpenContract: (String) -> Unit,
    onBrowseEngineers: () -> Unit,
    viewModel: MaintenanceContractsViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    // Picks up newly created / cancelled contracts on return.
    com.equipseva.app.designsystem.util.RefreshOnReturn { viewModel.refresh() }

    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(title = "Maintenance contracts", onBack = onBack)
            // Round 388 — pull-to-refresh. Matches r378-r387 pattern.
            androidx.compose.material3.pulltorefresh.PullToRefreshBox(
                isRefreshing = state.refreshing,
                onRefresh = viewModel::onPullToRefresh,
                modifier = Modifier.fillMaxSize(),
            ) {
                when {
                    state.loading -> Box(
                        modifier = Modifier.fillMaxSize(),
                        contentAlignment = Alignment.Center,
                    ) { CircularProgressIndicator() }

                    // Round 405 — render error state with retry. Previously a
                    // failed RPC stayed captured in UiState.error but the
                    // screen fell through to the "No contracts yet" empty
                    // state, masking the failure as "user has no contracts".
                    state.error != null && state.items.isEmpty() -> EmptyStateView(
                        icon = Icons.Outlined.CalendarMonth,
                        title = "Couldn't load",
                        subtitle = state.error,
                        ctaLabel = "Try again",
                        onCta = { viewModel.refresh() },
                    )

                    state.items.isEmpty() -> EmptyStateView(
                        icon = Icons.Outlined.CalendarMonth,
                        title = "No maintenance contracts yet",
                        subtitle = if (state.role == UserRole.ENGINEER) {
                            "Contracts where a hospital adds you as primary or fallback engineer will appear here."
                        } else {
                            "Set up monthly maintenance with a verified engineer for predictable preventive care."
                        },
                        ctaLabel = if (state.role == UserRole.HOSPITAL) "Browse engineers" else null,
                        onCta = if (state.role == UserRole.HOSPITAL) onBrowseEngineers else null,
                    )

                    else -> LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = androidx.compose.foundation.layout.PaddingValues(
                            horizontal = 16.dp,
                            vertical = 12.dp,
                        ),
                        verticalArrangement = Arrangement.spacedBy(10.dp),
                    ) {
                        items(state.items, key = { it.id }) { item ->
                            ContractCard(
                                item = item,
                                onClick = { onOpenContract(item.id) },
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun ContractCard(
    item: AmcListItem,
    onClick: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
            .clickable(onClick = onClick)
            .padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.Top,
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    item.title,
                    color = SevaInk900,
                    fontSize = 15.sp,
                    fontWeight = FontWeight.SemiBold,
                )
                Spacer(Modifier.height(2.dp))
                Text(item.titleSubtitle, color = SevaInk500, fontSize = 12.sp)
            }
            StatusPillFor(item.status)
        }
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Pill(text = prettyFrequency(item.visitFrequency), kind = PillKind.Neutral)
            Text(
                text = contractVisitsLabel(item.visitsCompleted, item.visitsPerYear),
                color = SevaInk700,
                fontSize = 12.sp,
            )
            if (item.autoRenew) Pill(text = "Auto-renew", kind = PillKind.Default)
        }
        // Round 314 — surface near-expiry warning at list level so the
        // hospital sees urgency without opening each contract.
        // Round 353 — widen threshold to 30 days so this aligns with the
        // founder dashboard "Expiring 30d" KPI; previously hospital saw
        // pills only within 14d while founder ops already flagged the
        // contract 16 days earlier. Show "N days" countdown for urgency.
        if (item.status == "active"
            && com.equipseva.app.core.util.isWithinDays(item.endDate, 30)
        ) {
            val n = com.equipseva.app.core.util.daysUntil(item.endDate)
            val (label, kind) = contractExpiryPillTextAndKind(
                daysUntilEnd = n,
                prettyEndDate = prettyDate(item.endDate),
            )
            Pill(text = label, kind = kind)
        }
        if (!item.nextVisitAt.isNullOrBlank()) {
            Text(
                text = "Next visit: ${prettyDate(item.nextVisitAt)}",
                color = SevaInk500,
                fontSize = 12.sp,
            )
        }
    }
}

@Composable
internal fun StatusPillFor(status: String) {
    val (label, kind) = amcStatusLabelAndKind(status)
    Pill(text = label, kind = kind)
}

/**
 * Pure mapping behind [StatusPillFor]: maps an AMC contract status
 * key (`active`, `paused`, `expired`, `cancelled`, `renewal_failed`)
 * to user-facing copy + a [PillKind] tone.
 *
 * The case-insensitive comparison lets a future server-side write
 * use mixed-case without crashing the card — pin so a tightening
 * doesn't slip past review.
 */
internal fun amcStatusLabelAndKind(status: String): Pair<String, PillKind> =
    when (status.lowercase()) {
        "active" -> "Active" to PillKind.Success
        "paused" -> "Paused" to PillKind.Danger
        "expired" -> "Expired" to PillKind.Neutral
        "cancelled" -> "Cancelled" to PillKind.Neutral
        "renewal_failed" -> "Renewal failed" to PillKind.Danger
        else -> status.replaceFirstChar { it.uppercase() } to PillKind.Neutral
    }

internal fun prettyFrequency(f: String): String = when (f.lowercase()) {
    "weekly" -> "Weekly"
    "biweekly" -> "Every 2 weeks"
    "monthly" -> "Monthly"
    "quarterly" -> "Quarterly"
    else -> f.replaceFirstChar { it.uppercase() }
}

// prettyDate lives in core.util now — re-export the same name from the
// amc package so existing same-package callers don't need imports.
// Both founder + amc surfaces share the single implementation.
internal fun prettyDate(iso: String): String =
    com.equipseva.app.core.util.prettyDate(iso)

/**
 * Visits subline on the hospital's maintenance-contracts card:
 * "N / M visits".
 *
 * Sibling of [com.equipseva.app.features.founder.pausedAmcVisitsLine]
 * but with surface-specific phrasing — hospital says "visits" while
 * founder says "per year". Pin the asymmetry so a refactor that
 * unified them doesn't swap the noun on either surface.
 */
internal fun contractVisitsLabel(visitsCompleted: Int, visitsPerYear: Int): String =
    "$visitsCompleted / $visitsPerYear visits"

/**
 * Expiry pill text + colour kind on the hospital's maintenance-
 * contracts card.
 *
 * Decision tree (daysUntilEnd):
 *   - null (unparseable) → "Expires $prettyEndDate" + Warn
 *   - <= 0 → "Expires today" + Danger
 *   - == 1 → "Expires in 1 day" (singular) + Danger
 *   - <= 7 → "Expires in N days" + Danger (boundary INCLUSIVE)
 *   - > 7 → "Expires in N days" + Warn (still within the 30d
 *     near-expiry window the caller gates on)
 *
 * Critical cross-surface invariant: the 7-day INCLUSIVE Danger
 * boundary mirrors [com.equipseva.app.features.founder.expiringAmcPillTextAndKind].
 * The hospital + founder MUST agree on the urgency cue for the
 * same contract (r353 cross-surface invariant). A refactor that
 * relaxed either side to <= 6 would silently desynchronise them.
 *
 * Pin the singular "1 day" branch — a regression that always
 * appended "days" would surface "1 days" on the most-urgent row.
 */
internal fun contractExpiryPillTextAndKind(
    daysUntilEnd: Long?,
    prettyEndDate: String,
): Pair<String, PillKind> {
    val text = when {
        daysUntilEnd == null -> "Expires $prettyEndDate"
        daysUntilEnd <= 0L -> "Expires today"
        daysUntilEnd == 1L -> "Expires in 1 day"
        else -> "Expires in $daysUntilEnd days"
    }
    val kind = if (daysUntilEnd != null && daysUntilEnd <= 7L) PillKind.Danger else PillKind.Warn
    return text to kind
}
