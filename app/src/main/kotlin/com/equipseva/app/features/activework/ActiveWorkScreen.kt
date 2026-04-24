package com.equipseva.app.features.activework

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.CheckCircle
import androidx.compose.material.icons.outlined.CloudSync
import androidx.compose.material.icons.outlined.Directions
import androidx.compose.material.icons.outlined.Handyman
import androidx.compose.material.icons.outlined.Login
import androidx.compose.material.icons.outlined.PhotoCamera
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.core.data.repair.RepairJob
import com.equipseva.app.core.data.repair.RepairJobStatus
import com.equipseva.app.designsystem.components.ESBackTopBar
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.ErrorBanner
import com.equipseva.app.designsystem.components.SectionHeader
import com.equipseva.app.designsystem.theme.BrandGreen
import com.equipseva.app.designsystem.theme.BrandGreen50
import com.equipseva.app.designsystem.theme.BrandGreenDark
import com.equipseva.app.designsystem.theme.Ink500
import com.equipseva.app.designsystem.theme.Ink900
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.designsystem.theme.Surface50
import com.equipseva.app.features.repair.components.RepairJobCard

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ActiveWorkScreen(
    onBack: () -> Unit,
    onJobClick: (String) -> Unit,
    viewModel: ActiveWorkViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val totalJobs = state.activeJobs.size + state.completedJobs.size

    Scaffold(
        topBar = { ESBackTopBar(title = "Active work", onBack = onBack) },
        containerColor = Surface50,
    ) { inner ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(inner),
        ) {
            if (totalJobs > 0 && !state.loading) {
                Text(
                    text = if (totalJobs == 1) "1 job scheduled" else "$totalJobs jobs scheduled",
                    fontSize = 13.sp,
                    color = Ink500,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = Spacing.lg, vertical = Spacing.xs),
                )
            }
            ErrorBanner(
                message = state.errorMessage,
                modifier = Modifier.padding(horizontal = Spacing.lg),
            )
            QueuedStatusPill(count = state.queuedStatusCount)
            PullToRefreshBox(
                isRefreshing = state.refreshing,
                onRefresh = viewModel::onRefresh,
                modifier = Modifier.fillMaxSize(),
            ) {
                when {
                    state.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator()
                    }
                    state.activeJobs.isEmpty() && state.completedJobs.isEmpty() -> EmptyStateView(
                        icon = Icons.Outlined.Handyman,
                        title = "No assigned jobs",
                        subtitle = "Jobs you win from the feed will show up here.",
                    )
                    else -> LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(vertical = Spacing.sm),
                        verticalArrangement = Arrangement.spacedBy(Spacing.sm),
                    ) {
                        if (state.activeJobs.isNotEmpty()) {
                            item("active_header") { SectionHeader(title = "In progress") }
                            items(items = state.activeJobs, key = { "a-${it.id}" }) { job ->
                                ActiveJobItem(
                                    job = job,
                                    onJobClick = { onJobClick(job.id) },
                                )
                            }
                        }
                        if (state.completedJobs.isNotEmpty()) {
                            item("completed_header") { SectionHeader(title = "Recently completed") }
                            items(items = state.completedJobs, key = { "c-${it.id}" }) { job ->
                                ActiveJobItem(
                                    job = job,
                                    onJobClick = { onJobClick(job.id) },
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun ActiveJobItem(
    job: RepairJob,
    onJobClick: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = Spacing.lg),
        verticalArrangement = Arrangement.spacedBy(Spacing.sm),
    ) {
        RepairJobCard(
            job = job,
            onClick = onJobClick,
        )
        val actions = actionsForStatus(job.status)
        if (actions.isNotEmpty()) {
            ActionChipRow(actions = actions)
        }
    }
}

private data class JobAction(val label: String, val icon: ImageVector)

private fun actionsForStatus(status: RepairJobStatus): List<JobAction> = when (status) {
    RepairJobStatus.Assigned -> listOf(
        JobAction("Check in", Icons.Outlined.Login),
        JobAction("Navigate", Icons.Outlined.Directions),
    )
    RepairJobStatus.EnRoute -> listOf(
        JobAction("Check in", Icons.Outlined.Login),
        JobAction("Navigate", Icons.Outlined.Directions),
    )
    RepairJobStatus.InProgress -> listOf(
        JobAction("Mark done", Icons.Outlined.CheckCircle),
        JobAction("Upload photo", Icons.Outlined.PhotoCamera),
    )
    else -> emptyList()
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun ActionChipRow(actions: List<JobAction>) {
    FlowRow(
        modifier = Modifier
            .fillMaxWidth()
            .padding(start = 64.dp),
        horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
        verticalArrangement = Arrangement.spacedBy(Spacing.xs),
    ) {
        actions.forEach { action ->
            BrandActionChip(label = action.label, icon = action.icon, onClick = {})
        }
    }
}

@Composable
private fun BrandActionChip(
    label: String,
    icon: ImageVector,
    onClick: () -> Unit,
) {
    Row(
        modifier = Modifier
            .clip(RoundedCornerShape(percent = 50))
            .background(BrandGreen50)
            .clickable(onClick = onClick)
            .padding(horizontal = 12.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = BrandGreenDark,
            modifier = Modifier.size(14.dp),
        )
        Text(
            text = label,
            fontSize = 12.sp,
            fontWeight = FontWeight.SemiBold,
            color = BrandGreenDark,
        )
    }
}

@Composable
private fun QueuedStatusPill(count: Int) {
    if (count <= 0) return
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = Spacing.lg, vertical = Spacing.xs)
            .clip(MaterialTheme.shapes.small)
            .background(BrandGreen50)
            .padding(horizontal = 12.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Icon(
            imageVector = Icons.Outlined.CloudSync,
            contentDescription = null,
            tint = BrandGreen,
            modifier = Modifier.size(16.dp),
        )
        Text(
            text = if (count == 1) "1 status change queued — will sync when back online"
            else "$count status changes queued — will sync when back online",
            style = MaterialTheme.typography.bodySmall,
            color = Ink900,
        )
    }
}
