package com.equipseva.app.features.hospital

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.RequestQuote
import androidx.compose.material.icons.outlined.Warning
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
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.features.supplier.RfqListCard

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HospitalMyRfqsScreen(
    onBack: () -> Unit,
    onRfqClick: (String) -> Unit = {},
    viewModel: HospitalMyRfqsViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    Scaffold(
        topBar = { ESBackTopBar(title = "My RFQs", onBack = onBack) },
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
                    state.noOrgWarning -> EmptyStateView(
                        icon = Icons.Outlined.Warning,
                        title = "Organization not linked",
                        subtitle = "Ask your admin to link your account to a hospital organization.",
                    )
                    state.rfqs.isEmpty() -> EmptyStateView(
                        icon = Icons.Outlined.RequestQuote,
                        title = "No RFQs yet",
                        subtitle = "RFQs you post for bulk equipment will appear here.",
                    )
                    else -> LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(horizontal = Spacing.lg, vertical = Spacing.md),
                        verticalArrangement = Arrangement.spacedBy(Spacing.md),
                    ) {
                        items(items = state.rfqs, key = { it.id }) { rfq ->
                            Box(modifier = Modifier.clickable { onRfqClick(rfq.id) }) {
                                RfqListCard(rfq = rfq)
                            }
                        }
                    }
                }
            }
        }
    }
}
