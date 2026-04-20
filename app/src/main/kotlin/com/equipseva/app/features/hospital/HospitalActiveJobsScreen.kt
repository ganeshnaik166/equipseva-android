package com.equipseva.app.features.hospital

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.Assignment
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Scaffold
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.designsystem.components.ESBackTopBar
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.ErrorBanner
import com.equipseva.app.designsystem.components.SectionHeader
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.features.repair.components.RepairJobCard

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HospitalActiveJobsScreen(
    onBack: () -> Unit,
    onJobClick: (String) -> Unit,
    viewModel: HospitalActiveJobsViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    Scaffold(
        topBar = { ESBackTopBar(title = "My repair jobs", onBack = onBack) },
    ) { inner ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(inner),
        ) {
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
                    state.openJobs.isEmpty() &&
                        state.inProgressJobs.isEmpty() &&
                        state.closedJobs.isEmpty() -> EmptyStateView(
                        icon = Icons.AutoMirrored.Outlined.Assignment,
                        title = "No repair jobs yet",
                        subtitle = "Jobs you post will appear here so you can track bids and progress.",
                    )
                    else -> LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(vertical = Spacing.md),
                        verticalArrangement = Arrangement.spacedBy(Spacing.sm),
                    ) {
                        if (state.openJobs.isNotEmpty()) {
                            item("open_header") { SectionHeader(title = "Open · awaiting bids") }
                            items(items = state.openJobs, key = { "o-${it.id}" }) { job ->
                                RepairJobCard(
                                    job = job,
                                    onClick = { onJobClick(job.id) },
                                    modifier = Modifier.padding(horizontal = Spacing.lg),
                                )
                            }
                        }
                        if (state.inProgressJobs.isNotEmpty()) {
                            item("inprogress_header") { SectionHeader(title = "In progress") }
                            items(items = state.inProgressJobs, key = { "p-${it.id}" }) { job ->
                                RepairJobCard(
                                    job = job,
                                    onClick = { onJobClick(job.id) },
                                    modifier = Modifier.padding(horizontal = Spacing.lg),
                                )
                            }
                        }
                        if (state.closedJobs.isNotEmpty()) {
                            item("closed_header") { SectionHeader(title = "Closed") }
                            items(items = state.closedJobs, key = { "c-${it.id}" }) { job ->
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
}
