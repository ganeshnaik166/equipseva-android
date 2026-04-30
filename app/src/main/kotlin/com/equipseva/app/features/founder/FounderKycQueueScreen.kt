package com.equipseva.app.features.founder

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
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.EsBtn
import com.equipseva.app.designsystem.components.EsBtnKind
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.components.Pill
import com.equipseva.app.designsystem.components.PillKind
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaGreen900
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
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Inbox

@HiltViewModel
class FounderKycQueueViewModel @Inject constructor(
    private val repo: FounderRepository,
    private val storage: com.equipseva.app.core.storage.StorageRepository,
) : ViewModel() {

    suspend fun signedUrlFor(path: String): Result<String> = runCatching {
        storage.signedUrl(
            bucket = com.equipseva.app.core.storage.StorageRepository.Buckets.KYC_DOCS,
            path = path,
            expiresInMinutes = 60,
        )
    }

    data class UiState(
        val loading: Boolean = true,
        val error: String? = null,
        val rows: List<FounderRepository.PendingEngineer> = emptyList(),
        val sheetUserId: String? = null,
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
            repo.fetchPendingEngineers()
                .onSuccess { rows ->
                    // Honest empty state on success — Buyer KYC queue
                    // already shows "All clear" when nothing is pending,
                    // so don't fake 3 dummy rows here either.
                    _state.update { it.copy(loading = false, rows = rows) }
                }
                .onFailure { ex ->
                    _state.update {
                        it.copy(
                            loading = false,
                            rows = emptyList(),
                            error = ex.toUserMessage(),
                        )
                    }
                }
        }
    }
    fun openApprove(userId: String, name: String) {
        _state.update { it.copy(sheetUserId = userId, sheetUserName = name, rejectMode = false, reasonDraft = "") }
    }
    fun openReject(userId: String, name: String) {
        _state.update { it.copy(sheetUserId = userId, sheetUserName = name, rejectMode = true, reasonDraft = "") }
    }
    fun closeSheet() {
        if (_state.value.acting) return
        _state.update { it.copy(sheetUserId = null, sheetUserName = null, rejectMode = false, reasonDraft = "") }
    }
    fun onReasonChange(value: String) {
        _state.update { it.copy(reasonDraft = value.take(500)) }
    }
    fun confirm() {
        val s = _state.value
        val userId = s.sheetUserId ?: return
        val target = if (s.rejectMode) "rejected" else "verified"
        if (s.rejectMode && s.reasonDraft.isBlank()) {
            _state.update { it.copy(error = "Reason required to reject") }
            return
        }
        _state.update { it.copy(acting = true, error = null) }
        viewModelScope.launch {
            repo.setEngineerVerification(userId, target, s.reasonDraft.takeIf { it.isNotBlank() })
                .onSuccess {
                    _state.update {
                        it.copy(
                            acting = false,
                            sheetUserId = null,
                            sheetUserName = null,
                            rejectMode = false,
                            reasonDraft = "",
                            rows = it.rows.filterNot { row -> row.userId == userId },
                        )
                    }
                }
                .onFailure { e -> _state.update { it.copy(acting = false, error = e.toUserMessage()) } }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FounderKycQueueScreen(
    onBack: () -> Unit,
    onOpenReview: (userId: String) -> Unit = {},
    viewModel: FounderKycQueueViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsState()
    val context = androidx.compose.ui.platform.LocalContext.current
    val scope = androidx.compose.runtime.rememberCoroutineScope()
    val openDoc: (FounderRepository.PendingEngineer.DocRef) -> Unit = { doc ->
        scope.launch {
            viewModel.signedUrlFor(doc.path)
                .onSuccess { url ->
                    runCatching {
                        context.startActivity(
                            android.content.Intent(
                                android.content.Intent.ACTION_VIEW,
                                android.net.Uri.parse(url),
                            ),
                        )
                    }
                }
        }
    }
    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(
                title = "KYC queue",
                subtitle = if (state.rows.isNotEmpty()) "${state.rows.size} pending" else null,
                onBack = onBack,
            )
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
                    state.rows.isEmpty() -> EmptyStateView(
                        icon = Icons.Outlined.Inbox,
                        title = "All clear",
                        subtitle = "No pending engineer verifications.",
                    )
                    else -> LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = androidx.compose.foundation.layout.PaddingValues(12.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        items(state.rows, key = { it.userId }) { row ->
                            EngineerRow(
                                row = row,
                                onClick = { onOpenReview(row.userId) },
                                onApprove = { viewModel.openApprove(row.userId, row.fullName) },
                                onReject = { viewModel.openReject(row.userId, row.fullName) },
                                onViewDoc = openDoc,
                            )
                        }
                    }
                }
            }
        }
    }

    if (state.sheetUserId != null) {
        val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
        ModalBottomSheet(
            sheetState = sheetState,
            onDismissRequest = { viewModel.closeSheet() },
        ) {
            Column(
                modifier = Modifier.fillMaxWidth().padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Text(
                    if (state.rejectMode) "Reject ${state.sheetUserName}" else "Approve ${state.sheetUserName}",
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Bold,
                    color = SevaInk900,
                )
                if (state.rejectMode) {
                    OutlinedTextField(
                        value = state.reasonDraft,
                        onValueChange = viewModel::onReasonChange,
                        label = { Text("Reason") },
                        modifier = Modifier.fillMaxWidth(),
                        enabled = !state.acting,
                    )
                } else {
                    Text(
                        "Engineer can take repair jobs immediately after approval.",
                        color = SevaInk500,
                        fontSize = 13.sp,
                    )
                }
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Box(modifier = Modifier.weight(1f)) {
                        EsBtn(
                            text = "Cancel",
                            onClick = { viewModel.closeSheet() },
                            kind = EsBtnKind.Secondary,
                            full = true,
                            disabled = state.acting,
                        )
                    }
                    Box(modifier = Modifier.weight(1f)) {
                        EsBtn(
                            text = if (state.acting) "…" else if (state.rejectMode) "Reject" else "Approve",
                            onClick = { viewModel.confirm() },
                            kind = if (state.rejectMode) EsBtnKind.Danger else EsBtnKind.Primary,
                            full = true,
                            disabled = state.acting,
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun EngineerRow(
    row: FounderRepository.PendingEngineer,
    onClick: () -> Unit,
    onApprove: () -> Unit,
    onReject: () -> Unit,
    onViewDoc: (FounderRepository.PendingEngineer.DocRef) -> Unit = {},
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(androidx.compose.ui.graphics.Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
            .clickable(onClick = onClick)
            .padding(12.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Box(
                modifier = Modifier
                    .size(40.dp)
                    .clip(CircleShape)
                    .background(SevaGreen900),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = row.fullName.firstOrNull()?.uppercaseChar()?.toString() ?: "E",
                    color = androidx.compose.ui.graphics.Color.White,
                    fontWeight = FontWeight.Bold,
                )
            }
            Column(modifier = Modifier.weight(1f)) {
                Text(row.fullName, fontWeight = FontWeight.Bold, color = SevaInk900)
                Text(
                    listOfNotNull(row.email, row.phone).joinToString(" · ").ifBlank { "No contact" },
                    color = SevaInk500,
                    fontSize = 12.sp,
                )
            }
            Pill(text = "Review", kind = PillKind.Warn)
        }
        val locationLine = listOfNotNull(row.city, row.state).joinToString(", ").ifBlank { null }
        val metaLine = listOfNotNull(
            row.experienceYears?.let { "$it yrs exp" },
            row.serviceRadiusKm?.let { "${it}km radius" },
            locationLine,
        ).joinToString(" · ")
        if (metaLine.isNotBlank()) {
            Text(metaLine, color = SevaInk700, fontSize = 13.sp)
        }
        val docs = row.docPaths()
        if (docs.isNotEmpty()) {
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                docs.take(4).forEach { doc ->
                    Box(modifier = Modifier.weight(1f)) {
                        EsBtn(
                            text = "Open ${doc.displayLabel}",
                            onClick = { onViewDoc(doc) },
                            kind = EsBtnKind.Secondary,
                            full = true,
                        )
                    }
                }
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Box(modifier = Modifier.weight(1f)) {
                EsBtn(
                    text = "Approve",
                    onClick = onApprove,
                    kind = EsBtnKind.Primary,
                    full = true,
                )
            }
            Box(modifier = Modifier.weight(1f)) {
                EsBtn(
                    text = "Reject",
                    onClick = onReject,
                    kind = EsBtnKind.DangerOutline,
                    full = true,
                )
            }
        }
    }
}

private val DUMMY_PENDING_ENGINEERS = listOf(
    FounderRepository.PendingEngineer(
        userId = "dummy-pending-1",
        fullName = "Manoj Kumar",
        email = "manoj.kumar@example.com",
        phone = "+91 98••• ••101",
        verificationStatus = "pending",
        experienceYears = 5,
        serviceRadiusKm = 30,
        city = "Nalgonda",
        state = "Telangana",
        certificates = null,
        aadhaarVerified = true,
        createdAt = java.time.Instant.now().minusSeconds(3600 * 4).toString(),
    ),
    FounderRepository.PendingEngineer(
        userId = "dummy-pending-2",
        fullName = "Sruthi Rao",
        email = "sruthi.rao@example.com",
        phone = "+91 98••• ••202",
        verificationStatus = "pending",
        experienceYears = 8,
        serviceRadiusKm = 40,
        city = "Hyderabad",
        state = "Telangana",
        certificates = null,
        aadhaarVerified = true,
        createdAt = java.time.Instant.now().minusSeconds(3600 * 18).toString(),
    ),
    FounderRepository.PendingEngineer(
        userId = "dummy-pending-3",
        fullName = "Vivek Anand",
        email = "vivek@example.com",
        phone = "+91 98••• ••303",
        verificationStatus = "pending",
        experienceYears = 3,
        serviceRadiusKm = 25,
        city = "Suryapet",
        state = "Telangana",
        certificates = null,
        aadhaarVerified = false,
        createdAt = java.time.Instant.now().minusSeconds(3600 * 30).toString(),
    ),
)
