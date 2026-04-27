package com.equipseva.app.features.founder

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Inbox
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.designsystem.components.ESBackTopBar
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.theme.Ink500
import com.equipseva.app.designsystem.theme.Ink700
import com.equipseva.app.designsystem.theme.Ink900
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.designsystem.theme.Surface0
import com.equipseva.app.designsystem.theme.Surface200
import com.equipseva.app.designsystem.theme.Surface50
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

@HiltViewModel
class FounderReportsQueueViewModel @Inject constructor(
    private val repo: FounderRepository,
) : ViewModel() {
    data class UiState(
        val loading: Boolean = true,
        val error: String? = null,
        val rows: List<FounderRepository.PendingReport> = emptyList(),
        val acting: Set<String> = emptySet(),
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init { reload() }

    fun reload() {
        _state.update { it.copy(loading = true, error = null) }
        viewModelScope.launch {
            repo.fetchPendingReports()
                .onSuccess { rows -> _state.update { it.copy(loading = false, rows = rows) } }
                .onFailure { e -> _state.update { it.copy(loading = false, error = e.toUserMessage()) } }
        }
    }

    fun resolve(reportId: String, status: String) {
        if (_state.value.acting.contains(reportId)) return
        _state.update { it.copy(acting = it.acting + reportId, error = null) }
        viewModelScope.launch {
            repo.resolveReport(reportId, status)
                .onSuccess {
                    _state.update {
                        it.copy(
                            acting = it.acting - reportId,
                            rows = it.rows.filterNot { row -> row.reportId == reportId },
                        )
                    }
                }
                .onFailure { e ->
                    _state.update { it.copy(acting = it.acting - reportId, error = e.toUserMessage()) }
                }
        }
    }
}

@Composable
fun FounderReportsQueueScreen(
    onBack: () -> Unit,
    viewModel: FounderReportsQueueViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsState()
    Scaffold(topBar = { ESBackTopBar(title = "Content reports", onBack = onBack) }) { padding ->
        Box(modifier = Modifier.fillMaxSize().padding(padding)) {
            when {
                state.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }
                state.error != null -> EmptyStateView(
                    icon = Icons.Outlined.Inbox,
                    title = "Couldn't load",
                    subtitle = state.error,
                )
                state.rows.isEmpty() -> EmptyStateView(
                    icon = Icons.Outlined.Inbox,
                    title = "All clear",
                    subtitle = "No pending content reports.",
                )
                else -> LazyColumn(
                    modifier = Modifier.fillMaxSize().background(Surface50),
                    contentPadding = androidx.compose.foundation.layout.PaddingValues(Spacing.md),
                    verticalArrangement = Arrangement.spacedBy(Spacing.sm),
                ) {
                    items(state.rows, key = { it.reportId }) { row ->
                        ReportRow(
                            row = row,
                            acting = state.acting.contains(row.reportId),
                            onAction = { status -> viewModel.resolve(row.reportId, status) },
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun ReportRow(
    row: FounderRepository.PendingReport,
    acting: Boolean,
    onAction: (status: String) -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(Surface0)
            .border(1.dp, Surface200, RoundedCornerShape(14.dp))
            .padding(Spacing.md),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                row.targetType.replace('_', ' ').replaceFirstChar { it.uppercase() },
                color = Ink900,
                fontWeight = FontWeight.Bold,
                fontSize = 14.sp,
                modifier = Modifier.weight(1f),
            )
            Text(
                row.reason.replaceFirstChar { it.uppercase() },
                color = Ink700,
                fontSize = 12.sp,
                fontWeight = FontWeight.Medium,
            )
        }
        Text(
            "Reporter: ${row.reporterName ?: row.reporterUserId.take(8)}",
            color = Ink500,
            fontSize = 12.sp,
        )
        Text(
            "Target id: ${row.targetId}",
            color = Ink500,
            fontSize = 11.sp,
        )
        if (!row.notes.isNullOrBlank()) {
            Text(row.notes, color = Ink700, fontSize = 13.sp)
        }
        Row(horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
            Button(
                onClick = { onAction("actioned") },
                enabled = !acting,
                modifier = Modifier.weight(1f),
            ) { Text(if (acting) "…" else "Action") }
            OutlinedButton(
                onClick = { onAction("dismissed") },
                enabled = !acting,
                modifier = Modifier.weight(1f),
            ) { Text("Dismiss") }
            OutlinedButton(
                onClick = { onAction("reviewed") },
                enabled = !acting,
                modifier = Modifier.weight(1f),
            ) { Text("Review") }
        }
    }
}
