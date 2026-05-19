package com.equipseva.app.features.founder

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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.ErrorOutline
import androidx.compose.material.icons.outlined.PersonOff
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.lifecycle.compose.collectAsStateWithLifecycle
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
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.core.util.prettyDate
import com.equipseva.app.core.util.relativeLabel
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
class FounderInactiveEngineersViewModel @Inject constructor(
    private val repo: FounderRepository,
) : ViewModel() {
    data class UiState(
        val loading: Boolean = true,
        // Round 382 — pull-to-refresh inline indicator.
        val refreshing: Boolean = false,
        val error: String? = null,
        val rows: List<FounderRepository.InactiveEngineerRow> = emptyList(),
    )
    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()
    init { reload(initial = true) }
    fun reload(initial: Boolean = false) {
        _state.update {
            it.copy(
                loading = initial || it.rows.isEmpty(),
                refreshing = !initial && it.rows.isNotEmpty(),
                error = null,
            )
        }
        viewModelScope.launch {
            repo.fetchInactiveEngineers(windowDays = 30)
                .onSuccess { rows -> _state.update { it.copy(loading = false, refreshing = false, rows = rows) } }
                .onFailure { e -> _state.update { it.copy(loading = false, refreshing = false, error = e.toUserMessage()) } }
        }
    }
    fun onPullToRefresh() = reload(initial = false)
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FounderInactiveEngineersScreen(
    onBack: () -> Unit,
    onOpenEngineer: (engineerId: String) -> Unit = {},
    viewModel: FounderInactiveEngineersViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    com.equipseva.app.designsystem.util.RefreshOnReturn { viewModel.reload() }
    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(
                title = "Inactive engineers",
                subtitle = if (state.rows.isNotEmpty()) "${state.rows.size} verified · 0 jobs in 30d" else null,
                onBack = onBack,
            )
            // Round 382 — pull-to-refresh.
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
                        icon = Icons.Outlined.ErrorOutline,
                        title = "Couldn't load",
                        subtitle = state.error,
                    )
                    state.rows.isEmpty() -> EmptyStateView(
                        icon = Icons.Outlined.PersonOff,
                        title = "All engineers active",
                        subtitle = "Every verified engineer (verified > 7d ago) has released at least one job in the last 30 days.",
                    )
                    else -> LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(12.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        items(state.rows, key = { it.engineerId }) { row ->
                            InactiveEngineerRow(row = row, onClick = { onOpenEngineer(row.engineerId) })
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun InactiveEngineerRow(
    row: FounderRepository.InactiveEngineerRow,
    onClick: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
            .clickable(onClick = onClick)
            .padding(12.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                row.fullName,
                fontWeight = FontWeight.Bold,
                color = SevaInk900,
                modifier = Modifier.weight(1f),
            )
            // Pill conveys severity: never-shipped (no last_released_at)
            // is the loudest signal; long-quiet is danger; recently quiet
            // is warn.
            val lastReleasedDays = row.lastReleasedAt?.let { iso ->
                com.equipseva.app.core.util.daysUntil(iso)?.let { -it }
            }
            val (label, kind) = when {
                lastReleasedDays == null -> "Never shipped" to PillKind.Danger
                lastReleasedDays >= 90L -> "${lastReleasedDays}d quiet" to PillKind.Danger
                else -> "${lastReleasedDays}d quiet" to PillKind.Warn
            }
            Pill(text = label, kind = kind)
        }
        val locationLine = listOfNotNull(row.city, row.state).joinToString(", ").ifBlank { null }
        locationLine?.let {
            Text(it, color = SevaInk700, fontSize = 13.sp)
        }
        if (row.specializations.isNotEmpty()) {
            Text(
                text = row.specializations.take(3).joinToString(" · "),
                color = SevaInk500,
                fontSize = 12.sp,
            )
        }
        val contactLine = listOfNotNull(row.email, row.phone).joinToString(" · ")
        if (contactLine.isNotBlank()) {
            Text(contactLine, color = SevaInk500, fontSize = 12.sp)
        }
        val verifiedRel = row.verifiedAt?.let { relativeLabel(it) }
        verifiedRel?.let {
            Text("Verified ${prettyDate(row.verifiedAt!!)} · $it ago", color = SevaInk500, fontSize = 11.sp)
        }
    }
}
