package com.equipseva.app.features.profile

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Gavel
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.data.consent.GrievanceRepository
import com.equipseva.app.core.data.consent.grievanceTypeLabel
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.core.util.prettyDate
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.components.Pill
import com.equipseva.app.designsystem.components.PillKind
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk700
import com.equipseva.app.designsystem.theme.SevaInk900
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

@HiltViewModel
class GrievancesViewModel @Inject constructor(
    private val repo: GrievanceRepository,
) : ViewModel() {
    data class UiState(
        val loading: Boolean = true,
        val refreshing: Boolean = false,
        val error: String? = null,
        val grievances: List<GrievanceRepository.Grievance> = emptyList(),
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init { reload(initial = true) }

    fun reload(initial: Boolean = false) {
        _state.update {
            it.copy(
                loading = initial || it.grievances.isEmpty(),
                refreshing = !initial && it.grievances.isNotEmpty(),
                error = null,
            )
        }
        viewModelScope.launch {
            repo.fetch()
                .onSuccess { rows -> _state.update { it.copy(loading = false, refreshing = false, grievances = rows) } }
                .onFailure { e -> _state.update { it.copy(loading = false, refreshing = false, error = e.toUserMessage()) } }
        }
    }

    fun onPullToRefresh() = reload(initial = false)
}

/**
 * Read-only list of DPDP grievances the user has filed, with status and the
 * statutory deadline. Reachable from the Profile "My grievances" row (both
 * roles). Surfaces my_grievances() (round 485), which had no Android screen
 * before r1403 — pairs with the r1402 consent centre.
 */
@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
fun GrievancesScreen(
    onBack: () -> Unit,
    viewModel: GrievancesViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    com.equipseva.app.designsystem.util.RefreshOnReturn { viewModel.reload() }

    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(title = "My grievances", onBack = onBack)
            androidx.compose.material3.pulltorefresh.PullToRefreshBox(
                isRefreshing = state.refreshing,
                onRefresh = viewModel::onPullToRefresh,
                modifier = Modifier.fillMaxSize(),
            ) {
                when {
                    state.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator()
                    }
                    state.error != null -> EmptyStateView(
                        icon = Icons.Outlined.Gavel,
                        title = "Couldn't load grievances",
                        subtitle = state.error,
                        ctaLabel = "Try again",
                        onCta = { viewModel.reload() },
                    )
                    state.grievances.isEmpty() -> EmptyStateView(
                        icon = Icons.Outlined.Gavel,
                        title = "No grievances filed",
                        subtitle = "Data-rights requests you raise under India's DPDP Act (access, correction, deletion) show up here with their status and deadline.",
                    )
                    else -> LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(12.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        items(state.grievances, key = { it.id }) { g -> GrievanceRow(g) }
                    }
                }
            }
        }
    }
}

@Composable
private fun GrievanceRow(g: GrievanceRepository.Grievance) {
    val (pillText, pillKind) = grievanceStatusPillTextAndKind(g.status)
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
            .padding(12.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(
                grievanceTypeLabel(g.grievanceType),
                color = SevaInk900,
                fontWeight = FontWeight.Bold,
                fontSize = 14.sp,
                modifier = Modifier.weight(1f),
            )
            Pill(text = pillText, kind = pillKind)
        }
        if (g.description.isNotBlank()) {
            Text(g.description, color = SevaInk700, fontSize = 12.sp, maxLines = 3)
        }
        val meta = when {
            g.resolvedAt?.isNotBlank() == true -> "Resolved ${prettyDate(g.resolvedAt)}"
            g.deadlineAt?.isNotBlank() == true -> "Response due by ${prettyDate(g.deadlineAt)}"
            g.createdAt?.isNotBlank() == true -> "Filed ${prettyDate(g.createdAt)}"
            else -> null
        }
        meta?.let { Text(it, color = SevaInk500, fontSize = 11.sp) }
    }
}

/**
 * Grievance status → pill:
 *   * open      → "Open"      (Warn)
 *   * in_review → "In review" (Info)
 *   * resolved  → "Resolved"  (Success)
 *   * escalated → "Escalated" (Danger)
 *   * rejected  → "Rejected"  (Neutral)
 *   * other     → capitalised (Neutral, defensive default)
 */
internal fun grievanceStatusPillTextAndKind(status: String): Pair<String, PillKind> = when (status) {
    "open" -> "Open" to PillKind.Warn
    "in_review" -> "In review" to PillKind.Info
    "resolved" -> "Resolved" to PillKind.Success
    "escalated" -> "Escalated" to PillKind.Danger
    "rejected" -> "Rejected" to PillKind.Neutral
    else -> status.replace('_', ' ').replaceFirstChar { it.uppercase() } to PillKind.Neutral
}
