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
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Assignment
import androidx.compose.material.icons.outlined.Draw
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.data.repair.DsrRepository
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.core.util.prettyDate
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.EsBottomSheet
import com.equipseva.app.designsystem.components.EsBtn
import com.equipseva.app.designsystem.components.EsBtnKind
import com.equipseva.app.designsystem.components.EsBtnSize
import com.equipseva.app.designsystem.components.EsField
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.components.Pill
import com.equipseva.app.designsystem.components.PillKind
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.SevaDanger500
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaGreen50
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk700
import com.equipseva.app.designsystem.theme.SevaInk900
import com.equipseva.app.navigation.Routes
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

@HiltViewModel
class ServiceReportDetailViewModel @Inject constructor(
    savedState: SavedStateHandle,
    private val repo: DsrRepository,
) : ViewModel() {
    private val jobId: String =
        checkNotNull(savedState.get<String>(Routes.SERVICE_REPORT_ARG_JOB_ID)) {
            "ServiceReportDetailViewModel requires arg ${Routes.SERVICE_REPORT_ARG_JOB_ID}"
        }

    data class UiState(
        val loading: Boolean = true,
        val error: String? = null,
        val data: DsrRepository.Dsr? = null,
        val signing: Boolean = false,
        val signError: String? = null,
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init { reload() }

    fun reload() {
        _state.update { it.copy(loading = it.data == null, error = null) }
        viewModelScope.launch {
            repo.fetch(jobId)
                .onSuccess { d -> _state.update { it.copy(loading = false, data = d) } }
                .onFailure { e -> _state.update { it.copy(loading = false, error = e.toUserMessage()) } }
        }
    }

    /**
     * Hospital counter-signs the DSR. On success clears any sign error and
     * reloads so the status pill + hospital signature row refresh; on failure
     * surfaces the server message inside the sheet. [onSigned] lets the screen
     * close the sheet only on success.
     */
    fun signDsr(signerName: String, signerRole: String, onSigned: () -> Unit) {
        val dsrId = _state.value.data?.id ?: return
        _state.update { it.copy(signing = true, signError = null) }
        viewModelScope.launch {
            repo.sign(dsrId, signerName, signerRole)
                .onSuccess {
                    _state.update { it.copy(signing = false, signError = null) }
                    onSigned()
                    reload()
                }
                .onFailure { e -> _state.update { it.copy(signing = false, signError = e.toUserMessage()) } }
        }
    }

    fun clearSignError() = _state.update { it.copy(signError = null) }
}

/**
 * In-app structured Digital Service Report (r1411): status, compliance checks
 * (IEC 62353 + calibration), engineer/hospital signatures, work summary and
 * recommendations for a completed job. Read-only; surfaces dsr_for_job()
 * (round 494). Complements the downloadable PDF; reached from job "Records".
 */
@Composable
fun ServiceReportDetailScreen(
    onBack: () -> Unit,
    viewModel: ServiceReportDetailViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    com.equipseva.app.designsystem.util.RefreshOnReturn { viewModel.reload() }

    var showSignSheet by rememberSaveable { mutableStateOf(false) }
    if (showSignSheet) {
        SignDsrSheet(
            signing = state.signing,
            error = state.signError,
            onClose = {
                showSignSheet = false
                viewModel.clearSignError()
            },
            onSubmit = { name, role ->
                viewModel.signDsr(name, role) { showSignSheet = false }
            },
        )
    }

    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(title = "Service report", onBack = onBack)
            when {
                state.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }
                state.error != null -> EmptyStateView(
                    icon = Icons.Outlined.Assignment,
                    title = "Couldn't load service report",
                    subtitle = state.error,
                    ctaLabel = "Try again",
                    onCta = { viewModel.reload() },
                )
                state.data == null -> EmptyStateView(
                    icon = Icons.Outlined.Assignment,
                    title = "No service report yet",
                    subtitle = "Once the engineer completes and signs off the job, the digital service report appears here.",
                )
                else -> {
                    val d = state.data!!
                    Column(
                        modifier = Modifier
                            .fillMaxSize()
                            .verticalScroll(rememberScrollState())
                            .padding(16.dp),
                        verticalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        StatusHeroCard(d)
                        SectionHeader("Compliance checks")
                        CheckRow("IEC 62353 electrical safety", d.iec62353Passed)
                        CheckRow("Calibration within OEM spec", d.calibrationWithinOem)
                        SectionHeader("Signatures")
                        SignRow("Engineer", d.engineerSignatureAt)
                        SignRow("Hospital", d.hospitalSignatureAt)
                        if (canSignDsr(d.status)) {
                            EsBtn(
                                text = "Sign report",
                                onClick = { showSignSheet = true },
                                kind = EsBtnKind.Primary,
                                size = EsBtnSize.Lg,
                                full = true,
                                leading = {
                                    Icon(Icons.Outlined.Draw, contentDescription = null, modifier = Modifier.size(18.dp))
                                },
                            )
                        }
                        d.workSummary?.takeIf { it.isNotBlank() }?.let {
                            SectionHeader("Work summary")
                            Text(it, style = EsType.Body, color = SevaInk700)
                        }
                        d.recommendations?.takeIf { it.isNotBlank() }?.let {
                            SectionHeader("Recommendations")
                            Text(it, style = EsType.Body, color = SevaInk700)
                        }
                        Spacer(Modifier.height(8.dp))
                    }
                }
            }
        }
    }
}

@Composable
private fun StatusHeroCard(d: DsrRepository.Dsr) {
    val (pillText, pillKind) = dsrStatusPill(d.status)
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(SevaGreen50)
            .padding(16.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text("Digital service report", style = EsType.BodySm, color = SevaInk700)
        Pill(text = pillText, kind = pillKind)
    }
}

@Composable
private fun SectionHeader(label: String) {
    Text(label, style = EsType.H5, color = SevaInk900, modifier = Modifier.padding(top = 4.dp))
}

@Composable
private fun CheckRow(label: String, passed: Boolean?) {
    val (pillText, pillKind) = dsrCheckPill(passed)
    RowCard {
        Text(label, style = EsType.Body, color = SevaInk700, modifier = Modifier.weight(1f))
        Pill(text = pillText, kind = pillKind)
    }
}

@Composable
private fun SignRow(label: String, signedAt: String?) {
    RowCard {
        Text(label, style = EsType.Body, color = SevaInk700, modifier = Modifier.weight(1f))
        Text(
            signedAt?.takeIf { it.isNotBlank() }?.let { "Signed ${prettyDate(it)}" } ?: "Not signed",
            style = EsType.Body.copy(fontWeight = FontWeight.Medium),
            color = if (signedAt.isNullOrBlank()) SevaInk500 else SevaInk900,
        )
    }
}

@Composable
private fun RowCard(content: @Composable androidx.compose.foundation.layout.RowScope.() -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(10.dp))
            .padding(14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        content = content,
    )
}

@Composable
private fun SignDsrSheet(
    signing: Boolean,
    error: String?,
    onClose: () -> Unit,
    onSubmit: (name: String, role: String) -> Unit,
) {
    var name by rememberSaveable { mutableStateOf("") }
    var role by rememberSaveable { mutableStateOf("") }
    EsBottomSheet(onClose = onClose, title = "Sign service report") {
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text(
                "Confirm the work was completed to your satisfaction. Your name and role are recorded on the signed report.",
                style = EsType.BodySm,
                color = SevaInk700,
            )
            EsField(
                value = name,
                onChange = { name = it },
                label = "Your name",
                placeholder = "e.g. Dr. Anita Rao",
            )
            EsField(
                value = role,
                onChange = { role = it },
                label = "Your role",
                placeholder = "e.g. Biomedical Head",
                imeAction = ImeAction.Done,
            )
            if (error != null) {
                Text(error, style = EsType.BodySm, color = SevaDanger500)
            }
            EsBtn(
                text = if (signing) "Signing…" else "Confirm signature",
                onClick = { onSubmit(name, role) },
                kind = EsBtnKind.Primary,
                size = EsBtnSize.Lg,
                full = true,
                disabled = signing || !isValidSigner(name, role),
            )
            Spacer(Modifier.height(4.dp))
        }
    }
}

// ---------------------------------------------------------------------
//  Pinned helpers
// ---------------------------------------------------------------------

/** DSR lifecycle status → pill. Fully-signed reads Success; drafts Neutral. */
internal fun dsrStatusPill(status: String): Pair<String, PillKind> = when (status) {
    "both_signed", "signed", "completed", "finalized" -> "Signed off" to PillKind.Success
    "engineer_signed", "pending_hospital_sign" -> "Awaiting hospital" to PillKind.Warn
    "draft", "" -> "Draft" to PillKind.Neutral
    else -> status.replace('_', ' ').replaceFirstChar { it.uppercase() } to PillKind.Neutral
}

/**
 * True when the hospital can counter-sign: only DSRs the engineer has
 * submitted and that are awaiting the hospital signature. Mirrors the
 * server guard (status = 'pending_hospital_sign'); any other status hides
 * the Sign CTA so we never show a button the RPC would reject.
 */
internal fun canSignDsr(status: String): Boolean = status == "pending_hospital_sign"

/**
 * Signer name + role are both required at >= 3 trimmed chars — mirrors the
 * server validation so the confirm button stays disabled until the RPC
 * would accept the input.
 */
internal fun isValidSigner(name: String, role: String): Boolean =
    name.trim().length >= 3 && role.trim().length >= 3

/** Compliance-check flag → pill. true Pass / false Fail / null not-recorded. */
internal fun dsrCheckPill(passed: Boolean?): Pair<String, PillKind> = when (passed) {
    true -> "Pass" to PillKind.Success
    false -> "Fail" to PillKind.Danger
    null -> "—" to PillKind.Neutral
}
