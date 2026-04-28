package com.equipseva.app.features.activework

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.background
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.CloudSync
import androidx.compose.material.icons.outlined.Handyman
import androidx.compose.material3.CircularProgressIndicator
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
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.ErrorBanner
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.components.ListSkeleton
import com.equipseva.app.designsystem.components.SectionHeader
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaGreen50
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaInk900
import com.equipseva.app.features.repair.components.RepairJobCard

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ActiveWorkScreen(
    onBack: () -> Unit,
    onJobClick: (String) -> Unit,
    viewModel: ActiveWorkViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            val total = state.activeJobs.size + state.completedJobs.size
            EsTopBar(
                title = "Active work",
                subtitle = if (total > 0) "$total jobs in progress" else null,
                onBack = onBack,
            )
            ErrorBanner(message = state.errorMessage)
            QueuedStatusPill(count = state.queuedStatusCount)
            PullToRefreshBox(
                isRefreshing = state.refreshing,
                onRefresh = viewModel::onRefresh,
                modifier = Modifier.fillMaxSize(),
            ) {
                when {
                    state.loading -> ListSkeleton(rows = 6)
                    state.activeJobs.isEmpty() && state.completedJobs.isEmpty() -> EmptyStateView(
                        icon = Icons.Outlined.Handyman,
                        title = "No assigned jobs",
                        subtitle = "Jobs you win from the feed will show up here.",
                    )
                    else -> LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(vertical = 12.dp),
                        verticalArrangement = Arrangement.spacedBy(10.dp),
                    ) {
                        if (state.activeJobs.isNotEmpty()) {
                            item("active_header") { SectionHeader(title = "In progress") }
                            items(items = state.activeJobs, key = { "a-${it.id}" }) { job ->
                                RepairJobCard(
                                    job = job,
                                    onClick = { onJobClick(job.id) },
                                    modifier = Modifier.padding(horizontal = 16.dp),
                                )
                            }
                        }
                        if (state.completedJobs.isNotEmpty()) {
                            item("completed_header") { SectionHeader(title = "Recently completed") }
                            items(items = state.completedJobs, key = { "c-${it.id}" }) { job ->
                                RepairJobCard(
                                    job = job,
                                    onClick = { onJobClick(job.id) },
                                    modifier = Modifier.padding(horizontal = 16.dp),
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
private fun QueuedStatusPill(count: Int) {
    if (count <= 0) return
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 4.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(SevaGreen50)
            .padding(horizontal = 12.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Icon(
            imageVector = Icons.Outlined.CloudSync,
            contentDescription = null,
            tint = SevaGreen700,
            modifier = Modifier.size(16.dp),
        )
        Text(
            text = if (count == 1) "1 status change queued — will sync when back online"
            else "$count status changes queued — will sync when back online",
            style = EsType.Caption,
            color = SevaInk900,
        )
    }
}
