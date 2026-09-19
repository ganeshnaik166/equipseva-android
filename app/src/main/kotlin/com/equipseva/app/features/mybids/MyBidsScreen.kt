package com.equipseva.app.features.mybids

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.CloudSync
import androidx.compose.material.icons.outlined.Gavel
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.R
import com.equipseva.app.core.data.repair.RepairBidStatus
import com.equipseva.app.core.util.formatRupees
import com.equipseva.app.core.util.relativeLabel
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.ErrorBanner
import com.equipseva.app.designsystem.components.EsChip
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.components.ListSkeleton
import com.equipseva.app.designsystem.components.Pill
import com.equipseva.app.designsystem.components.PillKind
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.EsRadius
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaGreen50
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaInk400
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk900
import com.equipseva.app.designsystem.theme.Spacing

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MyBidsScreen(
    onBack: () -> Unit,
    onJobClick: (String) -> Unit,
    onBrowseJobs: () -> Unit = {},
    // round3773 — "check profitability before you accept" (any bid
    // status; profitability_for_repair_bid is auth.uid()-scoped to the
    // bidding engineer regardless of accept state).
    onCheckProfitability: (bidId: String) -> Unit = {},
    // round3774 — "preview payout" (accepted bids only; the RPC blocks
    // pre-bid tier-shopping by requiring the caller be the assigned
    // engineer on the job).
    onPreviewPayout: (repairJobId: String) -> Unit = {},
    viewModel: MyBidsViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    // Re-fetch on every ON_RESUME so a status change in the detail screen
    // (e.g., an accepted bid that flips status server-side) reflects when
    // the user pops back to this list.
    val lifecycleOwner = androidx.lifecycle.compose.LocalLifecycleOwner.current
    androidx.compose.runtime.DisposableEffect(lifecycleOwner) {
        val observer = androidx.lifecycle.LifecycleEventObserver { _, event ->
            if (event == androidx.lifecycle.Lifecycle.Event.ON_RESUME) viewModel.onRefresh()
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }
    MyBidsContent(
        state = state,
        onRefresh = viewModel::onRefresh,
        onStatusFilterChange = viewModel::onStatusFilterChange,
        onBack = onBack,
        onJobClick = onJobClick,
        onBrowseJobs = onBrowseJobs,
        onCheckProfitability = onCheckProfitability,
        onPreviewPayout = onPreviewPayout,
    )
}

/**
 * Stateless body of the My-Bids screen. Kept ViewModel-free so screenshot
 * fixtures and previews can pin each visual state without Hilt or a
 * lifecycle owner.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun MyBidsContent(
    state: MyBidsViewModel.UiState,
    onRefresh: () -> Unit,
    onStatusFilterChange: (RepairBidStatus) -> Unit,
    onBack: () -> Unit,
    onJobClick: (String) -> Unit,
    onBrowseJobs: () -> Unit = {},
    onCheckProfitability: (bidId: String) -> Unit = {},
    onPreviewPayout: (repairJobId: String) -> Unit = {},
    modifier: Modifier = Modifier,
) {
    val activeFilter = state.statusFilter ?: RepairBidStatus.Pending
    Surface(modifier = modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(title = "My bids", onBack = onBack)
            ErrorBanner(message = state.errorMessage)
            QueuedBidPill(count = state.queuedBidCount)

            val groups = remember(state.rows) {
                MY_BIDS_TAB_STATUSES.map { status ->
                    status to state.rows.count { it.bid.status == status }
                }
            }
            Row(
                // Scrollable: four labelled-and-counted chips no longer fit a
                // narrow screen, and a clipped tab is an unreachable tab.
                modifier = Modifier
                    .fillMaxWidth()
                    .horizontalScroll(rememberScrollState())
                    .padding(horizontal = Spacing.lg, vertical = Spacing.sm),
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                groups.forEach { (status, count) ->
                    EsChip(
                        text = "${status.displayName} ($count)",
                        active = activeFilter == status,
                        onClick = { onStatusFilterChange(status) },
                    )
                }
            }

            PullToRefreshBox(
                isRefreshing = state.refreshing,
                onRefresh = onRefresh,
                modifier = Modifier.fillMaxSize(),
            ) {
                // Round 442 — memoize the filtered list so the walk doesn't
                // re-fire on every PTR / list-scroll recomposition. Keyed
                // on rows + activeFilter so the cache invalidates exactly
                // when either changes. Mirror of the r434 pattern.
                val visibleRows = remember(state.rows, activeFilter) {
                    state.rows.filter { it.bid.status == activeFilter }
                }
                when {
                    state.loading && state.rows.isEmpty() -> ListSkeleton(rows = 8)
                    visibleRows.isEmpty() -> EmptyStateView(
                        icon = Icons.Outlined.Gavel,
                        title = myBidsEmptyTitle(activeFilter),
                        subtitle = myBidsEmptySubtitle(activeFilter),
                        ctaLabel = myBidsEmptyCtaLabel(activeFilter),
                        onCta = if (activeFilter == RepairBidStatus.Pending) onBrowseJobs else null,
                    )
                    else -> LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(horizontal = Spacing.lg, vertical = Spacing.sm),
                        verticalArrangement = Arrangement.spacedBy(10.dp),
                    ) {
                        items(items = visibleRows, key = { it.bid.id }) { row ->
                            BidRowCard(
                                row = row,
                                onClick = { onJobClick(row.bid.repairJobId) },
                                onCheckProfitability = { onCheckProfitability(row.bid.id) },
                                onPreviewPayout = { onPreviewPayout(row.bid.repairJobId) },
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun BidRowCard(
    row: MyBidsViewModel.MyBidRow,
    onClick: () -> Unit,
    onCheckProfitability: () -> Unit = {},
    onPreviewPayout: () -> Unit = {},
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(EsRadius.Lg))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(EsRadius.Lg))
            .clickable(onClick = onClick)
            .padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(Spacing.sm),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.Top,
            horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
        ) {
            Text(
                text = bidRowEquipmentTitle(row.job?.equipmentLabel, row.job?.title),
                style = EsType.Body.copy(fontWeight = FontWeight.SemiBold),
                color = SevaInk900,
                modifier = Modifier.weight(1f),
            )
            Pill(text = row.bid.status.displayName, kind = bidStatusPillKind(row.bid.status))
        }
        row.job?.siteLocation?.takeIf { it.isNotBlank() }?.let {
            Text(
                text = it,
                style = EsType.Caption,
                color = SevaInk500,
            )
        }
        Box(modifier = Modifier.fillMaxWidth().height(1.dp).background(BorderDefault))
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text(
                // Round 3760 — repair_job_bids.amount_rupees can be null
                // on a legacy/anomalous row.
                text = row.bid.amountRupees?.let { formatRupees(it) } ?: "—",
                style = EsType.H5,
                color = SevaGreen700,
            )
            row.bid.createdAtInstant?.let { placed ->
                // r1457 — relativeLabel() returns the standalone "now" for
                // <1min elapsed; "Placed now ago" reads broken, so special-case it.
                val rel = relativeLabel(placed)
                Text(
                    text = if (rel == "now") {
                        stringResource(R.string.mybids_row_placed_just_now)
                    } else {
                        stringResource(R.string.mybids_row_placed_ago, rel)
                    },
                    style = EsType.Caption,
                    color = SevaInk400,
                )
            }
        }
        // round3773/3774 — small link-style affordances into the two
        // dormant-RPC payout-preview screens. Profitability check works
        // for any bid status; the tier-based payout preview requires
        // the caller to be the assigned engineer, so it's Accepted-only.
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(Spacing.lg),
        ) {
            BidLinkAction(
                text = stringResource(R.string.mybids_check_profitability),
                onClick = onCheckProfitability,
            )
            if (row.bid.status == RepairBidStatus.Accepted) {
                BidLinkAction(
                    text = stringResource(R.string.mybids_preview_payout),
                    onClick = onPreviewPayout,
                )
            }
        }
    }
}

@Composable
private fun BidLinkAction(text: String, onClick: () -> Unit) {
    // A caption-sized Text with a bare clickable gave a ~20dp-tall target
    // with no button role — the 48dp floor and Role.Button come from the
    // wrapper, while the label keeps its inline link look.
    Box(
        modifier = Modifier
            .heightIn(min = Spacing.MinTouchTarget)
            .clip(RoundedCornerShape(6.dp))
            .clickable(
                onClickLabel = text,
                role = androidx.compose.ui.semantics.Role.Button,
                onClick = onClick,
            )
            .padding(horizontal = Spacing.xs),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = text,
            style = EsType.Caption.copy(fontWeight = FontWeight.SemiBold),
            color = SevaGreen700,
        )
    }
}

@Composable
private fun QueuedBidPill(count: Int) {
    if (count <= 0) return
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = Spacing.lg, vertical = Spacing.xs)
            .clip(RoundedCornerShape(EsRadius.Lg))
            .background(SevaGreen50)
            .padding(horizontal = Spacing.md, vertical = Spacing.sm),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
    ) {
        Icon(
            imageVector = Icons.Outlined.CloudSync,
            contentDescription = null,
            tint = SevaGreen700,
            modifier = Modifier.size(16.dp),
        )
        Text(
            text = queuedBidPillText(count),
            style = EsType.Caption,
            color = SevaInk900,
        )
    }
}

/**
 * Bid-card pill colour for each bid status. Pinned to keep the
 * MyBids list visually consistent with the rest of the app (Accepted
 * = green Success, Rejected = red Danger). Pending and Unknown share
 * Info so an in-flight bid + a legacy row both read as "still
 * resolving".
 */
internal fun bidStatusPillKind(status: RepairBidStatus): PillKind = when (status) {
    RepairBidStatus.Accepted -> PillKind.Success
    RepairBidStatus.Rejected -> PillKind.Danger
    RepairBidStatus.Withdrawn -> PillKind.Neutral
    else -> PillKind.Info
}

/**
 * Title on the engineer's My-Bids row.
 *
 * Multi-fallback chain: equipmentLabel → job title → "Repair job".
 *
 * Pin the chain — equipmentLabel ("Ultrasound machine") is more
 * specific than the hospital's freeform title ("Repair needed
 * urgently") and reads better at-a-glance on the row. A refactor
 * that flipped the order would surface the freeform title on top
 * even when the structured field was populated.
 *
 * Final "Repair job" fallback is generic but tap-targetable — pin
 * so backfill rows with neither field still render an addressable
 * row instead of empty whitespace.
 */
internal fun bidRowEquipmentTitle(
    equipmentLabel: String?,
    jobTitle: String?,
): String = equipmentLabel ?: jobTitle ?: "Repair job"

/**
 * Banner text on the queued-bid pill (offline submit queue).
 *
 * Critical region: singular/plural split AND the U+2014 em-dash
 * separator that visually anchors the explanatory clause.
 *
 *   - count == 1 → "1 bid queued — will submit when back online"
 *   - count != 1 → "N bids queued — will submit when back online"
 *
 * Pin the literal "will submit when back online" — a refactor to
 * "will be sent when online" or similar would change the verb tense
 * + voice and could mislead the engineer about the submit semantics
 * (the queue is fire-and-forget, not store-and-forward with retry).
 */
internal fun queuedBidPillText(count: Int): String =
    if (count == 1) {
        "1 bid queued — will submit when back online"
    } else {
        "$count bids queued — will submit when back online"
    }

/**
 * The tab strip on My bids, in display order.
 *
 * Withdrawn is a real status the engineer creates themselves (the
 * "Withdraw bid" action) and the row card already has a pill kind for
 * it, but it had no tab, no count and no other surface — a bid the
 * engineer pulled simply disappeared from the app, which reads as data
 * loss rather than as a completed action.
 *
 * Unknown is deliberately absent: it is the client's parse fallback for
 * a status literal this build does not know, not a state a server row
 * can be in, and a tab for it would advertise a decoding failure.
 */
internal val MY_BIDS_TAB_STATUSES: List<RepairBidStatus> = listOf(
    RepairBidStatus.Pending,
    RepairBidStatus.Accepted,
    RepairBidStatus.Rejected,
    RepairBidStatus.Withdrawn,
)

/**
 * Empty-state title on the My-Bids screen.
 *
 * "No {filter.displayName lowercase} bids" — e.g. "No pending bids",
 * "No accepted bids".
 *
 * Pin lowercase displayName — flows as a noun inside the sentence
 * "No X bids". A refactor that surfaced the raw Title-cased
 * displayName would read as "No Pending bids" (capital P mid-line).
 */
internal fun myBidsEmptyTitle(filter: RepairBidStatus): String =
    "No ${filter.displayName.lowercase()} bids"

/**
 * Empty-state subtitle on the My-Bids screen.
 *
 * Pending filter gets the action-prompt copy explaining the funnel
 * ("Place a bid on an open repair job and it shows up here.
 * Hospitals usually pick within an hour."). Other filters get the
 * generic tab-switch nudge.
 *
 * Critical pin: the Pending-specific copy includes the "within an
 * hour" expectation-setter — load-bearing trust signal. A refactor
 * that surfaced the generic nudge on Pending would lose the
 * concrete hospital-response cadence.
 */
internal fun myBidsEmptySubtitle(filter: RepairBidStatus): String =
    if (filter == RepairBidStatus.Pending) {
        "Place a bid on an open repair job and it shows up here. Hospitals usually pick within an hour."
    } else {
        "Switch tabs to see other bid states."
    }

/**
 * Empty-state CTA label on the My-Bids screen.
 *
 * Pending → "Browse open jobs"; other filters → null (no CTA).
 *
 * Pin null-on-non-Pending — the other tabs are filter views; a
 * "Browse" CTA there would lead the engineer away from the queue
 * they're looking at without solving the empty problem.
 */
internal fun myBidsEmptyCtaLabel(filter: RepairBidStatus): String? =
    if (filter == RepairBidStatus.Pending) "Browse open jobs" else null
