package com.equipseva.app.features.repair

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
import androidx.compose.material.icons.outlined.VerifiedUser
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.data.repair.EvidenceRepository
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.core.util.prettyDate
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.components.Pill
import com.equipseva.app.designsystem.components.PillKind
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaInk500
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
class EvidenceVaultViewModel @Inject constructor(
    savedState: SavedStateHandle,
    private val repo: EvidenceRepository,
) : ViewModel() {
    private val jobId: String =
        checkNotNull(savedState.get<String>(Routes.EVIDENCE_ARG_JOB_ID)) {
            "EvidenceVaultViewModel requires arg ${Routes.EVIDENCE_ARG_JOB_ID}"
        }

    data class UiState(
        val loading: Boolean = true,
        val refreshing: Boolean = false,
        val error: String? = null,
        val rows: List<EvidenceRepository.Evidence> = emptyList(),
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init { reload(initial = true) }

    fun reload(initial: Boolean = false) {
        _state.update {
            it.copy(
                loading = initial || it.rows.isEmpty(),
                refreshing = !initial && it.rows.isNotEmpty(),
                error = null,
            )
        }
        viewModelScope.launch {
            repo.fetch(jobId)
                .onSuccess { rows -> _state.update { it.copy(loading = false, refreshing = false, rows = rows) } }
                .onFailure { e -> _state.update { it.copy(loading = false, refreshing = false, error = e.toUserMessage()) } }
        }
    }

    fun onPullToRefresh() = reload(initial = false)
}

/**
 * Evidence vault (r1408): the §65B hash-chained evidence ledger for one repair
 * job — every PDF, photo, signature, OTP and receipt with its kind, producer,
 * capture time, size and a short SHA-256 fingerprint. Read-only; surfaces
 * evidence_for_repair_job() (round 492). Reached from the job detail "Records".
 */
@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
fun EvidenceVaultScreen(
    onBack: () -> Unit,
    viewModel: EvidenceVaultViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    com.equipseva.app.designsystem.util.RefreshOnReturn { viewModel.reload() }

    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(title = "Evidence vault", onBack = onBack)
            androidx.compose.material3.pulltorefresh.PullToRefreshBox(
                isRefreshing = state.refreshing,
                onRefresh = viewModel::onPullToRefresh,
                modifier = Modifier.fillMaxSize(),
            ) {
                when {
                    state.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator()
                    }
                    state.error != null -> EmptyStateView(
                        icon = Icons.Outlined.VerifiedUser,
                        title = "Couldn't load evidence",
                        subtitle = state.error,
                        ctaLabel = "Try again",
                        onCta = { viewModel.reload() },
                    )
                    state.rows.isEmpty() -> EmptyStateView(
                        icon = Icons.Outlined.VerifiedUser,
                        title = "No evidence yet",
                        subtitle = "Tamper-evident records for this job — photos, signatures, reports and receipts — are collected here as work progresses.",
                    )
                    else -> LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(12.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        items(state.rows, key = { it.id }) { row -> EvidenceRow(row) }
                    }
                }
            }
        }
    }
}

@Composable
private fun EvidenceRow(row: EvidenceRepository.Evidence) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(
                evidenceKindLabel(row.evidenceKind),
                style = EsType.Body.copy(fontWeight = FontWeight.Medium),
                color = SevaInk900,
            )
            val meta = listOfNotNull(
                producerKindLabel(row.producerKind).takeIf { it.isNotBlank() },
                (row.capturedAt ?: row.createdAt)?.takeIf { it.isNotBlank() }?.let { prettyDate(it) },
                row.contentSizeBytes.takeIf { it > 0 }?.let { formatBytes(it) },
            ).joinToString(" · ")
            if (meta.isNotEmpty()) {
                Text(meta, style = EsType.Caption, color = SevaInk500)
            }
            row.contentSha256?.takeIf { it.isNotBlank() }?.let {
                Text("SHA-256 ${shortHash(it)}", style = EsType.Caption, color = SevaInk500)
            }
        }
        Pill(text = "Sealed", kind = PillKind.Success)
    }
}

// ---------------------------------------------------------------------
//  Pinned helpers
// ---------------------------------------------------------------------

/** Human label for an evidence_kind (round 492 CHECK list); de-snake fallback. */
internal fun evidenceKindLabel(kind: String): String = when (kind) {
    "pved_pdf" -> "Pre-visit dossier (PDF)"
    "dsr_pdf" -> "Service report (PDF)"
    "chat_archive" -> "Chat archive"
    "photo_before" -> "Photo — before"
    "photo_after" -> "Photo — after"
    "photo_during" -> "Photo — during"
    "signature_engineer" -> "Engineer signature"
    "signature_hospital" -> "Hospital signature"
    "amc_affidavit" -> "AMC affidavit"
    "tds_certificate" -> "TDS certificate"
    "gst_invoice_pdf" -> "GST invoice (PDF)"
    "voice_note" -> "Voice note"
    "job_completion_otp" -> "Completion OTP"
    "parts_receipt" -> "Parts receipt"
    else -> kind.replace('_', ' ').replaceFirstChar { it.uppercase() }
}

/** "Added by …" label for the producer_kind; blank for null/unknown so the row omits it. */
internal fun producerKindLabel(kind: String?): String = when (kind) {
    "engineer" -> "By engineer"
    "hospital" -> "By hospital"
    "system" -> "By EquipSeva"
    "founder" -> "By EquipSeva"
    else -> ""
}

/** Compact byte size (1024-based): "820 B", "12.3 KB", "4.1 MB". */
internal fun formatBytes(bytes: Long): String {
    if (bytes < 1024) return "$bytes B"
    val kb = bytes / 1024.0
    if (kb < 1024) return "${round1(kb)} KB"
    val mb = kb / 1024.0
    if (mb < 1024) return "${round1(mb)} MB"
    return "${round1(mb / 1024.0)} GB"
}

/** First 10 hex chars of a SHA-256, for a glanceable fingerprint. */
internal fun shortHash(sha256: String): String =
    if (sha256.length <= 10) sha256 else sha256.substring(0, 10) + "…"

private fun round1(v: Double): String {
    val r = kotlin.math.round(v * 10.0) / 10.0
    return if (r % 1.0 == 0.0) r.toLong().toString() else r.toString()
}
