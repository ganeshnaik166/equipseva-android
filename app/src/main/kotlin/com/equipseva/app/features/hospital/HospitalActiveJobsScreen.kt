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
import androidx.compose.material3.Surface
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.ErrorBanner
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.components.SectionHeader
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.features.hospital.components.HospitalBrowseEngineersTile
import com.equipseva.app.features.hospital.components.HospitalHowItWorksStrip
import com.equipseva.app.features.hospital.components.HospitalRepairHeroCard
import com.equipseva.app.features.repair.components.RepairJobCard

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

    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            val total = state.openJobs.size + state.inProgressJobs.size + state.closedJobs.size
            EsTopBar(
                title = "My repair jobs",
                subtitle = if (total > 0) "$total total" else null,
                onBack = onBack,
            )
            ErrorBanner(message = state.errorMessage)
            PullToRefreshBox(
                isRefreshing = state.refreshing,
                onRefresh = viewModel::onRefresh,
                modifier = Modifier.fillMaxSize(),
            ) {
                when {
                    state.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator()
                    }
                    else -> LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(vertical = 12.dp),
                        verticalArrangement = Arrangement.spacedBy(10.dp),
                    ) {
                        // Hero card stays visible whether the lists are full
                        // or empty — gives the hospital one-tap access to
                        // post a job + browse engineers without scrolling.
                        item("hero") {
                            HospitalRepairHeroCard(
                                openCount = state.openJobs.size,
                                inProgressCount = state.inProgressJobs.size,
                                completedCount = state.closedJobs.size,
                                onRequestRepair = onRequestRepair,
                                onBrowseEngineers = onBrowseEngineers,
                            )
                        }

                        val anyJobs = state.openJobs.isNotEmpty() ||
                            state.inProgressJobs.isNotEmpty() ||
                            state.closedJobs.isNotEmpty()

                        if (!anyJobs) {
                            // First-time hospital — fill the space with
                            // education + a discovery shortcut so the screen
                            // never goes blank under the hero.
                            item("how_it_works") { HospitalHowItWorksStrip() }
                            item("browse_engineers_tile") {
                                HospitalBrowseEngineersTile(onClick = onBrowseEngineers)
                            }
                            item("empty_pad") {
                                EmptyStateView(
                                    icon = Icons.AutoMirrored.Outlined.Assignment,
                                    title = "No repair jobs yet",
                                    subtitle = "Tap Request repair above to post your first one.",
                                )
                            }
                        }

                        if (state.openJobs.isNotEmpty()) {
                            item("open_header") { SectionHeader(title = "Open · awaiting bids") }
                            items(items = state.openJobs, key = { "o-${it.id}" }) { job ->
                                RepairJobCard(
                                    job = job,
                                    onClick = { onJobClick(job.id) },
                                    modifier = Modifier.padding(horizontal = 16.dp),
                                )
                            }
                        }
                        if (state.inProgressJobs.isNotEmpty()) {
                            item("inprogress_header") { SectionHeader(title = "In progress") }
                            items(items = state.inProgressJobs, key = { "p-${it.id}" }) { job ->
                                RepairJobCard(
                                    job = job,
                                    onClick = { onJobClick(job.id) },
                                    modifier = Modifier.padding(horizontal = 16.dp),
                                )
                            }
                        }
                        if (state.closedJobs.isNotEmpty()) {
                            item("closed_header") { SectionHeader(title = "Closed") }
                            items(items = state.closedJobs, key = { "c-${it.id}" }) { job ->
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
