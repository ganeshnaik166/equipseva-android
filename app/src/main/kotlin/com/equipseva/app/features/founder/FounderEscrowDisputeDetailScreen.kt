package com.equipseva.app.features.founder

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Inbox
import androidx.compose.material3.CircularProgressIndicator
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
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaDanger500
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk700
import com.equipseva.app.designsystem.theme.SevaInk900
import com.equipseva.app.designsystem.theme.SevaWarning500
import com.equipseva.app.navigation.Routes
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

@HiltViewModel
class FounderEscrowDisputeDetailViewModel @Inject constructor(
    private val repo: FounderRepository,
    savedStateHandle: SavedStateHandle,
) : ViewModel() {
    private val escrowId: String =
        savedStateHandle.get<String>(Routes.FOUNDER_ESCROW_DISPUTE_DETAIL_ARG_ESCROW_ID).orEmpty()

    data class UiState(
        val loading: Boolean = true,
        val error: String? = null,
        val rows: List<FounderRepository.EscrowEventRow> = emptyList(),
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init { reload() }

    fun reload() {
        if (escrowId.isBlank()) {
            _state.update { it.copy(loading = false, error = "Missing escrow id") }
            return
        }
        _state.update { it.copy(loading = true, error = null) }
        viewModelScope.launch {
            repo.fetchEscrowEventTimeline(escrowId)
                .onSuccess { rows -> _state.update { it.copy(loading = false, rows = rows) } }
                .onFailure { e -> _state.update { it.copy(loading = false, error = e.toUserMessage()) } }
        }
    }
}

@Composable
fun FounderEscrowDisputeDetailScreen(
    onBack: () -> Unit,
    viewModel: FounderEscrowDisputeDetailViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(
                title = "Escrow timeline",
                subtitle = state.rows.size.takeIf { it > 0 }?.let { "$it events" },
                onBack = onBack,
            )
            Box(modifier = Modifier.fillMaxSize()) {
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
                        title = "No events",
                        subtitle = "This escrow has no recorded events.",
                    )
                    else -> LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(12.dp),
                        verticalArrangement = Arrangement.spacedBy(0.dp),
                    ) {
                        items(state.rows, key = { it.eventId }) { row -> EscrowEventRow(row) }
                    }
                }
            }
        }
    }
}

@Composable
private fun EscrowEventRow(row: FounderRepository.EscrowEventRow) {
    val tint = when (row.eventKind) {
        "created" -> SevaInk700
        "paid", "released" -> SevaGreen700
        "release_scheduled" -> SevaInk700
        "disputed" -> SevaDanger500
        "dispute_resolved" -> SevaWarning500
        "refunded", "cancelled" -> SevaDanger500
        else -> SevaInk500
    }
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 8.dp),
        verticalAlignment = Alignment.Top,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.width(20.dp)) {
            Box(
                modifier = Modifier
                    .size(12.dp)
                    .clip(CircleShape)
                    .background(tint),
            )
            Box(
                modifier = Modifier
                    .padding(top = 4.dp)
                    .width(2.dp)
                    .height(36.dp)
                    .background(BorderDefault),
            )
        }
        Column(
            modifier = Modifier
                .weight(1f)
                .clip(RoundedCornerShape(10.dp))
                .background(Color.White)
                .border(1.dp, BorderDefault, RoundedCornerShape(10.dp))
                .padding(12.dp),
            verticalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            Text(
                text = row.eventKind.replace('_', ' ').replaceFirstChar { it.uppercase() },
                fontSize = 13.sp,
                fontWeight = FontWeight.SemiBold,
                color = SevaInk900,
            )
            row.occurredAt?.let {
                Text("Occurred: " + it.take(19).replace('T', ' '), color = SevaInk500, fontSize = 11.sp)
            }
            if (!row.actorName.isNullOrBlank() && row.actorName != "(system)") {
                Text("Actor: ${row.actorName}", color = SevaInk500, fontSize = 11.sp)
            } else if (row.actorUserId == null) {
                Text("Actor: system", color = SevaInk500, fontSize = 11.sp)
            }
            row.payload?.toString()?.takeIf { it.isNotBlank() && it != "{}" }?.let {
                Text(
                    text = it,
                    color = SevaInk700,
                    fontSize = 11.sp,
                )
            }
        }
    }
}
