package com.equipseva.app.features.engineer

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import com.equipseva.app.designsystem.components.EsBtn
import com.equipseva.app.designsystem.components.EsBtnKind
import com.equipseva.app.designsystem.components.EsBtnSize
import com.equipseva.app.designsystem.components.EsField
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.components.Pill
import com.equipseva.app.designsystem.components.PillKind
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk600
import com.equipseva.app.designsystem.theme.SevaInk900
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

@HiltViewModel
class EngineerSupervisionViewModel @Inject constructor(
    private val repo: EngineerGraduationRepository,
) : ViewModel() {
    enum class Status { Loading, Loaded, Error }

    data class UiState(
        val status: Status = Status.Loading,
        val rows: List<EngineerGraduationRepository.SupervisionRow> = emptyList(),
        val error: String? = null,
        val acting: String? = null,    // assignment_id currently mutating
        val toast: String? = null,
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init {
        reload()
    }

    fun reload() {
        _state.update { it.copy(status = Status.Loading, error = null) }
        viewModelScope.launch {
            repo.fetchSupervisionProgress()
                .onSuccess { list ->
                    _state.update { UiState(status = Status.Loaded, rows = list) }
                }
                .onFailure { e ->
                    _state.update {
                        UiState(
                            status = Status.Error,
                            error = e.message ?: "Could not load supervision history.",
                        )
                    }
                }
        }
    }

    fun accept(assignmentId: String) {
        _state.update { it.copy(acting = assignmentId) }
        viewModelScope.launch {
            repo.acceptSupervision(assignmentId)
                .onSuccess {
                    _state.update { it.copy(acting = null, toast = "Accepted") }
                    reload()
                }
                .onFailure { e ->
                    _state.update {
                        it.copy(
                            acting = null,
                            toast = e.message ?: "Could not accept.",
                        )
                    }
                }
        }
    }

    fun decline(assignmentId: String, reason: String) {
        _state.update { it.copy(acting = assignmentId) }
        viewModelScope.launch {
            repo.declineSupervision(assignmentId, reason)
                .onSuccess {
                    _state.update { it.copy(acting = null, toast = "Declined") }
                    reload()
                }
                .onFailure { e ->
                    _state.update {
                        it.copy(
                            acting = null,
                            toast = e.message ?: "Could not decline.",
                        )
                    }
                }
        }
    }

    fun clearToast() {
        _state.update { it.copy(toast = null) }
    }
}

@Composable
fun EngineerSupervisionScreen(
    onBack: () -> Unit,
    viewModel: EngineerSupervisionViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    var declineFor by remember { mutableStateOf<String?>(null) }
    var declineReason by remember { mutableStateOf("") }
    var declineError by remember { mutableStateOf<String?>(null) }

    Box(Modifier.fillMaxSize().background(PaperDefault)) {
        Column(Modifier.fillMaxSize()) {
            EsTopBar(title = "Supervision", onBack = onBack)

            when (state.status) {
                EngineerSupervisionViewModel.Status.Loading ->
                    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator()
                    }

                EngineerSupervisionViewModel.Status.Error ->
                    Column(
                        Modifier.fillMaxSize().padding(24.dp),
                        verticalArrangement = Arrangement.Center,
                        horizontalAlignment = Alignment.CenterHorizontally,
                    ) {
                        Text("Couldn't load", style = EsType.H4, color = SevaInk900)
                        Spacer(Modifier.height(8.dp))
                        Text(state.error ?: "", style = EsType.Body, color = SevaInk500)
                    }

                EngineerSupervisionViewModel.Status.Loaded -> {
                    val asTrainee = state.rows.filter { it.role == "trainee" }
                    val asSupervisor = state.rows.filter { it.role == "supervisor" }
                    Column(
                        Modifier
                            .fillMaxSize()
                            .verticalScroll(rememberScrollState())
                            .padding(16.dp),
                        verticalArrangement = Arrangement.spacedBy(10.dp),
                    ) {
                        if (asSupervisor.isNotEmpty()) {
                            SectionHeader("As supervisor (${asSupervisor.size})")
                            asSupervisor.forEach { row ->
                                AssignmentCard(
                                    row = row,
                                    showActions = row.status == "pending_supervisor_accept",
                                    actionPending = state.acting == row.assignmentId,
                                    onAccept = { viewModel.accept(row.assignmentId) },
                                    onDecline = {
                                        declineFor = row.assignmentId
                                        declineReason = ""
                                        declineError = null
                                    },
                                )
                            }
                        }
                        if (asTrainee.isNotEmpty()) {
                            SectionHeader("As trainee (${asTrainee.size})")
                            asTrainee.forEach { row ->
                                AssignmentCard(
                                    row = row,
                                    showActions = false,
                                    actionPending = false,
                                    onAccept = {},
                                    onDecline = {},
                                )
                            }
                        }
                        if (asTrainee.isEmpty() && asSupervisor.isEmpty()) {
                            EmptyState()
                        }
                    }
                }
            }
        }
    }

    val declineId = declineFor
    if (declineId != null) {
        AlertDialog(
            onDismissRequest = { declineFor = null },
            title = { Text("Decline supervision") },
            text = {
                Column {
                    Text(
                        "Tell the trainee why (min 10 chars — logged forever).",
                        style = EsType.BodySm,
                        color = SevaInk500,
                    )
                    Spacer(Modifier.height(8.dp))
                    EsField(
                        value = declineReason,
                        onChange = {
                            declineReason = it
                            declineError = null
                        },
                        placeholder = "Reason",
                        error = declineError,
                    )
                }
            },
            confirmButton = {
                TextButton(onClick = {
                    val r = declineReason.trim()
                    if (r.length < 10) {
                        declineError = "Min 10 characters."
                    } else {
                        viewModel.decline(declineId, r)
                        declineFor = null
                    }
                }) { Text("Decline") }
            },
            dismissButton = {
                TextButton(onClick = { declineFor = null }) { Text("Cancel") }
            },
        )
    }

    val toast = state.toast
    if (toast != null) {
        // Surface toast as a transient banner; auto-clear on next tap.
        Box(
            Modifier
                .fillMaxWidth()
                .padding(16.dp),
            contentAlignment = Alignment.BottomCenter,
        ) {
            Box(
                Modifier
                    .clip(RoundedCornerShape(8.dp))
                    .background(Color.Black.copy(alpha = 0.85f))
                    .padding(horizontal = 16.dp, vertical = 10.dp)
            ) {
                Text(toast, color = Color.White, style = EsType.BodySm)
            }
        }
        // Best-effort auto-clear via LaunchedEffect would be more polished;
        // for now any user action clears the toast.
        viewModel.clearToast()
    }
}

@Composable
private fun SectionHeader(text: String) {
    Text(
        text,
        style = EsType.H5,
        color = SevaInk900,
        modifier = Modifier.padding(top = 4.dp, bottom = 2.dp),
    )
}

@Composable
private fun AssignmentCard(
    row: EngineerGraduationRepository.SupervisionRow,
    showActions: Boolean,
    actionPending: Boolean,
    onAccept: () -> Unit,
    onDecline: () -> Unit,
) {
    Box(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(10.dp))
            .padding(12.dp),
    ) {
        Column {
            Row(
                Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    "Job ${row.repairJobId.take(8)}",
                    style = EsType.Body.copy(fontWeight = FontWeight.SemiBold),
                    color = SevaInk900,
                )
                StatusPill(row.status)
            }
            Spacer(Modifier.height(4.dp))
            Text(
                "Trainee ${row.traineeTier.replaceFirstChar { it.uppercase() }} · Supervisor ${row.supervisorTier.replaceFirstChar { it.uppercase() }}",
                style = EsType.BodySm,
                color = SevaInk500,
            )
            if (row.signoffOutcome != null) {
                Spacer(Modifier.height(2.dp))
                Text(
                    "Outcome: ${row.signoffOutcome}",
                    style = EsType.BodySm,
                    color = SevaInk600,
                )
            }
            if (showActions) {
                Spacer(Modifier.height(10.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    EsBtn(
                        text = "Accept",
                        onClick = onAccept,
                        kind = EsBtnKind.Primary,
                        size = EsBtnSize.Sm,
                        disabled = actionPending,
                    )
                    EsBtn(
                        text = "Decline",
                        onClick = onDecline,
                        kind = EsBtnKind.Ghost,
                        size = EsBtnSize.Sm,
                        disabled = actionPending,
                    )
                }
            }
        }
    }
}

@Composable
private fun StatusPill(status: String) {
    val (label, kind) = when (status) {
        "pending_supervisor_accept" -> "Awaiting accept" to PillKind.Warn
        "active" -> "Active" to PillKind.Info
        "completed_successful" -> "Success" to PillKind.Success
        "completed_failed" -> "Failed" to PillKind.Danger
        "declined" -> "Declined" to PillKind.Neutral
        "revoked" -> "Revoked" to PillKind.Neutral
        else -> status to PillKind.Default
    }
    Pill(text = label, kind = kind)
}

@Composable
private fun EmptyState() {
    Column(
        Modifier.fillMaxWidth().padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text("No supervision yet", style = EsType.H4, color = SevaInk900)
        Spacer(Modifier.height(8.dp))
        Text(
            "When you're a trainee, request supervision from a higher-tier engineer on a job. When you're a supervisor, pending requests show here for accept/decline.",
            style = EsType.BodySm,
            color = SevaInk500,
        )
    }
}
