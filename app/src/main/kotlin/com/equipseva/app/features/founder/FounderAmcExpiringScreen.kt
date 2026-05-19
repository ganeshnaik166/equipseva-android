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
import androidx.compose.material.icons.outlined.EventAvailable
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
import com.equipseva.app.core.util.formatRupees
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
class FounderAmcExpiringViewModel @Inject constructor(
    private val repo: FounderRepository,
) : ViewModel() {
    data class UiState(
        val loading: Boolean = true,
        val error: String? = null,
        val rows: List<FounderRepository.ExpiringAmcRow> = emptyList(),
    )
    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()
    init { reload() }
    fun reload() {
        _state.update { it.copy(loading = true, error = null) }
        viewModelScope.launch {
            repo.fetchAmcExpiringSoon(windowDays = 30)
                .onSuccess { rows -> _state.update { it.copy(loading = false, rows = rows) } }
                .onFailure { e -> _state.update { it.copy(loading = false, error = e.toUserMessage()) } }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FounderAmcExpiringScreen(
    onBack: () -> Unit,
    onOpenContract: (contractId: String) -> Unit = {},
    viewModel: FounderAmcExpiringViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    com.equipseva.app.designsystem.util.RefreshOnReturn { viewModel.reload() }
    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(
                title = "Expiring AMCs",
                subtitle = if (state.rows.isNotEmpty()) "${state.rows.size} contracts in next 30 days" else null,
                onBack = onBack,
            )
            Box(modifier = Modifier.fillMaxSize()) {
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
                        icon = Icons.Outlined.EventAvailable,
                        title = "Nothing expiring soon",
                        subtitle = "No active contracts end in the next 30 days",
                    )
                    else -> LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(12.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        items(state.rows, key = { it.contractId }) { row ->
                            ExpiringRow(row = row, onClick = { onOpenContract(row.contractId) })
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun ExpiringRow(
    row: FounderRepository.ExpiringAmcRow,
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
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                row.hospitalName,
                fontWeight = FontWeight.Bold,
                color = SevaInk900,
                modifier = Modifier.weight(1f),
            )
            // Match the hospital-side list r353 colour rule: Danger when
            // ≤7 days, Warn otherwise. Keeps founder + hospital reading
            // the same urgency cue for the same contract.
            val (text, kind) = when {
                row.daysRemaining <= 0 -> "Expires today" to PillKind.Danger
                row.daysRemaining == 1 -> "1 day left" to PillKind.Danger
                row.daysRemaining <= 7 -> "${row.daysRemaining} days left" to PillKind.Danger
                else -> "${row.daysRemaining} days left" to PillKind.Warn
            }
            Pill(text = text, kind = kind)
        }
        row.primaryEngineerName?.let {
            Text("Engineer: $it", color = SevaInk700, fontSize = 13.sp)
        }
        Text(
            text = "Ends ${prettyDate(row.endDate)} · ${formatRupees(row.monthlyFeeRupees)} / month",
            color = SevaInk500,
            fontSize = 12.sp,
        )
        if (row.renewalNotificationsSent > 0) {
            // Surface reminder cadence so the founder doesn't double-page
            // a hospital that already received stage 1/2/3.
            Text(
                text = "Reminders sent: ${row.renewalNotificationsSent}/3",
                color = SevaInk500,
                fontSize = 11.sp,
            )
        }
    }
}
