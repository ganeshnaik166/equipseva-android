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
import com.equipseva.app.core.network.toUserMessage
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
class EngineerDemandSignalsViewModel @Inject constructor(
    private val repo: EngineerGraduationRepository,
) : ViewModel() {
    enum class Status { Loading, Loaded, Error }

    data class UiState(
        val status: Status = Status.Loading,
        val rows: List<EngineerGraduationRepository.MyDemandSignal> = emptyList(),
        val error: String? = null,
        val submitting: Boolean = false,
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
            repo.fetchMyDemandSignals()
                .onSuccess { list ->
                    // it.copy (not a fresh UiState) so a pending "Reported"
                    // toast set by submit() survives this reload — a fresh
                    // UiState reset toast=null and the confirmation never showed.
                    _state.update { it.copy(status = Status.Loaded, rows = list, error = null) }
                }
                .onFailure { e ->
                    _state.update {
                        UiState(
                            status = Status.Error,
                            error = e.toUserMessage("Could not load your reports."),
                        )
                    }
                }
        }
    }

    fun submit(
        brand: String,
        model: String,
        partNumber: String,
        description: String,
        urgency: String,
        onResult: (ok: Boolean, msg: String) -> Unit,
    ) {
        _state.update { it.copy(submitting = true) }
        viewModelScope.launch {
            repo.reportDemandSignal(
                partNumber = partNumber.ifBlank { null },
                brand = brand.ifBlank { null },
                model = model.ifBlank { null },
                query = description.ifBlank { null },
                urgency = urgency,
            )
                .onSuccess {
                    _state.update { it.copy(submitting = false, toast = "Reported") }
                    onResult(true, "")
                    reload()
                }
                .onFailure { e ->
                    _state.update { it.copy(submitting = false) }
                    onResult(false, e.toUserMessage("Could not report."))
                }
        }
    }

    fun clearToast() {
        _state.update { it.copy(toast = null) }
    }
}

@Composable
fun EngineerDemandSignalsScreen(
    onBack: () -> Unit,
    viewModel: EngineerDemandSignalsViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    var reportOpen by rememberSaveable { mutableStateOf(false) }

    // r585 audit-24 MEDIUM: drive clearToast via LaunchedEffect.
    LaunchedEffect(state.toast) {
        if (state.toast != null) {
            delay(2_500)
            viewModel.clearToast()
        }
    }

    Box(Modifier.fillMaxSize().background(PaperDefault)) {
        Column(Modifier.fillMaxSize()) {
            EsTopBar(title = "Demand signals", onBack = onBack)

            when (state.status) {
                EngineerDemandSignalsViewModel.Status.Loading ->
                    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator()
                    }

                EngineerDemandSignalsViewModel.Status.Error ->
                    Column(
                        Modifier.fillMaxSize().padding(24.dp),
                        verticalArrangement = Arrangement.Center,
                        horizontalAlignment = Alignment.CenterHorizontally,
                    ) {
                        Text(stringResource(R.string.earnings_projection_load_error_title), style = EsType.H4, color = SevaInk900)
                        Spacer(Modifier.height(8.dp))
                        Text(state.error ?: "", style = EsType.Body, color = SevaInk500)
                    }

                EngineerDemandSignalsViewModel.Status.Loaded ->
                    Column(
                        Modifier
                            .fillMaxSize()
                            .verticalScroll(rememberScrollState())
                            .padding(16.dp),
                        verticalArrangement = Arrangement.spacedBy(10.dp),
                    ) {
                        EsBtn(
                            text = "Report a missing part",
                            onClick = { reportOpen = true },
                            kind = EsBtnKind.Primary,
                            size = EsBtnSize.Md,
                            full = true,
                        )
                        Text(
                            stringResource(R.string.engineer_demand_signals_intro),
                            style = EsType.BodySm,
                            color = SevaInk500,
                        )

                        if (state.rows.isEmpty()) {
                            Spacer(Modifier.height(16.dp))
                            Text(
                                stringResource(R.string.engineer_demand_signals_no_reports),
                                style = EsType.Body,
                                color = SevaInk500,
                            )
                        } else {
                            Text(
                                stringResource(R.string.engineer_demand_signals_your_reports_count, state.rows.size),
                                style = EsType.H5,
                                color = SevaInk900,
                                modifier = Modifier.padding(top = 6.dp),
                            )
                            state.rows.forEach { row -> SignalCard(row) }
                        }
                    }
            }
        }
    }

    if (reportOpen) {
        ReportDialog(
            submitting = state.submitting,
            onCancel = { reportOpen = false },
            onSubmit = { brand, model, part, desc, urg, onResult ->
                viewModel.submit(brand, model, part, desc, urg) { ok, msg ->
                    if (ok) reportOpen = false
                    onResult(ok, msg)
                }
            },
        )
    }

    val toast = state.toast
    if (toast != null) {
        Box(
            Modifier.fillMaxWidth().padding(16.dp),
            contentAlignment = Alignment.BottomCenter,
        ) {
            Box(
                Modifier
                    .clip(RoundedCornerShape(8.dp))
                    .background(Color.Black.copy(alpha = 0.85f))
                    .padding(horizontal = 16.dp, vertical = 10.dp),
            ) {
                Text(toast, color = Color.White, style = EsType.BodySm)
            }
        }
        // Auto-clear is driven by the LaunchedEffect(state.toast) above.
    }
}

@Composable
private fun SignalCard(row: EngineerGraduationRepository.MyDemandSignal) {
    val resolved = row.resolvedAt != null
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
                    listOfNotNull(row.equipmentBrand, row.equipmentModel)
                        .joinToString(" ")
                        .ifBlank { row.partNumber ?: stringResource(R.string.engineer_demand_signals_unspecified) },
                    style = EsType.Body.copy(fontWeight = FontWeight.SemiBold),
                    color = SevaInk900,
                )
                StatusPill(resolved, row.resolvedVia, row.founderPriority)
            }
            if (!row.partNumber.isNullOrBlank()) {
                Spacer(Modifier.height(2.dp))
                Text(stringResource(R.string.engineer_demand_signals_part_number, row.partNumber.orEmpty()), style = EsType.BodySm, color = SevaInk600)
            }
            Spacer(Modifier.height(4.dp))
            Text(
                stringResource(R.string.engineer_demand_signals_urgency_days_open, row.urgency, row.daysOpen),
                style = EsType.BodySm,
                color = SevaInk500,
            )
            if (resolved) {
                Spacer(Modifier.height(2.dp))
                Text(
                    stringResource(R.string.engineer_demand_signals_resolved_via, row.resolvedVia ?: "—"),
                    style = EsType.BodySm,
                    color = SevaInk500,
                )
            }
        }
    }
}

@Composable
private fun StatusPill(resolved: Boolean, via: String?, priority: String?) {
    if (resolved) {
        val (label, kind) = when (via) {
            "supplier_onboarded" -> "Supplier on" to PillKind.Success
            "bonded_intake" -> "Bonded" to PillKind.Success
            "duplicate_of_existing" -> "Duplicate" to PillKind.Neutral
            "wont_fulfill" -> "Won't fulfill" to PillKind.Danger
            "fulfilled_offplatform" -> "Off-platform" to PillKind.Neutral
            else -> "Resolved" to PillKind.Success
        }
        Pill(text = label, kind = kind)
    } else if (priority != null) {
        val kind = when (priority) {
            "high" -> PillKind.Danger
            "med" -> PillKind.Warn
            else -> PillKind.Default
        }
        Pill(text = "Priority $priority", kind = kind)
    } else {
        Pill(text = "Pending", kind = PillKind.Warn)
    }
}

@Composable
private fun ReportDialog(
    submitting: Boolean,
    onCancel: () -> Unit,
    onSubmit: (
        brand: String,
        model: String,
        part: String,
        desc: String,
        urgency: String,
        onResult: (ok: Boolean, msg: String) -> Unit,
    ) -> Unit,
) {
    // r585 audit-24 MEDIUM: rememberSaveable so mid-typing report fields
    // survive rotation / theme flips while the dialog is open.
    var brand by rememberSaveable { mutableStateOf("") }
    var model by rememberSaveable { mutableStateOf("") }
    var part by rememberSaveable { mutableStateOf("") }
    var desc by rememberSaveable { mutableStateOf("") }
    var urgency by rememberSaveable { mutableStateOf("standard") }
    var error by rememberSaveable { mutableStateOf<String?>(null) }

    AlertDialog(
        onDismissRequest = onCancel,
        title = { Text(stringResource(R.string.engineer_demand_signals_report_dialog_title)) },
        text = {
            Column(
                Modifier.verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Text(
                    stringResource(R.string.engineer_demand_signals_provide_one_field_hint),
                    style = EsType.BodySm,
                    color = SevaInk500,
                )
                EsField(
                    value = brand,
                    onChange = { brand = it; error = null },
                    label = "Brand",
                    placeholder = "Mindray, Philips, GE…",
                )
                EsField(
                    value = model,
                    onChange = { model = it; error = null },
                    label = "Model",
                    placeholder = "BeneView T5, EFIA, …",
                )
                EsField(
                    value = part,
                    onChange = { part = it; error = null },
                    label = "Part number",
                    placeholder = "115-006080-00",
                )
                EsField(
                    value = desc,
                    onChange = { desc = it; error = null },
                    label = "Description",
                    placeholder = "What you need; symptoms; vendor quotes",
                )
                Spacer(Modifier.height(4.dp))
                Text(stringResource(R.string.engineer_demand_signals_urgency_label), style = EsType.BodySm, color = SevaInk600)
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    listOf("standard", "urgent", "critical").forEach { u ->
                        EsBtn(
                            text = u.replaceFirstChar { it.uppercase() },
                            onClick = { urgency = u },
                            kind = if (urgency == u) EsBtnKind.Primary else EsBtnKind.Secondary,
                            size = EsBtnSize.Sm,
                        )
                    }
                }
                if (error != null) {
                    Text(
                        error!!,
                        style = EsType.BodySm,
                        color = SevaInk900,
                    )
                }
            }
        },
        confirmButton = {
            TextButton(
                onClick = {
                    val anyFilled = listOf(brand, model, part, desc).any { it.isNotBlank() }
                    if (!anyFilled) {
                        error = "Provide at least one field."
                    } else if (!submitting) {
                        onSubmit(brand, model, part, desc, urgency) { ok, msg ->
                            if (!ok) error = msg
                        }
                    }
                },
                enabled = !submitting,
            ) {
                Text(if (submitting) stringResource(R.string.engineer_demand_signals_reporting) else stringResource(R.string.engineer_demand_signals_report_action))
            }
        },
        dismissButton = {
            TextButton(onClick = onCancel) { Text(stringResource(R.string.common_cancel)) }
        },
    )
}
