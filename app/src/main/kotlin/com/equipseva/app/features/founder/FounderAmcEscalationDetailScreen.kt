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
import com.equipseva.app.core.data.amc.AmcRepository
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.core.util.formatRupees
import com.equipseva.app.core.util.prettyDate
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.EsBtn
import com.equipseva.app.designsystem.components.EsBtnKind
import com.equipseva.app.designsystem.components.EsBtnSize
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.components.Pill
import com.equipseva.app.designsystem.components.PillKind
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk700
import com.equipseva.app.designsystem.theme.SevaInk900
import com.equipseva.app.navigation.Routes
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

@HiltViewModel
class FounderAmcEscalationDetailViewModel @Inject constructor(
    private val founderRepo: FounderRepository,
    private val amcRepo: AmcRepository,
    savedStateHandle: SavedStateHandle,
) : ViewModel() {
    private val escalationId: String =
        savedStateHandle.get<String>(Routes.FOUNDER_AMC_ESCALATION_DETAIL_ARG_ESCALATION_ID).orEmpty()

    data class UiState(
        val loading: Boolean = true,
        val error: String? = null,
        val detail: FounderRepository.AmcEscalationDetail? = null,
        val rotation: List<AmcRepository.AmcRotationRow> = emptyList(),
        val resolving: Boolean = false,
        val resolved: Boolean = false,
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init { reload() }

    fun reload() {
        if (escalationId.isBlank()) {
            _state.update { it.copy(loading = false, error = "Missing escalation id") }
            return
        }
        _state.update { it.copy(loading = true, error = null) }
        viewModelScope.launch {
            // Fetch escalation context first; we need amc_contract_id for the
            // rotation call. Detail and rotation aren't independent, so a
            // serial fetch is fine here.
            val detailResult = founderRepo.fetchAmcEscalationDetail(escalationId)
            val detail = detailResult.getOrNull()
            if (detail == null) {
                _state.update {
                    it.copy(
                        loading = false,
                        error = detailResult.exceptionOrNull()?.toUserMessage() ?: "Escalation not found",
                    )
                }
                return@launch
            }
            val rotationResult = amcRepo.listRotation(detail.amcContractId)
            _state.update {
                it.copy(
                    loading = false,
                    detail = detail,
                    rotation = rotationResult.getOrNull().orEmpty(),
                )
            }
        }
    }

    fun resolve() {
        if (_state.value.resolving) return
        _state.update { it.copy(resolving = true, error = null) }
        viewModelScope.launch {
            founderRepo.resolveAmcEscalation(escalationId, notes = "Resolved via admin detail screen")
                .onSuccess { _state.update { it.copy(resolving = false, resolved = true) } }
                .onFailure { e -> _state.update { it.copy(resolving = false, error = e.toUserMessage()) } }
        }
    }
}

@Composable
fun FounderAmcEscalationDetailScreen(
    onBack: () -> Unit,
    viewModel: FounderAmcEscalationDetailViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(title = "Escalation detail", onBack = onBack)
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
                    state.detail == null -> EmptyStateView(
                        icon = Icons.Outlined.Inbox,
                        title = "Not found",
                        subtitle = "This escalation no longer exists.",
                    )
                    else -> EscalationDetailBody(
                        detail = state.detail!!,
                        rotation = state.rotation,
                        resolving = state.resolving,
                        resolved = state.resolved,
                        onResolve = viewModel::resolve,
                    )
                }
            }
        }
    }
}

@Composable
private fun EscalationDetailBody(
    detail: FounderRepository.AmcEscalationDetail,
    rotation: List<AmcRepository.AmcRotationRow>,
    resolving: Boolean,
    resolved: Boolean,
    onResolve: () -> Unit,
) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(12.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        item("reason") {
            DetailCard {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = detail.reason.replace('_', ' ').replaceFirstChar { it.uppercase() },
                            color = SevaInk900,
                            fontWeight = FontWeight.Bold,
                            fontSize = 16.sp,
                        )
                        detail.createdAt?.let {
                            Text(
                                "Raised: " + it.take(19).replace('T', ' '),
                                color = SevaInk500,
                                fontSize = 12.sp,
                            )
                        }
                    }
                    Pill(
                        text = if (detail.resolvedAt != null || resolved) "Resolved" else "Open",
                        kind = if (detail.resolvedAt != null || resolved) PillKind.Success else PillKind.Danger,
                    )
                }
                if (!detail.notes.isNullOrBlank()) {
                    Text(detail.notes, color = SevaInk700, fontSize = 13.sp)
                }
            }
        }
        item("contract") {
            DetailCard {
                SectionLabel("Contract")
                LabelRow("Hospital", detail.hospitalName?.takeIf { it.isNotBlank() } ?: "Hospital")
                detail.contractStatus?.let { LabelRow("Status", it.replaceFirstChar { c -> c.uppercase() }) }
                detail.visitFrequency?.let { LabelRow("Cadence", it.replaceFirstChar { c -> c.uppercase() }) }
                detail.monthlyFeeRupees?.let { LabelRow("Monthly fee", formatRupees(it)) }
                detail.nextVisitAt?.let { LabelRow("Next visit", it.take(16).replace('T', ' ')) }
                detail.contractEndDate?.let { LabelRow("End date", prettyDate(it)) }
            }
        }
        if (detail.visitId != null) {
            item("visit") {
                DetailCard {
                    SectionLabel("Visit")
                    detail.visitNumber?.let { LabelRow("Visit number", "#$it") }
                    detail.visitStatus?.let { LabelRow("Status", it.replace('_', ' ').replaceFirstChar { c -> c.uppercase() }) }
                    detail.visitScheduledDate?.let { LabelRow("Scheduled", prettyDate(it)) }
                    detail.visitEquipmentType?.let { LabelRow("Equipment", it.replace('_', ' ').replaceFirstChar { c -> c.uppercase() }) }
                }
            }
        }
        item("rotation_header") {
            Text(
                text = "Engineer rotation (${rotation.size})",
                color = SevaInk700,
                fontSize = 13.sp,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.padding(start = 4.dp),
            )
        }
        if (rotation.isEmpty()) {
            item("rotation_empty") {
                DetailCard {
                    Text(
                        text = "No engineers in rotation.",
                        color = SevaInk500,
                        fontSize = 13.sp,
                    )
                }
            }
        } else {
            items(rotation, key = { it.rotationId }) { row -> RotationRow(row) }
        }
        item("actions") {
            if (!resolved && detail.resolvedAt == null) {
                EsBtn(
                    text = if (resolving) "Resolving…" else "Mark resolved",
                    kind = EsBtnKind.Primary,
                    size = EsBtnSize.Md,
                    disabled = resolving,
                    onClick = onResolve,
                    full = true,
                )
            }
        }
    }
}

@Composable
private fun DetailCard(content: @Composable androidx.compose.foundation.layout.ColumnScope.() -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
            .padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
        content = content,
    )
}

@Composable
private fun SectionLabel(text: String) {
    Text(
        text = text.uppercase(),
        color = SevaInk500,
        fontSize = 11.sp,
        fontWeight = FontWeight.SemiBold,
        letterSpacing = 0.5.sp,
    )
}

@Composable
private fun LabelRow(label: String, value: String) {
    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(label, color = SevaInk500, fontSize = 12.sp, modifier = Modifier.weight(0.4f))
        Text(value, color = SevaInk900, fontSize = 13.sp, fontWeight = FontWeight.Medium, modifier = Modifier.weight(0.6f))
    }
}

@Composable
private fun RotationRow(row: AmcRepository.AmcRotationRow) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(10.dp))
            .padding(12.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = row.engineerName,
                    color = SevaInk900,
                    fontWeight = FontWeight.SemiBold,
                    fontSize = 13.sp,
                )
                if (!row.engineerCity.isNullOrBlank()) {
                    Text(row.engineerCity, color = SevaInk500, fontSize = 11.sp)
                }
            }
            if (row.isPrimary) {
                Pill(text = "Primary", kind = PillKind.Info)
            } else {
                Pill(text = "#${row.priority}", kind = PillKind.Default)
            }
            Pill(
                text = if (row.isAvailable) "Available" else "Unavailable",
                kind = if (row.isAvailable) PillKind.Success else PillKind.Warn,
            )
        }
        if (!row.active) {
            Text("Inactive", color = SevaInk500, fontSize = 11.sp)
        }
    }
}
