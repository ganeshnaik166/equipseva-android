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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Security
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
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
import com.equipseva.app.designsystem.components.ESBackTopBar
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.theme.BrandGreen
import com.equipseva.app.designsystem.theme.ErrorRed
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
class FounderIntegrityViewModel @Inject constructor(
    private val repo: FounderRepository,
) : ViewModel() {
    data class UiState(
        val loading: Boolean = true,
        val error: String? = null,
        val rows: List<FounderRepository.IntegrityFlag> = emptyList(),
    )
    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()
    init { reload() }
    fun reload() {
        _state.update { it.copy(loading = true, error = null) }
        viewModelScope.launch {
            repo.fetchIntegrityFlags(limit = 100)
                .onSuccess { rows -> _state.update { it.copy(loading = false, rows = rows) } }
                .onFailure { e -> _state.update { it.copy(loading = false, error = e.toUserMessage()) } }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FounderIntegrityScreen(
    onBack: () -> Unit,
    viewModel: FounderIntegrityViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsState()
    Scaffold(topBar = { ESBackTopBar(title = "Integrity flags", onBack = onBack) }) { padding ->
        Box(modifier = Modifier.fillMaxSize().padding(padding).background(Surface50)) {
            when {
                state.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }
                state.error != null -> EmptyStateView(
                    icon = Icons.Outlined.Security,
                    title = "Couldn't load",
                    subtitle = state.error,
                )
                state.rows.isEmpty() -> EmptyStateView(
                    icon = Icons.Outlined.Security,
                    title = "No integrity events yet",
                    subtitle = "Play Integrity attestations appear here",
                )
                else -> LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(Spacing.md),
                    verticalArrangement = Arrangement.spacedBy(Spacing.sm),
                ) {
                    items(state.rows, key = { it.checkId }) { row ->
                        IntegrityRow(row = row)
                    }
                }
            }
        }
    }
}

@Composable
private fun IntegrityRow(row: FounderRepository.IntegrityFlag) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(Surface0)
            .border(1.dp, Surface200, RoundedCornerShape(14.dp))
            .padding(Spacing.md),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            PassFailPill(pass = row.pass)
            Text(
                text = row.action ?: "unknown action",
                color = Ink900,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.weight(1f),
            )
            row.createdAt?.let { ts ->
                Text(
                    text = relativeTime(ts),
                    color = Ink500,
                    fontSize = 11.sp,
                )
            }
        }
        row.userEmail?.let {
            Text(it, color = Ink700, fontSize = 13.sp)
        }
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            VerdictChip(label = "device", value = row.deviceVerdict)
            VerdictChip(label = "app", value = row.appVerdict)
            row.licensingVerdict?.let { VerdictChip(label = "lic", value = it) }
        }
    }
}

@Composable
private fun PassFailPill(pass: Boolean) {
    val (bg, fg, txt) = if (pass) {
        Triple(Color(0xFFE6F2ED), BrandGreen, "PASS")
    } else {
        Triple(Color(0xFFFADCE3), ErrorRed, "FAIL")
    }
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(999.dp))
            .background(bg)
            .padding(horizontal = 10.dp, vertical = 4.dp),
    ) {
        Text(text = txt, color = fg, fontSize = 11.sp, fontWeight = FontWeight.Bold)
    }
}

@Composable
private fun VerdictChip(label: String, value: String?) {
    val v = value?.takeIf { it.isNotBlank() } ?: "—"
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(8.dp))
            .background(Surface50)
            .border(1.dp, Surface200, RoundedCornerShape(8.dp))
            .padding(horizontal = 8.dp, vertical = 3.dp),
    ) {
        Text(
            text = "$label: $v",
            color = Ink700,
            fontSize = 11.sp,
            fontWeight = FontWeight.Medium,
        )
    }
}

// Coarse relative-time formatter; ISO-8601 timestamps from Postgres.
private fun relativeTime(iso: String): String = runCatching {
    val ts = java.time.OffsetDateTime.parse(iso).toInstant().toEpochMilli()
    val diff = System.currentTimeMillis() - ts
    val mins = diff / 60_000L
    when {
        mins < 1 -> "now"
        mins < 60 -> "${mins}m"
        mins < 60 * 24 -> "${mins / 60}h"
        else -> "${mins / (60 * 24)}d"
    }
}.getOrDefault(iso.take(10))
