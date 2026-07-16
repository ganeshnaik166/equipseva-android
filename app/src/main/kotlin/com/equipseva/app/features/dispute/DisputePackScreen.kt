package com.equipseva.app.features.dispute

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.CheckCircle
import androidx.compose.material.icons.outlined.Gavel
import androidx.compose.material3.Checkbox
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
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
import com.equipseva.app.core.data.dispute.DisputePackRepository
import com.equipseva.app.core.data.repair.EvidenceRepository
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.core.util.prettyDateTime
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.EsBtn
import com.equipseva.app.designsystem.components.EsBtnKind
import com.equipseva.app.designsystem.components.EsBtnSize
import com.equipseva.app.designsystem.components.EsField
import com.equipseva.app.designsystem.components.EsFieldType
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaDanger500
import com.equipseva.app.designsystem.theme.SevaGreen700
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
class DisputePackViewModel @Inject constructor(
    savedState: SavedStateHandle,
    private val repo: DisputePackRepository,
    private val evidenceRepo: EvidenceRepository,
) : ViewModel() {
    private val escrowId: String = savedState.get<String>(Routes.DISPUTE_PACK_ARG_ESCROW_ID).orEmpty()
    private val repairJobId: String = savedState.get<String>(Routes.DISPUTE_PACK_ARG_JOB_ID).orEmpty()
    val filerRole: String = savedState.get<String>(Routes.DISPUTE_PACK_ARG_ROLE).orEmpty()

    data class UiState(
        val loadingEvidence: Boolean = true,
        val evidence: List<EvidenceRepository.Evidence> = emptyList(),
        val submitting: Boolean = false,
        val error: String? = null,
        val filed: Boolean = false,
        val filedEvidence: List<DisputePackRepository.PackEvidence> = emptyList(),
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init { loadEvidence() }

    fun loadEvidence() {
        _state.update { it.copy(loadingEvidence = true) }
        viewModelScope.launch {
            evidenceRepo.fetch(repairJobId)
                .onSuccess { list -> _state.update { it.copy(loadingEvidence = false, evidence = list) } }
                .onFailure { _state.update { it.copy(loadingEvidence = false, evidence = emptyList()) } }
        }
    }

    fun clearError() = _state.update { it.copy(error = null) }

    /**
     * Files the pack: open a draft (with statement + selected evidence), submit
     * it for mediation, then load its detail for the confirmation view. Any step
     * failing surfaces inline and leaves the form intact.
     */
    fun file(positionStatement: String, evidenceIds: List<String>) {
        if (_state.value.submitting) return
        _state.update { it.copy(submitting = true, error = null) }
        viewModelScope.launch {
            val packId = repo.open(escrowId, filerRole, positionStatement, evidenceIds).getOrElse { e ->
                _state.update { it.copy(submitting = false, error = e.toUserMessage()) }
                return@launch
            }
            repo.submit(packId).getOrElse { e ->
                _state.update { it.copy(submitting = false, error = e.toUserMessage()) }
                return@launch
            }
            val filedEvidence = repo.detail(packId).getOrNull().orEmpty()
            _state.update { it.copy(submitting = false, filed = true, filedEvidence = filedEvidence) }
        }
    }
}

/**
 * Dispute evidence vault (r1445): a party to a disputed escrow files a
 * structured pack — a position statement plus attached evidence — for the
 * founder to mediate. Surfaces open_dispute_evidence_pack +
 * submit_dispute_evidence_pack + dispute_pack_evidence_detail (round 495).
 * Reached from the engineer's / hospital's disputes list.
 */
@Composable
fun DisputePackScreen(
    onBack: () -> Unit,
    viewModel: DisputePackViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    var statement by rememberSaveable { mutableStateOf("") }
    val selected = remember { mutableStateListOf<String>() }

    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(title = "Dispute evidence", onBack = onBack)
            when {
                state.filed -> FiledConfirmation(state.filedEvidence, onBack)
                state.loadingEvidence -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }
                else -> LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(16.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    item(key = "intro") {
                        Text(
                            "Filing as ${viewModel.filerRole.replaceFirstChar { it.uppercase() }}. State your case and attach the " +
                                "evidence that supports it. Our team reviews both sides before deciding.",
                            style = EsType.BodySm,
                            color = SevaInk700,
                        )
                    }
                    item(key = "statement") {
                        EsField(
                            value = statement,
                            onChange = { statement = it },
                            label = "Your position",
                            placeholder = "Explain what happened and why the escrow should resolve in your favour",
                            hint = "At least 20 characters",
                            type = EsFieldType.Multiline,
                        )
                    }
                    item(key = "evidence-header") {
                        Text(
                            if (state.evidence.isEmpty()) "No evidence on file for this job"
                            else "Attach evidence (${selected.size} selected)",
                            style = EsType.H5,
                            color = SevaInk900,
                        )
                    }
                    items(state.evidence, key = { it.id }) { ev ->
                        EvidencePickRow(
                            evidence = ev,
                            checked = ev.id in selected,
                            onToggle = { if (ev.id in selected) selected.remove(ev.id) else selected.add(ev.id) },
                        )
                    }
                    state.error?.let { msg ->
                        item(key = "error") { Text(msg, style = EsType.BodySm, color = SevaDanger500) }
                    }
                    item(key = "file") {
                        EsBtn(
                            text = if (state.submitting) "Filing…" else "File for mediation",
                            onClick = { viewModel.file(statement, selected.toList()) },
                            kind = EsBtnKind.Primary,
                            size = EsBtnSize.Lg,
                            full = true,
                            disabled = state.submitting || !isValidPositionStatement(statement),
                        )
                    }
                    item(key = "tail") { Spacer(Modifier.height(8.dp)) }
                }
            }
        }
    }
}

@Composable
private fun FiledConfirmation(evidence: List<DisputePackRepository.PackEvidence>, onBack: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Icon(Icons.Outlined.CheckCircle, contentDescription = null, tint = SevaGreen700, modifier = Modifier.height(56.dp))
        Spacer(Modifier.height(12.dp))
        Text("Evidence pack filed", style = EsType.H4, color = SevaInk900)
        Spacer(Modifier.height(6.dp))
        Text(
            if (evidence.isEmpty()) "Your position is filed for mediation. Our team will review and decide."
            else "Filed for mediation with ${evidence.size} evidence item(s). Our team will review and decide.",
            style = EsType.BodySm,
            color = SevaInk700,
        )
        Spacer(Modifier.height(20.dp))
        EsBtn(text = "Done", onClick = onBack, kind = EsBtnKind.Primary, size = EsBtnSize.Lg, full = true)
    }
}

@Composable
private fun EvidencePickRow(
    evidence: EvidenceRepository.Evidence,
    checked: Boolean,
    onToggle: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(10.dp))
            .clickable(onClick = onToggle)
            .padding(start = 12.dp, top = 8.dp, bottom = 8.dp, end = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(
                evidenceKindLabel(evidence.evidenceKind),
                style = EsType.Body.copy(fontWeight = FontWeight.Medium),
                color = SevaInk900,
            )
            evidence.capturedAt?.takeIf { it.isNotBlank() }?.let {
                Text(prettyDateTime(it), style = EsType.Caption, color = SevaInk500)
            }
        }
        Checkbox(checked = checked, onCheckedChange = { onToggle() })
    }
}

// ---------------------------------------------------------------------
//  Pinned helpers
// ---------------------------------------------------------------------

/** Position statement must be >= 20 trimmed chars (mirrors the server guard). */
internal fun isValidPositionStatement(statement: String): Boolean = statement.trim().length >= 20

/** Human label for an evidence_kind: de-snake + capitalise. */
internal fun evidenceKindLabel(kind: String): String =
    kind.trim().replace('_', ' ').replaceFirstChar { it.uppercase() }.ifBlank { "Evidence" }
