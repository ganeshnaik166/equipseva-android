package com.equipseva.app.features.founder

import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.material.icons.automirrored.outlined.ReceiptLong
import androidx.compose.material3.CircularProgressIndicator
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
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.data.founder.FounderRefundRepository
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.core.util.formatRupees
import com.equipseva.app.core.util.prettyDate
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.EsBottomSheet
import com.equipseva.app.designsystem.components.EsBtn
import com.equipseva.app.designsystem.components.EsBtnKind
import com.equipseva.app.designsystem.components.EsBtnSize
import com.equipseva.app.designsystem.components.EsField
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaDanger500
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk700
import com.equipseva.app.designsystem.theme.SevaInk900
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

@HiltViewModel
class FounderRefundApprovalsViewModel @Inject constructor(
    private val repo: FounderRefundRepository,
) : ViewModel() {
    data class UiState(
        val loading: Boolean = true,
        val error: String? = null,
        val requests: List<FounderRefundRepository.RefundRequest> = emptyList(),
        val working: Boolean = false,
        val actionError: String? = null,
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init { reload() }

    fun reload() {
        _state.update { it.copy(loading = it.requests.isEmpty(), error = null) }
        viewModelScope.launch {
            repo.pending()
                .onSuccess { list -> _state.update { it.copy(loading = false, requests = list) } }
                .onFailure { e -> _state.update { it.copy(loading = false, error = e.toUserMessage()) } }
        }
    }

    fun clearActionError() = _state.update { it.copy(actionError = null) }

    fun approve(requestId: String, note: String, onDone: () -> Unit) =
        run(onDone) { repo.approve(requestId, note) }

    fun reject(requestId: String, reason: String, onDone: () -> Unit) =
        run(onDone) { repo.reject(requestId, reason) }

    private fun run(onDone: () -> Unit, block: suspend () -> Result<Unit>) {
        _state.update { it.copy(working = true, actionError = null) }
        viewModelScope.launch {
            block()
                .onSuccess {
                    _state.update { it.copy(working = false, actionError = null) }
                    onDone()
                    reload()
                }
                .onFailure { e -> _state.update { it.copy(working = false, actionError = e.toUserMessage()) } }
        }
    }
}

private enum class RefundAction { Approve, Reject }

/**
 * Founder refund-authorization approvals (r1423): the pending queue from
 * founder_pending_refund_authorizations, with per-request approve (optional
 * note) and reject (reason >= 5 chars) actions backed by
 * approve_refund_authorization / reject_refund_authorization. Founder-gated
 * server-side; reached from the founder business cockpit.
 */
@Composable
fun FounderRefundApprovalsScreen(
    onBack: () -> Unit,
    viewModel: FounderRefundApprovalsViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    com.equipseva.app.designsystem.util.RefreshOnReturn { viewModel.reload() }

    var actionFor by rememberSaveable { mutableStateOf<String?>(null) }
    var actionMode by rememberSaveable { mutableStateOf(RefundAction.Approve) }

    actionFor?.let { requestId ->
        val req = state.requests.firstOrNull { it.id == requestId }
        RefundActionSheet(
            mode = actionMode,
            amountLabel = req?.let { formatRupees(it.amountRupees) } ?: "",
            working = state.working,
            error = state.actionError,
            onClose = {
                actionFor = null
                viewModel.clearActionError()
            },
            onSubmit = { text ->
                when (actionMode) {
                    RefundAction.Approve -> viewModel.approve(requestId, text) { actionFor = null }
                    RefundAction.Reject -> viewModel.reject(requestId, text) { actionFor = null }
                }
            },
        )
    }

    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(title = "Refund approvals", onBack = onBack)
            when {
                state.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }
                state.error != null -> EmptyStateView(
                    icon = Icons.AutoMirrored.Outlined.ReceiptLong,
                    title = "Couldn't load approvals",
                    subtitle = state.error,
                    ctaLabel = "Try again",
                    onCta = { viewModel.reload() },
                )
                state.requests.isEmpty() -> EmptyStateView(
                    icon = Icons.AutoMirrored.Outlined.ReceiptLong,
                    title = "No pending refunds",
                    subtitle = "Refund-authorization requests awaiting your decision appear here.",
                )
                else -> LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(12.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    items(state.requests, key = { it.id }) { req ->
                        RefundCard(
                            req = req,
                            onApprove = { actionMode = RefundAction.Approve; actionFor = req.id },
                            onReject = { actionMode = RefundAction.Reject; actionFor = req.id },
                        )
                    }
                    item(key = "tail") { Spacer(Modifier.height(8.dp)) }
                }
            }
        }
    }
}

@Composable
private fun RefundCard(
    req: FounderRefundRepository.RefundRequest,
    onApprove: () -> Unit,
    onReject: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
            .padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(formatRupees(req.amountRupees), style = EsType.H5.copy(fontWeight = FontWeight.Bold), color = SevaInk900)
            Text(refundSourceLabel(req.sourceKind), style = EsType.Caption, color = SevaInk500)
        }
        req.reason?.takeIf { it.isNotBlank() }?.let {
            Text(it, style = EsType.BodySm, color = SevaInk700)
        }
        req.requesterEmail?.takeIf { it.isNotBlank() }?.let {
            Text("Requested by $it", style = EsType.Caption, color = SevaInk500)
        }
        req.expiresAt?.takeIf { it.isNotBlank() }?.let {
            Text("Expires ${prettyDate(it)}", style = EsType.Caption, color = SevaInk500)
        }
        Row(
            modifier = Modifier.fillMaxWidth().padding(top = 4.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            EsBtn(
                text = "Reject",
                onClick = onReject,
                kind = EsBtnKind.DangerOutline,
                size = EsBtnSize.Sm,
                modifier = Modifier.weight(1f),
            )
            EsBtn(
                text = "Approve",
                onClick = onApprove,
                kind = EsBtnKind.Primary,
                size = EsBtnSize.Sm,
                modifier = Modifier.weight(1f),
            )
        }
    }
}

@Composable
private fun RefundActionSheet(
    mode: RefundAction,
    amountLabel: String,
    working: Boolean,
    error: String?,
    onClose: () -> Unit,
    onSubmit: (text: String) -> Unit,
) {
    var text by rememberSaveable(mode) { mutableStateOf("") }
    val isReject = mode == RefundAction.Reject
    EsBottomSheet(
        onClose = onClose,
        title = if (isReject) "Reject refund" else "Approve refund",
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text(
                if (isReject) {
                    "Rejecting $amountLabel. Give a reason (at least 5 characters) — it's recorded on the request."
                } else {
                    "Approving $amountLabel. You can add an optional note for the audit trail."
                },
                style = EsType.BodySm,
                color = SevaInk700,
            )
            EsField(
                value = text,
                onChange = { text = it },
                label = if (isReject) "Reject reason" else "Note (optional)",
                placeholder = if (isReject) "e.g. Duplicate request" else "e.g. Verified with hospital",
                imeAction = ImeAction.Done,
            )
            if (error != null) {
                Text(error, style = EsType.BodySm, color = SevaDanger500)
            }
            EsBtn(
                text = when {
                    working -> "Working…"
                    isReject -> "Confirm reject"
                    else -> "Confirm approve"
                },
                onClick = { onSubmit(text) },
                kind = if (isReject) EsBtnKind.DangerOutline else EsBtnKind.Primary,
                size = EsBtnSize.Lg,
                full = true,
                disabled = working || (isReject && !isValidRejectReason(text)),
            )
            Spacer(Modifier.height(4.dp))
        }
    }
}

// ---------------------------------------------------------------------
//  Pinned helpers
// ---------------------------------------------------------------------

/** Reject reason must be >= 5 trimmed chars (mirrors the server guard). */
internal fun isValidRejectReason(reason: String): Boolean = reason.trim().length >= 5

/** Refund source_kind → human label: de-snake + capitalise. */
internal fun refundSourceLabel(kind: String): String =
    kind.trim().replace('_', ' ').replaceFirstChar { it.uppercase() }.ifBlank { "Refund" }
