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
import com.equipseva.app.core.data.repair.RepairJobStatus
import com.equipseva.app.core.util.relativeLabel
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.ErrorBanner
import com.equipseva.app.designsystem.components.EsBtn
import com.equipseva.app.designsystem.components.EsBtnKind
import com.equipseva.app.designsystem.components.EsBtnSize
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.Paper2
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaDanger50
import com.equipseva.app.designsystem.theme.SevaDanger700
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaInfo50
import com.equipseva.app.designsystem.theme.SevaInfo700
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk700
import com.equipseva.app.designsystem.theme.SevaInk900
import com.equipseva.app.designsystem.theme.SevaSuccess50
import com.equipseva.app.designsystem.theme.SevaSuccess700
import com.equipseva.app.designsystem.theme.SevaWarning50
import com.equipseva.app.designsystem.theme.SevaWarning700

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HospitalActiveJobsScreen(
    onBack: () -> Unit,
    onJobClick: (String) -> Unit,
    onRequestRepair: () -> Unit = {},
    onBrowseEngineers: () -> Unit = {},
    viewModel: HospitalActiveJobsViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    val totalCount = state.openJobs.size + state.inProgressJobs.size + state.closedJobs.size
    val openCount = state.openJobs.size
    val activeCount = state.inProgressJobs.size
    val completedCount = state.closedJobs.count { it.status == RepairJobStatus.Completed }

    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(title = "My repair jobs")

            FilterChipsRow(
                selected = state.filter,
                allCount = totalCount,
                openCount = openCount,
                activeCount = activeCount,
                completedCount = completedCount,
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

                    state.visibleJobs.isEmpty() -> EmptyStateView(
                        icon = Icons.AutoMirrored.Outlined.Assignment,
                        title = "No jobs in this filter",
                        subtitle = "Tap Post new job below to add one.",
                    )

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
    completedCount: Int,
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
            label = "Completed ($completedCount)",
            active = selected == HospitalActiveJobsViewModel.Filter.Completed,
            onClick = { onSelect(HospitalActiveJobsViewModel.Filter.Completed) },
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
            StatusPill(status = job.status)
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
            val schedule = listOfNotNull(job.scheduledDate, job.scheduledTimeSlot)
                .joinToString(", ")
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
                val leftLabel = schedule.ifBlank {
                    job.createdAtInstant?.let { "Posted ${relativeLabel(it)} ago" } ?: "—"
                }
                Text(
                    text = leftLabel,
                    style = EsType.Caption,
                    color = SevaInk500,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            Spacer(Modifier.weight(1f))
            // Only surface the relative posted-time on the right when the
            // left side is showing a real schedule — otherwise both columns
            // would print the same "1d ago" twice.
            if (schedule.isNotBlank()) {
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

@Composable
private fun StatusPill(status: RepairJobStatus) {
    val (bg, fg, label) = when (status) {
        RepairJobStatus.Requested -> Triple(SevaInfo50, SevaInfo700, "Requested")
        RepairJobStatus.Assigned -> Triple(SevaInfo50, SevaInfo700, "Assigned")
        RepairJobStatus.EnRoute -> Triple(SevaWarning50, SevaWarning700, "En route")
        RepairJobStatus.InProgress -> Triple(SevaWarning50, SevaWarning700, "In progress")
        RepairJobStatus.Completed -> Triple(SevaSuccess50, SevaSuccess700, "Completed")
        RepairJobStatus.Cancelled -> Triple(SevaDanger50, SevaDanger700, "Cancelled")
        RepairJobStatus.Disputed -> Triple(SevaDanger50, SevaDanger700, "Disputed")
        RepairJobStatus.Unknown -> Triple(Paper2, SevaInk700, "—")
    }
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(999.dp))
            .background(bg)
            .padding(horizontal = 12.dp, vertical = 6.dp),
    ) {
        Text(
            text = label,
            style = EsType.Caption.copy(fontWeight = FontWeight.SemiBold),
            color = fg,
        )
    }
}
