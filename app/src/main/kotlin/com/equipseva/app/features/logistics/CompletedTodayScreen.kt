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
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.outlined.TaskAlt
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.ErrorBanner
import com.equipseva.app.designsystem.components.SectionHeader
import com.equipseva.app.designsystem.theme.Spacing

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CompletedTodayScreen(
    onBack: () -> Unit,
    viewModel: CompletedTodayViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Completed") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
            )
        },
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
                    state.noPartnerWarning -> EmptyStateView(
                        icon = Icons.Outlined.TaskAlt,
                        title = "Logistics partner not registered",
                        subtitle = "Completed jobs will appear after you're registered.",
                    )
                    state.completedToday.isEmpty() && state.earlierCompleted.isEmpty() -> EmptyStateView(
                        icon = Icons.Outlined.TaskAlt,
                        title = "No completed jobs yet",
                        subtitle = "Your delivery history will show up here.",
                    )
                    else -> LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(vertical = Spacing.md),
                        verticalArrangement = Arrangement.spacedBy(Spacing.sm),
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
