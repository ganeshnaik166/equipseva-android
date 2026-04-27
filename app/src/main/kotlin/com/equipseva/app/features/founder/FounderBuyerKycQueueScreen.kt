package com.equipseva.app.features.founder

import android.content.Intent
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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Inbox
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.net.toUri
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.designsystem.components.ESBackTopBar
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.theme.AccentLimeSoft
import com.equipseva.app.designsystem.theme.BrandGreenDeep
import com.equipseva.app.designsystem.theme.Ink500
import com.equipseva.app.designsystem.theme.Ink700
import com.equipseva.app.designsystem.theme.Ink900
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.designsystem.theme.Surface0
import com.equipseva.app.designsystem.theme.Surface200
import com.equipseva.app.designsystem.theme.Surface50
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

@HiltViewModel
class FounderBuyerKycQueueViewModel @Inject constructor(
    private val repo: FounderRepository,
) : ViewModel() {
    data class UiState(
        val loading: Boolean = true,
        val error: String? = null,
        val rows: List<FounderRepository.PendingBuyerKyc> = emptyList(),
        val sheetRequestId: String? = null,
        val sheetUserName: String? = null,
        val rejectMode: Boolean = false,
        val reasonDraft: String = "",
        val acting: Boolean = false,
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init { reload() }

    fun reload() {
        _state.update { it.copy(loading = true, error = null) }
        viewModelScope.launch {
            repo.fetchPendingBuyerKyc()
                .onSuccess { rows -> _state.update { it.copy(loading = false, rows = rows) } }
                .onFailure { e -> _state.update { it.copy(loading = false, error = e.toUserMessage()) } }
        }
    }

    fun openApprove(id: String, name: String) {
        _state.update { it.copy(sheetRequestId = id, sheetUserName = name, rejectMode = false, reasonDraft = "") }
    }

    fun openReject(id: String, name: String) {
        _state.update { it.copy(sheetRequestId = id, sheetUserName = name, rejectMode = true, reasonDraft = "") }
    }

    fun closeSheet() {
        if (_state.value.acting) return
        _state.update { it.copy(sheetRequestId = null, sheetUserName = null, rejectMode = false, reasonDraft = "") }
    }

    fun onReasonChange(v: String) {
        _state.update { it.copy(reasonDraft = v.take(500)) }
    }

    fun confirm() {
        val s = _state.value
        val id = s.sheetRequestId ?: return
        val target = if (s.rejectMode) "rejected" else "verified"
        if (s.rejectMode && s.reasonDraft.isBlank()) {
            _state.update { it.copy(error = "Reason required to reject") }
            return
        }
        _state.update { it.copy(acting = true, error = null) }
        viewModelScope.launch {
            repo.setBuyerKycStatus(id, target, s.reasonDraft.takeIf { it.isNotBlank() })
                .onSuccess {
                    _state.update {
                        it.copy(
                            acting = false,
                            sheetRequestId = null,
                            sheetUserName = null,
                            rejectMode = false,
                            reasonDraft = "",
                            rows = it.rows.filterNot { row -> row.requestId == id },
                        )
                    }
                }
                .onFailure { e -> _state.update { it.copy(acting = false, error = e.toUserMessage()) } }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FounderBuyerKycQueueScreen(
    onBack: () -> Unit,
    viewModel: FounderBuyerKycQueueViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsState()
    val context = LocalContext.current
    Scaffold(topBar = { ESBackTopBar(title = "Buyer KYC queue", onBack = onBack) }) { padding ->
        Box(modifier = Modifier.fillMaxSize().padding(padding)) {
            when {
                state.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }
                state.error != null && state.rows.isEmpty() -> EmptyStateView(
                    icon = Icons.Outlined.Inbox,
                    title = "Couldn't load",
                    subtitle = state.error,
                )
                state.rows.isEmpty() -> EmptyStateView(
                    icon = Icons.Outlined.Inbox,
                    title = "All clear",
                    subtitle = "No pending buyer KYC submissions.",
                )
                else -> LazyColumn(
                    modifier = Modifier.fillMaxSize().background(Surface50),
                    contentPadding = PaddingValues(Spacing.md),
                    verticalArrangement = Arrangement.spacedBy(Spacing.sm),
                ) {
                    items(state.rows, key = { it.requestId }) { row ->
                        BuyerKycRowCard(
                            row = row,
                            onView = {
                                runCatching {
                                    context.startActivity(Intent(Intent.ACTION_VIEW, row.docUrl.toUri()))
                                }
                            },
                            onApprove = { viewModel.openApprove(row.requestId, row.fullName) },
                            onReject = { viewModel.openReject(row.requestId, row.fullName) },
                        )
                    }
                }
            }
        }
    }

    if (state.sheetRequestId != null) {
        val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
        ModalBottomSheet(sheetState = sheetState, onDismissRequest = { viewModel.closeSheet() }) {
            Column(
                modifier = Modifier.fillMaxWidth().padding(Spacing.lg),
                verticalArrangement = Arrangement.spacedBy(Spacing.md),
            ) {
                Text(
                    if (state.rejectMode) "Reject ${state.sheetUserName}" else "Approve ${state.sheetUserName}",
                    fontSize = 18.sp, fontWeight = FontWeight.Bold, color = Ink900,
                )
                if (state.rejectMode) {
                    OutlinedTextField(
                        value = state.reasonDraft,
                        onValueChange = viewModel::onReasonChange,
                        label = { Text("Rejection reason (shown to buyer)") },
                        modifier = Modifier.fillMaxWidth(),
                        enabled = !state.acting,
                    )
                } else {
                    Text(
                        "Buyer can place orders immediately after approval.",
                        color = Ink500, fontSize = 13.sp,
                    )
                }
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
                    OutlinedButton(onClick = { viewModel.closeSheet() }, enabled = !state.acting, modifier = Modifier.weight(1f)) { Text("Cancel") }
                    Button(onClick = { viewModel.confirm() }, enabled = !state.acting, modifier = Modifier.weight(1f)) {
                        Text(if (state.acting) "…" else if (state.rejectMode) "Reject" else "Approve")
                    }
                }
            }
        }
    }
}

@Composable
private fun BuyerKycRowCard(
    row: FounderRepository.PendingBuyerKyc,
    onView: () -> Unit,
    onApprove: () -> Unit,
    onReject: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(Surface0)
            .border(1.dp, Surface200, RoundedCornerShape(14.dp))
            .padding(Spacing.md),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(row.fullName, color = Ink900, fontWeight = FontWeight.Bold, fontSize = 15.sp, modifier = Modifier.weight(1f))
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(50))
                    .background(AccentLimeSoft)
                    .padding(horizontal = 10.dp, vertical = 3.dp),
            ) {
                Text(prettyDocType(row.docType), color = BrandGreenDeep, fontSize = 11.sp, fontWeight = FontWeight.Bold)
            }
        }
        Text(
            listOfNotNull(row.email, row.phone).joinToString(" · ").ifBlank { "No contact" },
            color = Ink500, fontSize = 12.sp,
        )
        if (!row.gstNumber.isNullOrBlank()) {
            Text("GSTIN: ${row.gstNumber}", color = Ink700, fontSize = 12.sp, fontWeight = FontWeight.Medium)
        }
        Text("Submitted: ${row.submittedAt.take(10)}", color = Ink500, fontSize = 11.sp)
        Row(horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
            OutlinedButton(onClick = onView, modifier = Modifier.weight(1f).clickable(onClick = onView)) {
                Text("Open doc", fontSize = 12.sp)
            }
            Button(onClick = onApprove, modifier = Modifier.weight(1f)) { Text("Approve", fontSize = 12.sp) }
            OutlinedButton(onClick = onReject, modifier = Modifier.weight(1f)) { Text("Reject", fontSize = 12.sp) }
        }
    }
}

private fun prettyDocType(key: String): String = when (key) {
    "shop_registration" -> "Shop Reg"
    "gst" -> "GST"
    "drug_license" -> "Drug Lic"
    "mci" -> "MCI"
    "dci" -> "DCI"
    "medical_id" -> "Medical ID"
    else -> key
}
