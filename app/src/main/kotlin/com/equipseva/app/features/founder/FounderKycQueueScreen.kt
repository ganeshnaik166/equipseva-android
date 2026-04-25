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
import com.equipseva.app.designsystem.components.ESBackTopBar
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.theme.BrandGreen
import com.equipseva.app.designsystem.theme.BrandGreenDark
import com.equipseva.app.designsystem.theme.ErrorRed
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
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Inbox

@HiltViewModel
class FounderKycQueueViewModel @Inject constructor(
    private val repo: FounderRepository,
) : ViewModel() {
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
                .onSuccess { rows -> _state.update { it.copy(loading = false, rows = rows) } }
                .onFailure { e -> _state.update { it.copy(loading = false, error = e.message ?: "Failed to load") } }
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
                .onFailure { e -> _state.update { it.copy(acting = false, error = e.message ?: "Failed") } }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FounderKycQueueScreen(
    onBack: () -> Unit,
    viewModel: FounderKycQueueViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsState()
    Scaffold(topBar = { ESBackTopBar(title = "KYC queue", onBack = onBack) }) { padding ->
        Box(modifier = Modifier.fillMaxSize().padding(padding)) {
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
                    modifier = Modifier.fillMaxSize().background(Surface50),
                    contentPadding = androidx.compose.foundation.layout.PaddingValues(Spacing.md),
                    verticalArrangement = Arrangement.spacedBy(Spacing.sm),
                ) {
                    items(state.rows, key = { it.userId }) { row ->
                        EngineerRow(
                            row = row,
                            onApprove = { viewModel.openApprove(row.userId, row.fullName) },
                            onReject = { viewModel.openReject(row.userId, row.fullName) },
                        )
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
                modifier = Modifier.fillMaxWidth().padding(Spacing.lg),
                verticalArrangement = Arrangement.spacedBy(Spacing.md),
            ) {
                Text(
                    if (state.rejectMode) "Reject ${state.sheetUserName}" else "Approve ${state.sheetUserName}",
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Bold,
                    color = Ink900,
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
                        color = Ink500,
                        fontSize = 13.sp,
                    )
                }
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
                ) {
                    OutlinedButton(
                        onClick = { viewModel.closeSheet() },
                        enabled = !state.acting,
                        modifier = Modifier.weight(1f),
                    ) { Text("Cancel") }
                    Button(
                        onClick = { viewModel.confirm() },
                        enabled = !state.acting,
                        modifier = Modifier.weight(1f),
                    ) {
                        Text(if (state.acting) "…" else if (state.rejectMode) "Reject" else "Approve")
                    }
                }
            }
        }
    }
}

@Composable
private fun EngineerRow(
    row: FounderRepository.PendingEngineer,
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
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Box(
                modifier = Modifier
                    .size(40.dp)
                    .clip(CircleShape)
                    .background(BrandGreenDark),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = row.fullName.firstOrNull()?.uppercaseChar()?.toString() ?: "E",
                    color = androidx.compose.ui.graphics.Color.White,
                    fontWeight = FontWeight.Bold,
                )
            }
            Column(modifier = Modifier.weight(1f)) {
                Text(row.fullName, fontWeight = FontWeight.Bold, color = Ink900)
                Text(
                    listOfNotNull(row.email, row.phone).joinToString(" · ").ifBlank { "No contact" },
                    color = Ink500,
                    fontSize = 12.sp,
                )
            }
        }
        val locationLine = listOfNotNull(row.city, row.state).joinToString(", ").ifBlank { null }
        val metaLine = listOfNotNull(
            row.experienceYears?.let { "$it yrs exp" },
            row.serviceRadiusKm?.let { "${it}km radius" },
            locationLine,
        ).joinToString(" · ")
        if (metaLine.isNotBlank()) {
            Text(metaLine, color = Ink700, fontSize = 13.sp)
        }
        Row(horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
            Button(
                onClick = onApprove,
                modifier = Modifier.weight(1f),
            ) { Text("Approve") }
            OutlinedButton(
                onClick = onReject,
                modifier = Modifier.weight(1f),
            ) { Text("Reject") }
        }
    }
}
