package com.equipseva.app.features.hospital

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
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Build
import androidx.compose.material.icons.outlined.Description
import androidx.compose.material.icons.outlined.EventRepeat
import androidx.compose.material.icons.outlined.History
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.hospital.AssetHistoryRepository
import com.equipseva.app.core.data.hospital.assetEventLabel
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.core.util.prettyDate
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaGreen50
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk700
import com.equipseva.app.designsystem.theme.SevaInk900
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

@HiltViewModel
class AssetHistoryViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val repo: AssetHistoryRepository,
) : ViewModel() {
    data class UiState(
        val loading: Boolean = true,
        val error: String? = null,
        val events: List<AssetHistoryRepository.AssetEvent> = emptyList(),
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    private var loadedSerial: String? = null

    /** Idempotent per serial so the composable's LaunchedEffect can call it freely. */
    fun load(serial: String, force: Boolean = false) {
        if (!force && serial == loadedSerial && state.value.error == null) return
        loadedSerial = serial
        _state.update { it.copy(loading = true, error = null) }
        viewModelScope.launch {
            val session = authRepository.sessionState.first { it !is AuthSession.Unknown }
            val uid = (session as? AuthSession.SignedIn)?.userId
            if (uid == null) {
                _state.update { it.copy(loading = false, error = "Sign in again to view this asset.") }
                return@launch
            }
            repo.fetch(hospitalUserId = uid, equipmentSerial = serial)
                .onSuccess { rows -> _state.update { it.copy(loading = false, events = rows) } }
                .onFailure { e -> _state.update { it.copy(loading = false, error = e.toUserMessage()) } }
        }
    }
}

/**
 * Read-only per-asset timeline (repairs, service reports, PM events) for one
 * piece of equipment, newest first. The drill-down opened by tapping a Fleet
 * Health row that has a serial. Surfaces asset_history() (round 508), which
 * had no Android screen before r1399.
 */
@Composable
fun AssetHistoryScreen(
    serial: String,
    title: String,
    onBack: () -> Unit,
    // r1414 — NABH audit-bundle drill-down for this asset.
    onOpenNabh: (serial: String, title: String) -> Unit = { _, _ -> },
    viewModel: AssetHistoryViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    LaunchedEffect(serial) { viewModel.load(serial) }

    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(title = title.ifBlank { "Asset history" }, onBack = onBack)
            if (serial.isNotBlank()) {
                NabhEntryRow(onClick = { onOpenNabh(serial, title) })
            }
            when {
                state.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }
                state.error != null -> EmptyStateView(
                    icon = Icons.Outlined.History,
                    title = "Couldn't load history",
                    subtitle = state.error,
                    ctaLabel = "Try again",
                    onCta = { viewModel.load(serial, force = true) },
                )
                state.events.isEmpty() -> EmptyStateView(
                    icon = Icons.Outlined.History,
                    title = "No history yet",
                    subtitle = "Repairs, service reports, and maintenance events for SN $serial will appear here.",
                )
                else -> LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(12.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    item(key = "sn") {
                        Text(
                            "SN $serial · ${state.events.size} event${if (state.events.size == 1) "" else "s"}",
                            color = SevaInk500,
                            fontSize = 12.sp,
                            modifier = Modifier.padding(horizontal = 2.dp, vertical = 2.dp),
                        )
                    }
                    itemsIndexed(state.events) { i, event -> EventRow(event, key = i) }
                }
            }
        }
    }
}

@Composable
private fun NabhEntryRow(onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 12.dp, vertical = 8.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(SevaGreen50)
            .clickable(onClick = onClick)
            .padding(14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Icon(Icons.Outlined.Description, contentDescription = null, tint = SevaGreen700)
        Column(modifier = Modifier.weight(1f)) {
            Text("NABH audit bundle", color = SevaInk900, fontWeight = FontWeight.Medium, fontSize = 14.sp)
            Text("Signed service reports for audits", color = SevaInk500, fontSize = 12.sp)
        }
        Text("›", color = SevaInk500, fontSize = 20.sp)
    }
}

@Composable
private fun EventRow(event: AssetHistoryRepository.AssetEvent, key: Int) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
            .padding(12.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Box(
            modifier = Modifier
                .size(36.dp)
                .clip(RoundedCornerShape(9.dp))
                .background(SevaGreen50),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                assetEventIcon(event.eventKind),
                contentDescription = null,
                tint = SevaGreen700,
                modifier = Modifier.size(18.dp),
            )
        }
        Column(modifier = Modifier.weight(1f)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.Top,
            ) {
                Text(
                    assetEventLabel(event.eventKind),
                    color = SevaInk900,
                    fontWeight = FontWeight.Bold,
                    fontSize = 14.sp,
                )
                event.eventAt?.takeIf { it.isNotBlank() }?.let {
                    Text(prettyDate(it), color = SevaInk500, fontSize = 11.sp)
                }
            }
            event.summary?.takeIf { it.isNotBlank() }?.let {
                Text(it, color = SevaInk700, fontSize = 12.sp)
            }
        }
    }
}

/**
 * Icon per asset-timeline event kind:
 *   * repair_job   → wrench (Build)
 *   * dsr_report   → document (Description)
 *   * pm_scheduled → recurring event (EventRepeat)
 *   * other        → History (defensive default)
 */
internal fun assetEventIcon(eventKind: String): ImageVector = when (eventKind) {
    "repair_job" -> Icons.Outlined.Build
    "dsr_report" -> Icons.Outlined.Description
    "pm_scheduled" -> Icons.Outlined.EventRepeat
    else -> Icons.Outlined.History
}
