package com.equipseva.app.features.logistics

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.TaskAlt
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
import com.equipseva.app.designsystem.components.StatusBanner
import com.equipseva.app.designsystem.components.StatusBannerTone
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.designsystem.theme.Surface50

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CompletedTodayScreen(
    onBack: () -> Unit,
    viewModel: CompletedTodayViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    Scaffold(
        topBar = { ESBackTopBar(title = "Completed", onBack = onBack) },
        containerColor = Surface50,
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
            if (state.noPartnerWarning) {
                StatusBanner(
                    title = "Logistics partner not registered",
                    message = "Completed jobs will appear after you're registered.",
                    tone = StatusBannerTone.Warn,
                    leadingIcon = Icons.Outlined.TaskAlt,
                    modifier = Modifier.padding(horizontal = Spacing.lg, vertical = Spacing.sm),
                )
            }
            PullToRefreshBox(
                isRefreshing = state.refreshing,
                onRefresh = viewModel::onRefresh,
                modifier = Modifier.fillMaxSize(),
            ) {
                when {
                    state.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator()
                    }
                    state.completedToday.isEmpty() && state.earlierCompleted.isEmpty() && !state.noPartnerWarning -> EmptyStateView(
                        icon = Icons.Outlined.TaskAlt,
                        title = "No completed jobs yet",
                        subtitle = "Your delivery history will show up here.",
                    )
                    state.completedToday.isEmpty() && state.earlierCompleted.isEmpty() -> Box(Modifier)
                    else -> LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(bottom = Spacing.lg),
                        verticalArrangement = Arrangement.spacedBy(Spacing.md),
                    ) {
                        if (state.completedToday.isNotEmpty()) {
                            item("today_header") { SectionHeader(title = "Today") }
                            items(items = state.completedToday, key = { "t-${it.id}" }) { job ->
                                Box(modifier = Modifier.padding(horizontal = Spacing.lg)) {
                                    LogisticsJobCard(job = job)
                                }
                            }
                        }
                        if (state.earlierCompleted.isNotEmpty()) {
                            item("earlier_header") { SectionHeader(title = "Earlier") }
                            items(items = state.earlierCompleted, key = { "e-${it.id}" }) { job ->
                                Box(modifier = Modifier.padding(horizontal = Spacing.lg)) {
                                    LogisticsJobCard(job = job)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
