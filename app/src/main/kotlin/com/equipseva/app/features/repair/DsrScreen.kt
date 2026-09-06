package com.equipseva.app.features.repair

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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Description
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import com.equipseva.app.R
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.core.util.prettyDate
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.EsBtn
import com.equipseva.app.designsystem.components.EsBtnKind
import com.equipseva.app.designsystem.components.EsChip
import com.equipseva.app.designsystem.components.EsField
import com.equipseva.app.designsystem.components.EsFieldType
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.components.Pill
import com.equipseva.app.designsystem.components.PillKind
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaDanger500
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk900
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

// round3812 — Digital Service Report (round494 backend, first client).
// One screen, three modes:
//   * engineer + no DSR yet      -> the filing form
//   * anyone + DSR exists        -> read-only record (status, verdicts, summary)
//   * hospital + pending sign    -> record + the sign-off block
// The server is the authority on WHO may do WHAT (submit_dsr rejects
// non-engineers, hospital_sign_dsr rejects non-hospital); the isHospital
// nav arg only selects which affordances to draw.

@HiltViewModel
class DsrViewModel @Inject constructor(
    private val repo: DsrRepository,
) : ViewModel() {

    data class UiState(
        val loading: Boolean = true,
        val error: String? = null,
        val dsr: DsrRepository.Dsr? = null,
        val submitting: Boolean = false,
        val signing: Boolean = false,
        // one-shot success flags; the screen shows the refreshed record
        val actionError: String? = null,
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()
    private var jobId: String? = null

    fun load(id: String) {
        // Once-per-id guard. load() is called from composition, i.e. on
        // EVERY recomposition — an earlier draft returned early only when
        // NOT loading, so each state emission during the initial fetch
        // re-triggered refresh(): a self-sustaining refresh loop. Any
        // retry goes through refresh() explicitly (the error CTA).
        if (jobId == id) return
        jobId = id
        refresh()
    }

    fun refresh() {
        val id = jobId ?: return
        _state.update { it.copy(loading = true, error = null) }
        viewModelScope.launch {
            repo.fetch(id)
                .onSuccess { dsr ->
                    _state.update { it.copy(loading = false, dsr = dsr) }
                }
                .onFailure { e ->
                    _state.update { it.copy(loading = false, error = e.toUserMessage()) }
                }
        }
    }

    fun submit(
        workSummary: String,
        iec62353Passed: Boolean?,
        calibrationPerformed: Boolean,
        calibrationWithinOem: Boolean?,
        calibrationLabRef: String,
        recommendations: String,
    ) {
        val id = jobId ?: return
        if (_state.value.submitting) return
        if (DsrValidators.workSummaryProblem(workSummary) != null) return
        _state.update { it.copy(submitting = true, actionError = null) }
        viewModelScope.launch {
            repo.submit(
                jobId = id,
                workSummary = workSummary,
                iec62353Passed = iec62353Passed,
                calibrationPerformed = calibrationPerformed,
                calibrationWithinOem = calibrationWithinOem,
                calibrationLabRef = calibrationLabRef,
                recommendations = recommendations,
            )
                .onSuccess {
                    _state.update { it.copy(submitting = false) }
                    refresh()
                }
                .onFailure { e ->
                    _state.update { it.copy(submitting = false, actionError = e.toUserMessage()) }
                }
        }
    }

    fun sign(signerName: String, signerRole: String) {
        val dsrId = _state.value.dsr?.id ?: return
        if (_state.value.signing) return
        if (!DsrValidators.signerFieldOk(signerName) || !DsrValidators.signerFieldOk(signerRole)) return
        _state.update { it.copy(signing = true, actionError = null) }
        viewModelScope.launch {
            repo.sign(dsrId, signerName, signerRole)
                .onSuccess {
                    _state.update { it.copy(signing = false) }
                    refresh()
                }
                .onFailure { e ->
                    _state.update { it.copy(signing = false, actionError = e.toUserMessage()) }
                }
        }
    }
}

@Composable
fun DsrScreen(
    jobId: String,
    isHospital: Boolean,
    onBack: () -> Unit,
    viewModel: DsrViewModel = hiltViewModel(),
) {
    viewModel.load(jobId)
    val state by viewModel.state.collectAsStateWithLifecycle()

    Box(Modifier.fillMaxSize().background(PaperDefault)) {
        Column(Modifier.fillMaxSize()) {
            EsTopBar(title = stringResource(R.string.dsr_title), onBack = onBack)

            when {
                state.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }

                state.error != null -> EmptyStateView(
                    icon = Icons.Outlined.Description,
                    title = stringResource(R.string.dsr_couldnt_load),
                    subtitle = state.error,
                    ctaLabel = stringResource(R.string.dsr_try_again),
                    onCta = { viewModel.refresh() },
                )

                state.dsr == null && isHospital -> EmptyStateView(
                    icon = Icons.Outlined.Description,
                    title = stringResource(R.string.dsr_none_yet_title),
                    subtitle = stringResource(R.string.dsr_none_yet_hospital_body),
                )

                state.dsr == null -> DsrForm(
                    submitting = state.submitting,
                    actionError = state.actionError,
                    onSubmit = viewModel::submit,
                )

                else -> {
                    val dsr = state.dsr!!
                    // Revise path (server supports replace-on-resubmit; the
                    // form prefills from the existing record). Keyed on the
                    // engineer signature timestamp so a successful resubmit
                    // — which changes it — drops back to the record view.
                    var revising by rememberSaveable(dsr.engineerSignatureAt) {
                        mutableStateOf(false)
                    }
                    if (revising && !isHospital && dsr.isPendingSign) {
                        DsrForm(
                            submitting = state.submitting,
                            actionError = state.actionError,
                            initialSummary = dsr.workSummary,
                            initialRecommendations = dsr.recommendations.orEmpty(),
                            initialIecChoice = when (dsr.iec62353Passed) {
                                true -> 1
                                false -> 2
                                null -> 0
                            },
                            onSubmit = viewModel::submit,
                        )
                    } else {
                        DsrRecord(
                            dsr = dsr,
                            isHospital = isHospital,
                            signing = state.signing,
                            actionError = state.actionError,
                            onSign = viewModel::sign,
                            onRevise = { revising = true },
                        )
                    }
                }
            }
        }
    }
}

// --------------------------------------------------------------------------
// Engineer filing form
// --------------------------------------------------------------------------

@Composable
private fun DsrForm(
    submitting: Boolean,
    actionError: String?,
    // Prefill for the revise path (round3812 review finding: the server
    // supports replace-on-resubmit and the footnote promised it, but the
    // form was unreachable once a DSR existed).
    initialSummary: String = "",
    initialRecommendations: String = "",
    initialIecChoice: Int = 0,
    onSubmit: (
        workSummary: String,
        iec62353Passed: Boolean?,
        calibrationPerformed: Boolean,
        calibrationWithinOem: Boolean?,
        calibrationLabRef: String,
        recommendations: String,
    ) -> Unit,
) {
    var workSummary by rememberSaveable { mutableStateOf(initialSummary) }
    // 0 = not applicable, 1 = passed, 2 = failed
    var iecChoice by rememberSaveable { mutableStateOf(initialIecChoice) }
    var calibrationPerformed by rememberSaveable { mutableStateOf(false) }
    // Tri-state on purpose (review finding: a `true` default meant merely
    // toggling "calibration performed" silently recorded the positive
    // attestation "within OEM tolerance" the engineer never chose).
    // -1 = not chosen yet, 1 = within tolerance, 0 = out of tolerance.
    var calibChoice by rememberSaveable { mutableStateOf(-1) }
    var calibrationLabRef by rememberSaveable { mutableStateOf("") }
    var recommendations by rememberSaveable { mutableStateOf(initialRecommendations) }

    val summaryProblem = DsrValidators.workSummaryProblem(workSummary)
    val summaryError = when {
        workSummary.isBlank() -> null // don't scold an untouched form
        summaryProblem == DsrFieldProblem.TooShort ->
            stringResource(R.string.dsr_summary_too_short, DsrValidators.WORK_SUMMARY_MIN)
        summaryProblem == DsrFieldProblem.TooLong ->
            stringResource(R.string.dsr_summary_too_long, DsrValidators.WORK_SUMMARY_MAX)
        else -> null
    }

    Column(
        Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Text(
            stringResource(R.string.dsr_form_explainer),
            style = EsType.BodySm,
            color = SevaInk500,
        )

        EsField(
            value = workSummary,
            onChange = { workSummary = it },
            label = stringResource(R.string.dsr_summary_label),
            placeholder = stringResource(R.string.dsr_summary_placeholder),
            hint = stringResource(
                R.string.dsr_summary_hint,
                workSummary.trim().length,
                DsrValidators.WORK_SUMMARY_MIN,
            ),
            error = summaryError,
            type = EsFieldType.Multiline,
        )

        SectionCard(title = stringResource(R.string.dsr_iec_title)) {
            Text(
                stringResource(R.string.dsr_iec_body),
                style = EsType.BodySm,
                color = SevaInk500,
            )
            Spacer(Modifier.height(8.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                EsChip(
                    text = stringResource(R.string.dsr_iec_na),
                    active = iecChoice == 0,
                    onClick = { iecChoice = 0 },
                )
                EsChip(
                    text = stringResource(R.string.dsr_iec_passed),
                    active = iecChoice == 1,
                    onClick = { iecChoice = 1 },
                )
                EsChip(
                    text = stringResource(R.string.dsr_iec_failed),
                    active = iecChoice == 2,
                    onClick = { iecChoice = 2 },
                )
            }
        }

        SectionCard(title = stringResource(R.string.dsr_calibration_title)) {
            ToggleRow(
                label = stringResource(R.string.dsr_calibration_performed),
                checked = calibrationPerformed,
                onChange = { calibrationPerformed = it },
            )
            if (calibrationPerformed) {
                Spacer(Modifier.height(8.dp))
                Text(
                    stringResource(R.string.dsr_calibration_verdict_label),
                    style = EsType.BodySm,
                    color = SevaInk500,
                )
                Spacer(Modifier.height(6.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    EsChip(
                        text = stringResource(R.string.dsr_calibration_ok),
                        active = calibChoice == 1,
                        onClick = { calibChoice = 1 },
                    )
                    EsChip(
                        text = stringResource(R.string.dsr_calibration_out),
                        active = calibChoice == 0,
                        onClick = { calibChoice = 0 },
                    )
                }
                Spacer(Modifier.height(8.dp))
                EsField(
                    value = calibrationLabRef,
                    onChange = { calibrationLabRef = it },
                    label = stringResource(R.string.dsr_calibration_lab_ref),
                    hint = stringResource(R.string.dsr_calibration_lab_ref_hint),
                )
            }
        }

        EsField(
            value = recommendations,
            onChange = { recommendations = it },
            label = stringResource(R.string.dsr_recommendations_label),
            placeholder = stringResource(R.string.dsr_recommendations_placeholder),
            type = EsFieldType.Multiline,
        )

        if (actionError != null) {
            Text(actionError, style = EsType.BodySm, color = SevaDanger500)
        }

        EsBtn(
            text = if (submitting) {
                stringResource(R.string.dsr_submitting)
            } else {
                stringResource(R.string.dsr_submit)
            },
            onClick = {
                onSubmit(
                    workSummary,
                    when (iecChoice) {
                        1 -> true
                        2 -> false
                        else -> null
                    },
                    calibrationPerformed,
                    if (calibrationPerformed) calibChoice == 1 else null,
                    // Only meaningful alongside a performed calibration; the
                    // repository nulls it otherwise as well (belt + braces).
                    if (calibrationPerformed) calibrationLabRef else "",
                    recommendations,
                )
            },
            // A performed calibration requires an explicit verdict — no
            // silent attestation either way.
            disabled = submitting || summaryProblem != null ||
                (calibrationPerformed && calibChoice == -1),
            full = true,
        )
        Text(
            stringResource(R.string.dsr_submit_footnote),
            style = EsType.Caption,
            color = SevaInk500,
        )
        Spacer(Modifier.height(24.dp))
    }
}

// --------------------------------------------------------------------------
// Read-only record (+ hospital sign-off block while pending)
// --------------------------------------------------------------------------

@Composable
private fun DsrRecord(
    dsr: DsrRepository.Dsr,
    isHospital: Boolean,
    signing: Boolean,
    actionError: String?,
    onSign: (name: String, role: String) -> Unit,
    onRevise: () -> Unit = {},
) {
    var signerName by rememberSaveable { mutableStateOf("") }
    var signerRole by rememberSaveable { mutableStateOf("") }

    Column(
        Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            // Honest status mapping (review finding: an else-branch that
            // labels every non-signed status "awaiting sign-off" would lie
            // for 'disputed'/'invalidated', which the table CHECK allows).
            Pill(
                text = when {
                    dsr.isSigned -> stringResource(R.string.dsr_status_signed)
                    dsr.isPendingSign -> stringResource(R.string.dsr_status_pending)
                    else -> dsr.status.replace('_', ' ')
                },
                kind = when {
                    dsr.isSigned -> PillKind.Success
                    dsr.isPendingSign -> PillKind.Warn
                    else -> PillKind.Neutral
                },
            )
            Spacer(Modifier.width(10.dp))
            Text(
                stringResource(R.string.dsr_filed_on, prettyDate(dsr.engineerSignatureAt)),
                style = EsType.Caption,
                color = SevaInk500,
            )
        }

        SectionCard(title = stringResource(R.string.dsr_verdicts_title)) {
            VerdictRow(
                label = stringResource(R.string.dsr_iec_title),
                value = when (dsr.iec62353Passed) {
                    true -> stringResource(R.string.dsr_iec_passed)
                    false -> stringResource(R.string.dsr_iec_failed)
                    null -> stringResource(R.string.dsr_iec_na)
                },
                good = dsr.iec62353Passed != false,
            )
            VerdictRow(
                label = stringResource(R.string.dsr_calibration_title),
                value = when (dsr.calibrationWithinOem) {
                    true -> stringResource(R.string.dsr_calibration_ok)
                    false -> stringResource(R.string.dsr_calibration_out)
                    null -> stringResource(R.string.dsr_calibration_none)
                },
                good = dsr.calibrationWithinOem != false,
            )
        }

        SectionCard(title = stringResource(R.string.dsr_summary_label)) {
            Text(dsr.workSummary, style = EsType.Body, color = SevaInk900)
        }

        if (!dsr.recommendations.isNullOrBlank()) {
            SectionCard(title = stringResource(R.string.dsr_recommendations_label)) {
                Text(dsr.recommendations, style = EsType.Body, color = SevaInk900)
            }
        }

        if (dsr.isSigned && dsr.hospitalSignatureAt != null) {
            Text(
                stringResource(R.string.dsr_signed_on, prettyDate(dsr.hospitalSignatureAt)),
                style = EsType.Caption,
                color = SevaGreen700,
            )
        }

        if (dsr.isPendingSign && isHospital) {
            SectionCard(title = stringResource(R.string.dsr_sign_title)) {
                Text(
                    stringResource(R.string.dsr_sign_body),
                    style = EsType.BodySm,
                    color = SevaInk500,
                )
                Spacer(Modifier.height(10.dp))
                EsField(
                    value = signerName,
                    onChange = { signerName = it },
                    label = stringResource(R.string.dsr_signer_name),
                )
                Spacer(Modifier.height(8.dp))
                EsField(
                    value = signerRole,
                    onChange = { signerRole = it },
                    label = stringResource(R.string.dsr_signer_role),
                    hint = stringResource(R.string.dsr_signer_role_hint),
                )
                if (actionError != null) {
                    Spacer(Modifier.height(8.dp))
                    Text(actionError, style = EsType.BodySm, color = SevaDanger500)
                }
                Spacer(Modifier.height(12.dp))
                EsBtn(
                    text = if (signing) {
                        stringResource(R.string.dsr_signing)
                    } else {
                        stringResource(R.string.dsr_sign_cta)
                    },
                    onClick = { onSign(signerName, signerRole) },
                    disabled = signing ||
                        !DsrValidators.signerFieldOk(signerName) ||
                        !DsrValidators.signerFieldOk(signerRole),
                    full = true,
                )
            }
        } else if (dsr.isPendingSign && !isHospital) {
            Text(
                stringResource(R.string.dsr_awaiting_hospital),
                style = EsType.BodySm,
                color = SevaInk500,
            )
            EsBtn(
                text = stringResource(R.string.dsr_revise),
                onClick = onRevise,
                kind = EsBtnKind.Secondary,
                full = true,
            )
            Text(
                stringResource(R.string.dsr_revise_footnote),
                style = EsType.Caption,
                color = SevaInk500,
            )
        }
        Spacer(Modifier.height(24.dp))
    }
}

// --------------------------------------------------------------------------
// Small shared pieces
// --------------------------------------------------------------------------

@Composable
private fun SectionCard(
    title: String,
    content: @Composable androidx.compose.foundation.layout.ColumnScope.() -> Unit,
) {
    Column(
        Modifier
            .fillMaxWidth()
            .background(androidx.compose.ui.graphics.Color.White, RoundedCornerShape(12.dp))
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
            .padding(16.dp),
    ) {
        Text(title, style = EsType.Body.copy(fontWeight = androidx.compose.ui.text.font.FontWeight.SemiBold), color = SevaInk900)
        Spacer(Modifier.height(8.dp))
        content()
    }
}

@Composable
private fun ToggleRow(label: String, checked: Boolean, onChange: (Boolean) -> Unit) {
    Row(
        Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(label, style = EsType.Body, color = SevaInk900, modifier = Modifier.weight(1f))
        Switch(checked = checked, onCheckedChange = onChange)
    }
}

@Composable
private fun VerdictRow(label: String, value: String, good: Boolean) {
    Row(
        Modifier.fillMaxWidth().padding(vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(label, style = EsType.BodySm, color = SevaInk500, modifier = Modifier.weight(1f))
        Text(
            value,
            style = EsType.BodySm,
            color = if (good) SevaGreen700 else SevaDanger500,
        )
    }
}
