package com.equipseva.app.features.hospital

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.Assignment
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.core.data.repair.RepairJob
import com.equipseva.app.designsystem.components.ESBackTopBar
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.ErrorBanner
import com.equipseva.app.designsystem.theme.BrandGreen
import com.equipseva.app.designsystem.theme.BrandGreenDark
import com.equipseva.app.designsystem.theme.Ink500
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.designsystem.theme.Surface200
import com.equipseva.app.features.repair.components.RepairJobCard

private enum class HospitalJobsTab(val label: String) {
    Open("Open"),
    InProgress("In progress"),
    Closed("Closed"),
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HospitalActiveJobsScreen(
    onBack: () -> Unit,
    onJobClick: (String) -> Unit,
    viewModel: HospitalActiveJobsViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    var selectedTab by rememberSaveable { mutableStateOf(HospitalJobsTab.Open) }

    val visibleJobs: List<RepairJob> = remember(state.openJobs, state.inProgressJobs, state.closedJobs, selectedTab) {
        when (selectedTab) {
            HospitalJobsTab.Open -> state.openJobs
            HospitalJobsTab.InProgress -> state.inProgressJobs
            HospitalJobsTab.Closed -> state.closedJobs
        }
    }

    Scaffold(
        topBar = { ESBackTopBar(title = "My repair jobs", onBack = onBack) },
    ) { inner ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(inner),
        ) {
            HospitalJobsTabBar(selected = selectedTab, onSelect = { selectedTab = it })
            ErrorBanner(
                message = state.errorMessage,
                modifier = Modifier.padding(horizontal = Spacing.lg),
            )
            PullToRefreshBox(
                isRefreshing = state.refreshing,
                onRefresh = viewModel::onRefresh,
                modifier = Modifier.fillMaxSize(),
            ) {
                when {
                    state.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator()
                    }
                    visibleJobs.isEmpty() -> EmptyStateView(
                        icon = Icons.AutoMirrored.Outlined.Assignment,
                        title = when (selectedTab) {
                            HospitalJobsTab.Open -> "No open jobs"
                            HospitalJobsTab.InProgress -> "No jobs in progress"
                            HospitalJobsTab.Closed -> "No closed jobs"
                        },
                        subtitle = "Jobs you post will appear here so you can track bids and progress.",
                    )
                    else -> LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(vertical = Spacing.md),
                        verticalArrangement = Arrangement.spacedBy(Spacing.sm),
                    ) {
                        items(items = visibleJobs, key = { "${selectedTab.name}-${it.id}" }) { job ->
                            RepairJobCard(
                                job = job,
                                onClick = { onJobClick(job.id) },
                                modifier = Modifier.padding(horizontal = Spacing.lg),
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun HospitalJobsTabBar(
    selected: HospitalJobsTab,
    onSelect: (HospitalJobsTab) -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(MaterialTheme.colorScheme.surface)
            .border(1.dp, Surface200)
            .padding(horizontal = Spacing.lg),
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        HospitalJobsTab.entries.forEach { tab ->
            HospitalTabPill(
                label = tab.label,
                selected = tab == selected,
                onClick = { onSelect(tab) },
            )
        }
    }
}

@Composable
private fun HospitalTabPill(
    label: String,
    selected: Boolean,
    onClick: () -> Unit,
) {
    Column(
        modifier = Modifier
            .clickable(onClick = onClick)
            .padding(horizontal = 12.dp, vertical = 10.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            text = label,
            fontSize = 13.sp,
            fontWeight = FontWeight.SemiBold,
            color = if (selected) BrandGreenDark else Ink500,
        )
        Box(
            modifier = Modifier
                .padding(top = 8.dp)
                .height(2.dp)
                .fillMaxWidth()
                .background(if (selected) BrandGreen else Color.Transparent),
        )
    }
}
