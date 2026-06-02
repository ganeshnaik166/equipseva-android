package com.equipseva.app.features.hospital

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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.Assignment
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.CalendarMonth
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.core.data.repair.RepairJob
import com.equipseva.app.core.data.repair.RepairJobUrgency
import com.equipseva.app.core.util.relativeLabel
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.ErrorBanner
import com.equipseva.app.designsystem.components.EsBtn
import com.equipseva.app.designsystem.components.EsBtnKind
import com.equipseva.app.designsystem.components.EsBtnSize
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.components.StatusPill
import com.equipseva.app.designsystem.components.UrgencyPill
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.Paper2
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk600
import com.equipseva.app.designsystem.theme.SevaInk700
import com.equipseva.app.designsystem.theme.SevaInk900

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HospitalActiveJobsScreen(
    onBack: () -> Unit,
    onJobClick: (String) -> Unit,
    onRequestRepair: () -> Unit = {},
    viewModel: HospitalActiveJobsViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    // Picks up cancelled / state-changed jobs the moment the user
    // returns from the detail screen. First ON_RESUME skipped because
    // the VM's init {} already loaded.
    com.equipseva.app.designsystem.util.RefreshOnReturn { viewModel.onRefresh() }

    val totalCount = state.openJobs.size + state.inProgressJobs.size + state.closedJobs.size
    val openCount = state.openJobs.size
    val activeCount = state.inProgressJobs.size
    val closedCount = state.closedJobs.size

    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(title = "My repair jobs", onBack = onBack)

            FilterChipsRow(
                selected = state.filter,
                allCount = totalCount,
                openCount = openCount,
                activeCount = activeCount,
                closedCount = closedCount,
                onSelect = viewModel::onFilterChange,
            )

            ErrorBanner(message = state.errorMessage)

            PullToRefreshBox(
                isRefreshing = state.refreshing,
                onRefresh = viewModel::onRefresh,
                modifier = Modifier.weight(1f).fillMaxWidth(),
            ) {
                when {
                    state.loading -> Box(
                        Modifier.fillMaxSize(),
                        contentAlignment = Alignment.Center,
                    ) { CircularProgressIndicator() }

                    state.visibleJobs.isEmpty() -> {
                        // Filter-aware empty copy. The default "Tap Post new
                        // job below" advice is right when the hospital
                        // genuinely has no jobs (All filter + zero total) —
                        // but if they're filtering by Closed and just
                        // haven't finished any yet, posting another job
                        // doesn't help. Tell them what the empty state
                        // actually means under the active filter.
                        val (emptyTitle, emptySubtitle) = hospitalActiveJobsEmptyCopy(state.filter)
                        EmptyStateView(
                            icon = Icons.AutoMirrored.Outlined.Assignment,
                            title = emptyTitle,
                            subtitle = emptySubtitle,
                        )
                    }

                    else -> LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 12.dp),
                        verticalArrangement = Arrangement.spacedBy(10.dp),
                    ) {
                        items(items = state.visibleJobs, key = { it.id }) { job ->
                            HospitalBookingCard(
                                job = job,
                                onClick = { onJobClick(job.id) },
                            )
                        }
                    }
                }
            }

            // Bottom CTA — full-width, sticky-feeling because it sits below
            // the scrollable list and above the bottom nav.
            Box(modifier = Modifier.fillMaxWidth().padding(16.dp)) {
                EsBtn(
                    text = "Post new job",
                    onClick = onRequestRepair,
                    kind = EsBtnKind.Primary,
                    size = EsBtnSize.Lg,
                    full = true,
                    leading = {
                        Icon(
                            Icons.Outlined.Add,
                            contentDescription = null,
                            tint = Color.White,
                            modifier = Modifier.size(18.dp),
                        )
                    },
                )
            }
        }
    }
}

@Composable
private fun FilterChipsRow(
    selected: HospitalActiveJobsViewModel.Filter,
    allCount: Int,
    openCount: Int,
    activeCount: Int,
    closedCount: Int,
    onSelect: (HospitalActiveJobsViewModel.Filter) -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .horizontalScroll(rememberScrollState())
            .padding(horizontal = 16.dp, vertical = 12.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        FilterChip(
            label = "All ($allCount)",
            active = selected == HospitalActiveJobsViewModel.Filter.All,
            onClick = { onSelect(HospitalActiveJobsViewModel.Filter.All) },
        )
        FilterChip(
            label = "Open ($openCount)",
            active = selected == HospitalActiveJobsViewModel.Filter.Open,
            onClick = { onSelect(HospitalActiveJobsViewModel.Filter.Open) },
        )
        FilterChip(
            label = "Active ($activeCount)",
            active = selected == HospitalActiveJobsViewModel.Filter.Active,
            onClick = { onSelect(HospitalActiveJobsViewModel.Filter.Active) },
        )
        FilterChip(
            label = "Closed ($closedCount)",
            active = selected == HospitalActiveJobsViewModel.Filter.Closed,
            onClick = { onSelect(HospitalActiveJobsViewModel.Filter.Closed) },
        )
    }
}

@Composable
private fun FilterChip(
    label: String,
    active: Boolean,
    onClick: () -> Unit,
) {
    val shape = RoundedCornerShape(999.dp)
    Box(
        modifier = Modifier
            .clip(shape)
            .background(if (active) SevaGreen700 else Color.White)
            .border(1.dp, if (active) SevaGreen700 else BorderDefault, shape)
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 8.dp),
    ) {
        Text(
            text = label,
            style = EsType.BodySm.copy(fontWeight = FontWeight.SemiBold),
            color = if (active) Color.White else SevaInk700,
        )
    }
}

@Composable
private fun HospitalBookingCard(
    job: RepairJob,
    onClick: () -> Unit,
) {
    val shape = RoundedCornerShape(12.dp)
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(shape)
            .background(Color.White)
            .border(1.dp, BorderDefault, shape)
            .clickable(onClick = onClick)
            .padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.Top,
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = job.equipmentLabel,
                    style = EsType.Body.copy(
                        fontWeight = FontWeight.Bold,
                        fontSize = 16.sp,
                    ),
                    color = SevaInk900,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                if (!job.siteLocation.isNullOrBlank()) {
                    Spacer(Modifier.height(2.dp))
                    Text(
                        text = job.siteLocation!!,
                        style = EsType.Caption,
                        color = SevaInk500,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }
            Column(
                horizontalAlignment = Alignment.End,
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                StatusPill(status = job.status)
                if (job.urgency == RepairJobUrgency.Emergency ||
                    job.urgency == RepairJobUrgency.SameDay
                ) {
                    UrgencyPill(urgency = job.urgency)
                }
            }
        }

        // Terminal-state subtitle — when the job is Cancelled (with a
        // reason) or Disputed, the StatusPill alone is a dead-end.
        // Surface the explanation inline so a hospital scrolling the
        // Closed list can tell "engineer self-repaired" from "service
        // area dispute" without opening the detail screen.
        val terminal = com.equipseva.app.features.repair.terminalStatusBannerCopy(
            status = job.status,
            cancellationReason = job.cancellationReason,
        )
        if (terminal != null) {
            Text(
                text = terminal.subtitle,
                style = EsType.Caption,
                color = SevaInk600,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
        }

        if (job.issueDescription.isNotBlank()) {
            Text(
                text = job.issueDescription,
                style = EsType.BodySm,
                color = SevaInk700,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
        }

        HorizontalDivider(color = Paper2, thickness = 1.dp)

        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            val schedule = hospitalBookingScheduleLine(job.scheduledDate, job.scheduledTimeSlot)
            // Schedule first if hospital picked one; else fall back to a
            // relative posted-at. If neither is available the whole left
            // section is hidden — earlier "—" placeholder read as a broken
            // metric, not as "data not applicable".
            val leftLabel: String? = hospitalBookingLeftLabel(
                schedule = schedule,
                postedRelative = job.createdAtInstant?.let { relativeLabel(it) },
            )
            if (leftLabel != null) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    Icon(
                        imageVector = Icons.Outlined.CalendarMonth,
                        contentDescription = null,
                        tint = SevaInk500,
                        modifier = Modifier.size(14.dp),
                    )
                    Text(
                        text = leftLabel,
                        style = EsType.Caption,
                        color = SevaInk500,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }
            Spacer(Modifier.weight(1f))
            // Only surface the relative posted-time on the right when the
            // left side is showing a real schedule — otherwise both columns
            // would print the same "1d ago" twice.
            if (hospitalBookingShouldShowPostedOnRight(schedule)) {
                job.createdAtInstant?.let { posted ->
                    Text(
                        text = "${relativeLabel(posted)} ago",
                        style = EsType.Caption,
                        color = SevaInk500,
                    )
                }
            }
        }
    }
}

/**
 * Schedule line on the hospital's active-job card.
 *
 * Composes the optional scheduledDate + scheduledTimeSlot into a
 * comma-separated string. Either or both null → returns blank.
 *
 * Pin the comma+space separator (not " · ", not " at ") — load-bearing
 * because the caller checks `isNotBlank()` and a refactor that always
 * produced a non-blank string (e.g. inserting "—" between fields)
 * would silently flip the empty-schedule fallback path.
 */
internal fun hospitalBookingScheduleLine(
    scheduledDate: String?,
    scheduledTimeSlot: String?,
): String =
    listOfNotNull(scheduledDate, scheduledTimeSlot).joinToString(", ")

/**
 * Left-side label on the hospital's active-job card.
 *
 * Decision tree:
 *   1. schedule non-blank → render it verbatim.
 *   2. schedule blank but postedRelative present → "Posted ${rel} ago".
 *   3. both empty → null (caller hides the entire row to avoid the
 *      earlier "—" placeholder reading as a broken metric).
 *
 * Pin the literal "Posted " prefix and " ago" suffix — these wrap the
 * relative label which is a bare quantity ("1d", "3h"). A refactor
 * that returned just the relative label would read as a timestamp
 * column rather than the post-time it actually is.
 */
internal fun hospitalBookingLeftLabel(
    schedule: String,
    postedRelative: String?,
): String? = schedule.takeIf { it.isNotBlank() }
    ?: postedRelative?.let { "Posted $it ago" }

/**
 * Right-column gate on the hospital's active-job card. Returns true
 * only when the left side is showing a real schedule — preventing the
 * "1d ago" relative timestamp from being printed on both columns when
 * the left fell back to "Posted Nd ago".
 *
 * Pin so a refactor that allowed both columns to fire would surface
 * here as a deliberate change rather than slip in.
 */
internal fun hospitalBookingShouldShowPostedOnRight(schedule: String): Boolean =
    schedule.isNotBlank()

/**
 * Filter-aware empty-state copy on the hospital active-jobs screen.
 *
 * Each filter gets its own (title, subtitle) pair:
 *   - All → generic "Tap Post new job below" CTA prompt (the hospital
 *     genuinely has nothing)
 *   - Open → "No open jobs" + the explanation of what the Open tab
 *     surfaces (so the user understands the filter intent)
 *   - Active → "No jobs in progress" + engineer-acceptance explanation
 *   - Closed → "No closed jobs yet" + finished/cancelled/disputed
 *     bucket explanation
 *
 * Critical pin: the All branch is the ONLY one with the "Post new job
 * below" CTA. A refactor that surfaced that CTA on the Closed branch
 * would suggest posting another job fixes the empty-closed state
 * (which it doesn't — Closed is empty because nothing has been
 * finished yet, not because nothing has been posted).
 *
 * Pin each filter's explanation copy — these are the user's mental
 * model of what each tab contains. A refactor that swapped any pair
 * would mismatch the explanation to the filter.
 */
internal fun hospitalActiveJobsEmptyCopy(
    filter: HospitalActiveJobsViewModel.Filter,
): Pair<String, String> = when (filter) {
    HospitalActiveJobsViewModel.Filter.All ->
        "No repair jobs yet" to "Tap Post new job below to create one."
    HospitalActiveJobsViewModel.Filter.Open ->
        "No open jobs" to "Jobs you post and haven't assigned yet appear here."
    HospitalActiveJobsViewModel.Filter.Active ->
        "No jobs in progress" to "Jobs an engineer has accepted appear here."
    HospitalActiveJobsViewModel.Filter.Closed ->
        "No closed jobs yet" to "Finished, cancelled, or disputed jobs land here."
}
