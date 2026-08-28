package com.equipseva.app.features.engineer

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
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
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import kotlinx.coroutines.delay
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import com.equipseva.app.R
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
import com.equipseva.app.core.network.toUserMessage
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
        val pickerOpen: Boolean = false,
        val pickerLoading: Boolean = false,
        val pickerJobs: List<EngineerGraduationRepository.SupervisableJob> = emptyList(),
        val pickerSupervisors: List<EngineerGraduationRepository.EligibleSupervisor> = emptyList(),
        val pickerError: String? = null,
        val submitting: Boolean = false,
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init {
        reload()
    }

    fun reload() {
        // r1451 — only blank to the full-screen loader on the initial load; a
        // signoff-triggered refresh with rows already shown updates silently.
        _state.update { it.copy(status = if (it.rows.isEmpty()) Status.Loading else it.status, error = null) }
        viewModelScope.launch {
            repo.fetchSupervisionProgress()
                .onSuccess { list ->
                    _state.update { UiState(status = Status.Loaded, rows = list) }
                }
                .onFailure { e ->
                    _state.update {
                        UiState(
                            status = Status.Error,
                            error = e.toUserMessage("Could not load supervision history."),
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
                            toast = e.toUserMessage("Could not accept."),
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
                            toast = e.toUserMessage("Could not decline."),
                        )
                    }
                }
        }
    }

    fun clearToast() {
        _state.update { it.copy(toast = null) }
    }

    fun openPicker() {
        _state.update { it.copy(pickerOpen = true, pickerLoading = true, pickerError = null) }
        viewModelScope.launch {
            val jobsResult = repo.fetchSupervisableJobs()
            val supersResult = repo.fetchEligibleSupervisors()
            val jobs = jobsResult.getOrNull().orEmpty()
            val supers = supersResult.getOrNull().orEmpty()
            val firstError = jobsResult.exceptionOrNull() ?: supersResult.exceptionOrNull()
            _state.update {
                it.copy(
                    pickerLoading = false,
                    pickerJobs = jobs,
                    pickerSupervisors = supers,
                    pickerError = firstError?.toUserMessage("Couldn't load picker data."),
                )
            }
        }
    }

    fun closePicker() {
        _state.update {
            it.copy(
                pickerOpen = false,
                pickerJobs = emptyList(),
                pickerSupervisors = emptyList(),
                pickerError = null,
                submitting = false,
            )
        }
    }

    fun signoff(assignmentId: String, outcome: String, notes: String) {
        _state.update { it.copy(acting = assignmentId) }
        viewModelScope.launch {
            repo.signoffSupervision(assignmentId, outcome, notes)
                .onSuccess {
                    _state.update { it.copy(acting = null, toast = "Signed off") }
                    reload()
                }
                .onFailure { e ->
                    _state.update {
                        it.copy(
                            acting = null,
                            toast = e.toUserMessage("Could not sign off."),
                        )
                    }
                }
        }
    }

    fun submitRequest(jobId: String, supervisorUserId: String) {
        _state.update { it.copy(submitting = true, pickerError = null) }
        viewModelScope.launch {
            repo.requestSupervision(jobId, supervisorUserId)
                .onSuccess {
                    _state.update {
                        it.copy(
                            submitting = false,
                            pickerOpen = false,
                            pickerJobs = emptyList(),
                            pickerSupervisors = emptyList(),
                            toast = "Request sent",
                        )
                    }
                    reload()
                }
                .onFailure { e ->
                    _state.update {
                        it.copy(
                            submitting = false,
                            pickerError = e.toUserMessage("Could not send request."),
                        )
                    }
                }
        }
    }
}

@Composable
fun EngineerSupervisionScreen(
    onBack: () -> Unit,
    viewModel: EngineerSupervisionViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    // r585 audit-24 MEDIUM: rememberSaveable so mid-typing reasons + notes
    // survive rotation / theme flips / font-scale changes.
    var declineFor by rememberSaveable { mutableStateOf<String?>(null) }
    var declineReason by rememberSaveable { mutableStateOf("") }
    var declineError by rememberSaveable { mutableStateOf<String?>(null) }
    var signoffFor by rememberSaveable { mutableStateOf<String?>(null) }
    var signoffOutcome by rememberSaveable { mutableStateOf("successful") }
    var signoffNotes by rememberSaveable { mutableStateOf("") }
    var signoffError by rememberSaveable { mutableStateOf<String?>(null) }

    // r585 audit-24 MEDIUM: drive clearToast via LaunchedEffect so the
    // banner stays on screen long enough to read.
    LaunchedEffect(state.toast) {
        if (state.toast != null) {
            delay(2_500)
            viewModel.clearToast()
        }
    }

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
                        Text(stringResource(R.string.engineer_supervision_couldnt_load), style = EsType.H4, color = SevaInk900)
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
                        EsBtn(
                            text = "Request supervision",
                            onClick = { viewModel.openPicker() },
                            kind = EsBtnKind.Primary,
                            size = EsBtnSize.Md,
                            full = true,
                        )
                        if (asSupervisor.isNotEmpty()) {
                            SectionHeader("As supervisor (${asSupervisor.size})")
                            asSupervisor.forEach { row ->
                                AssignmentCard(
                                    row = row,
                                    showAcceptDecline = row.status == "pending_supervisor_accept",
                                    showSignoff = row.status == "active",
                                    actionPending = state.acting == row.assignmentId,
                                    onAccept = { viewModel.accept(row.assignmentId) },
                                    onDecline = {
                                        declineFor = row.assignmentId
                                        declineReason = ""
                                        declineError = null
                                    },
                                    onSignoff = {
                                        signoffFor = row.assignmentId
                                        signoffOutcome = "successful"
                                        signoffNotes = ""
                                        signoffError = null
                                    },
                                )
                            }
                        }
                        if (asTrainee.isNotEmpty()) {
                            SectionHeader("As trainee (${asTrainee.size})")
                            asTrainee.forEach { row ->
                                AssignmentCard(
                                    row = row,
                                    showAcceptDecline = false,
                                    showSignoff = false,
                                    actionPending = false,
                                    onAccept = {},
                                    onDecline = {},
                                    onSignoff = {},
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

    if (state.pickerOpen) {
        RequestSupervisionDialog(
            state = state,
            onCancel = { viewModel.closePicker() },
            onSubmit = { jobId, supId -> viewModel.submitRequest(jobId, supId) },
        )
    }

    val declineId = declineFor
    if (declineId != null) {
        AlertDialog(
            onDismissRequest = { declineFor = null },
            title = { Text(stringResource(R.string.engineer_supervision_decline_title)) },
            text = {
                Column {
                    Text(
                        stringResource(R.string.engineer_supervision_decline_hint),
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
                }) { Text(stringResource(R.string.engineer_supervision_decline_confirm)) }
            },
            dismissButton = {
                TextButton(onClick = { declineFor = null }) { Text(stringResource(R.string.common_cancel)) }
            },
        )
    }

    val signoffId = signoffFor
    if (signoffId != null) {
        AlertDialog(
            onDismissRequest = { signoffFor = null },
            title = { Text(stringResource(R.string.engineer_supervision_signoff_title)) },
            text = {
                Column {
                    Text(
                        stringResource(R.string.engineer_supervision_signoff_hint),
                        style = EsType.BodySm,
                        color = SevaInk500,
                    )
                    Spacer(Modifier.height(8.dp))
                    Text(stringResource(R.string.engineer_supervision_outcome_label), style = EsType.BodySm, color = SevaInk600)
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        listOf("successful", "failed", "disputed").forEach { o ->
                            EsBtn(
                                text = o.replaceFirstChar { it.uppercase() },
                                onClick = { signoffOutcome = o },
                                kind = if (signoffOutcome == o) EsBtnKind.Primary else EsBtnKind.Secondary,
                                size = EsBtnSize.Sm,
                            )
                        }
                    }
                    Spacer(Modifier.height(8.dp))
                    EsField(
                        value = signoffNotes,
                        onChange = {
                            signoffNotes = it
                            signoffError = null
                        },
                        label = "Notes",
                        placeholder = "How did the supervised work go?",
                        error = signoffError,
                    )
                }
            },
            confirmButton = {
                TextButton(onClick = {
                    val n = signoffNotes.trim()
                    if (n.length < 10) {
                        signoffError = "Min 10 characters."
                    } else {
                        viewModel.signoff(signoffId, signoffOutcome, n)
                        signoffFor = null
                    }
                }) { Text(stringResource(R.string.engineer_supervision_signoff_confirm)) }
            },
            dismissButton = {
                TextButton(onClick = { signoffFor = null }) { Text(stringResource(R.string.common_cancel)) }
            },
        )
    }

    val toast = state.toast
    if (toast != null) {
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
        // Auto-clear is driven by the LaunchedEffect(state.toast) above.
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
    showAcceptDecline: Boolean,
    showSignoff: Boolean,
    actionPending: Boolean,
    onAccept: () -> Unit,
    onDecline: () -> Unit,
    onSignoff: () -> Unit,
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
                    stringResource(R.string.engineer_supervision_job_id_label, row.repairJobId.take(8)),
                    style = EsType.Body.copy(fontWeight = FontWeight.SemiBold),
                    color = SevaInk900,
                )
                StatusPill(row.status)
            }
            Spacer(Modifier.height(4.dp))
            Text(
                stringResource(
                    R.string.engineer_supervision_trainee_supervisor_tier,
                    row.traineeTier.replaceFirstChar { it.uppercase() },
                    row.supervisorTier.replaceFirstChar { it.uppercase() },
                ),
                style = EsType.BodySm,
                color = SevaInk500,
            )
            if (row.signoffOutcome != null) {
                Spacer(Modifier.height(2.dp))
                Text(
                    stringResource(R.string.engineer_supervision_outcome_value, row.signoffOutcome),
                    style = EsType.BodySm,
                    color = SevaInk600,
                )
            }
            if (showAcceptDecline) {
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
            } else if (showSignoff) {
                Spacer(Modifier.height(10.dp))
                EsBtn(
                    text = "Sign off",
                    onClick = onSignoff,
                    kind = EsBtnKind.Primary,
                    size = EsBtnSize.Sm,
                    disabled = actionPending,
                )
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
private fun RequestSupervisionDialog(
    state: EngineerSupervisionViewModel.UiState,
    onCancel: () -> Unit,
    onSubmit: (jobId: String, supervisorUserId: String) -> Unit,
) {
    var selectedJob by rememberSaveable { mutableStateOf<String?>(null) }
    var selectedSup by rememberSaveable { mutableStateOf<String?>(null) }

    AlertDialog(
        onDismissRequest = onCancel,
        title = { Text(stringResource(R.string.engineer_supervision_request_dialog_title)) },
        text = {
            if (state.pickerLoading) {
                Box(
                    Modifier.fillMaxWidth().padding(24.dp),
                    contentAlignment = Alignment.Center,
                ) { CircularProgressIndicator() }
            } else if (state.pickerError != null && state.pickerJobs.isEmpty() && state.pickerSupervisors.isEmpty()) {
                Text(state.pickerError, style = EsType.BodySm, color = SevaInk500)
            } else {
                Column(
                    Modifier.verticalScroll(rememberScrollState()),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Text(stringResource(R.string.engineer_supervision_pick_job_label), style = EsType.H5, color = SevaInk900)
                    if (state.pickerJobs.isEmpty()) {
                        Text(
                            stringResource(R.string.engineer_supervision_no_jobs),
                            style = EsType.BodySm,
                            color = SevaInk500,
                        )
                    } else {
                        state.pickerJobs.forEach { job ->
                            PickerRow(
                                title = job.jobNumber ?: job.repairJobId.take(8),
                                subtitle = listOfNotNull(job.equipmentBrand, job.equipmentModel)
                                    .joinToString(" "),
                                selected = selectedJob == job.repairJobId,
                                onClick = { selectedJob = job.repairJobId },
                            )
                        }
                    }
                    Spacer(Modifier.height(4.dp))
                    Text(stringResource(R.string.engineer_supervision_pick_supervisor_label), style = EsType.H5, color = SevaInk900)
                    if (state.pickerSupervisors.isEmpty()) {
                        Text(
                            stringResource(R.string.engineer_supervision_no_supervisors),
                            style = EsType.BodySm,
                            color = SevaInk500,
                        )
                    } else {
                        state.pickerSupervisors.forEach { sup ->
                            PickerRow(
                                title = sup.displayName,
                                subtitle = "${sup.currentTier.replaceFirstChar { it.uppercase() }} · ${sup.jobsCompleted} jobs",
                                selected = selectedSup == sup.userId,
                                onClick = { selectedSup = sup.userId },
                            )
                        }
                    }
                    if (state.pickerError != null) {
                        Spacer(Modifier.height(4.dp))
                        Text(
                            state.pickerError,
                            style = EsType.BodySm,
                            color = SevaInk900,
                        )
                    }
                }
            }
        },
        confirmButton = {
            TextButton(
                onClick = {
                    val j = selectedJob
                    val s = selectedSup
                    if (j != null && s != null && !state.submitting) {
                        onSubmit(j, s)
                    }
                },
                enabled = selectedJob != null && selectedSup != null && !state.submitting,
            ) {
                Text(if (state.submitting) stringResource(R.string.kyc_email_otp_sending) else stringResource(R.string.engineer_supervision_send_request))
            }
        },
        dismissButton = {
            TextButton(onClick = onCancel) { Text(stringResource(R.string.common_cancel)) }
        },
    )
}

@Composable
private fun PickerRow(
    title: String,
    subtitle: String,
    selected: Boolean,
    onClick: () -> Unit,
) {
    val borderColor = if (selected) SevaInk900 else BorderDefault
    Box(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(8.dp))
            .background(if (selected) Color(0xFFF0F4F0) else Color.White)
            .border(1.dp, borderColor, RoundedCornerShape(8.dp))
            .clickable(onClick = onClick)
            .padding(10.dp),
    ) {
        Column {
            Text(title, style = EsType.Body, color = SevaInk900)
            if (subtitle.isNotBlank()) {
                Text(subtitle, style = EsType.BodySm, color = SevaInk500)
            }
        }
    }
}

@Composable
private fun EmptyState() {
    Column(
        Modifier.fillMaxWidth().padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(stringResource(R.string.engineer_supervision_empty_title), style = EsType.H4, color = SevaInk900)
        Spacer(Modifier.height(8.dp))
        Text(
            stringResource(R.string.engineer_supervision_empty_body),
            style = EsType.BodySm,
            color = SevaInk500,
        )
    }
}
