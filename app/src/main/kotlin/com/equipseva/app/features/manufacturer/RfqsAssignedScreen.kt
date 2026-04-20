package com.equipseva.app.features.manufacturer

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
import androidx.compose.material.icons.outlined.RequestQuote
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
import com.equipseva.app.designsystem.components.ESBackTopBar
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.ErrorBanner
import com.equipseva.app.designsystem.components.SectionHeader
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.features.supplier.RfqListCard

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RfqsAssignedScreen(
    onBack: () -> Unit,
    viewModel: RfqsAssignedViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    Scaffold(
        topBar = { ESBackTopBar(title = "Matched RFQs", onBack = onBack) },
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
                        icon = Icons.Outlined.RequestQuote,
                        title = "Manufacturer not linked",
                        subtitle = "Link your account to a manufacturer organization.",
                    )
                    state.targeted.isEmpty() && state.other.isEmpty() -> EmptyStateView(
                        icon = Icons.Outlined.RequestQuote,
                        title = "No open RFQs",
                        subtitle = "New equipment inquiries will appear here.",
                    )
                    else -> LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(vertical = Spacing.md),
                        verticalArrangement = Arrangement.spacedBy(Spacing.sm),
                    ) {
                        if (state.targeted.isNotEmpty()) {
                            item("targeted_header") { SectionHeader(title = "Matches your categories") }
                            items(items = state.targeted, key = { "t-${it.id}" }) { rfq ->
                                Box(modifier = Modifier.padding(horizontal = Spacing.lg)) {
                                    RfqListCard(rfq = rfq)
                                }
                            }
                        }
                        if (state.other.isNotEmpty()) {
                            item("other_header") { SectionHeader(title = "Other open RFQs") }
                            items(items = state.other, key = { "o-${it.id}" }) { rfq ->
                                Box(modifier = Modifier.padding(horizontal = Spacing.lg)) {
                                    RfqListCard(rfq = rfq)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
