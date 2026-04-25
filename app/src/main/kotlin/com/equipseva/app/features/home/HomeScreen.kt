package com.equipseva.app.features.home

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material.icons.outlined.Badge
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.designsystem.components.ESTopBar
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.features.auth.UserRole
import com.equipseva.app.features.home.dashboards.EngineerHome
import com.equipseva.app.features.home.dashboards.HospitalHome
import com.equipseva.app.features.home.dashboards.LogisticsHome
import com.equipseva.app.features.home.dashboards.ManufacturerHome
import com.equipseva.app.features.home.dashboards.SupplierHome

/**
 * Top-level Home tab. Dispatches to one of five role-specific dashboard
 * composables based on `state.role`. The dispatcher itself owns no UI shape
 * — every visual decision lives in `features/home/dashboards/`.
 *
 * Role flips are reactive: `HomeViewModel` observes `userPrefs.activeRole`
 * combined with the auth session, so changing the role from the Profile tab
 * re-emits and the dispatcher swaps the rendered dashboard without a
 * navigation event.
 */
@Composable
fun HomeScreen(
    onShowMessage: (String) -> Unit,
    onCardClick: (String) -> Unit = {},
    viewModel: HomeViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    LaunchedEffect(viewModel) {
        viewModel.effects.collect { effect ->
            when (effect) {
                is HomeViewModel.Effect.ShowMessage -> onShowMessage(effect.text)
            }
        }
    }

    Scaffold { inner ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(inner),
        ) {
            when {
                state.loading -> {
                    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator()
                    }
                }
                state.errorMessage != null -> {
                    HomeErrorView(
                        message = state.errorMessage!!,
                        onRetry = viewModel::onRetry,
                    )
                }
                else -> {
                    HomeDispatcher(
                        greetingName = state.greetingName,
                        role = state.role,
                        onCardClick = onCardClick,
                    )
                }
            }
        }
    }
}

@Composable
private fun HomeDispatcher(
    greetingName: String,
    role: UserRole?,
    onCardClick: (String) -> Unit,
) {
    when (role) {
        UserRole.HOSPITAL -> HospitalHome(
            name = greetingName,
            organization = null,
            onCardClick = onCardClick,
        )
        UserRole.ENGINEER -> EngineerHome(
            name = greetingName,
            verified = false, // TODO wire from engineerRepository.fetchByUserId().verificationStatus
            onCardClick = onCardClick,
        )
        UserRole.SUPPLIER -> SupplierHome(
            name = greetingName,
            organization = null,
            onCardClick = onCardClick,
        )
        UserRole.MANUFACTURER -> ManufacturerHome(
            name = greetingName,
            organization = null,
            onCardClick = onCardClick,
        )
        UserRole.LOGISTICS -> LogisticsHome(
            name = greetingName,
            onCardClick = onCardClick,
        )
        null -> NoRoleEmpty()
    }
}

@Composable
private fun NoRoleEmpty() {
    Scaffold(topBar = { ESTopBar(title = "Home") }) { inner ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(inner)
                .padding(Spacing.lg),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            EmptyStateView(
                icon = Icons.Outlined.Badge,
                title = "No role selected",
                subtitle = "Choose a role in Profile to see your dashboard.",
            )
        }
    }
}

@Composable
private fun HomeErrorView(
    message: String,
    onRetry: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(Spacing.lg),
        verticalArrangement = Arrangement.spacedBy(Spacing.md, Alignment.CenterVertically),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Icon(
            imageVector = Icons.Filled.Warning,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.error,
            modifier = Modifier.size(48.dp),
        )
        Text(message, style = MaterialTheme.typography.bodyLarge)
        Button(onClick = onRetry) {
            Icon(Icons.Filled.Refresh, contentDescription = null)
            Spacer(Modifier.size(Spacing.sm))
            Text("Retry")
        }
    }
}

