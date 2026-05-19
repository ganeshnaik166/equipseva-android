package com.equipseva.app.features.founder

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.outlined.ErrorOutline
import androidx.compose.material.icons.outlined.Group
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
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
import com.equipseva.app.designsystem.components.EsChip
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.components.Pill
import com.equipseva.app.designsystem.components.PillKind
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.Paper2
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaDanger500
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaGreen900
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk700
import com.equipseva.app.designsystem.theme.SevaInk900
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

private val VALID_ROLES = listOf(
    "hospital_admin",
    "engineer",
    "supplier",
    "manufacturer",
    "logistics",
)

@HiltViewModel
class FounderUsersViewModel @Inject constructor(
    private val repo: FounderRepository,
) : ViewModel() {
    data class UiState(
        val loading: Boolean = true,
        // Round 380 — pull-to-refresh inline indicator distinct from
        // the cold-load spinner.
        val refreshing: Boolean = false,
        val error: String? = null,
        val rows: List<FounderRepository.UserRow> = emptyList(),
        val query: String = "",
        val selectedRole: String? = null,
        val acting: Boolean = false,
        val sheetUserId: String? = null,
        val sheetUserName: String? = null,
    )
    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()
    private var debounceJob: Job? = null

    init { fetch() }

    fun onQueryChange(q: String) {
        _state.update { it.copy(query = q) }
        debounceJob?.cancel()
        debounceJob = viewModelScope.launch {
            delay(300)
            fetch()
        }
    }

    fun onRoleSelected(role: String?) {
        _state.update { it.copy(selectedRole = role) }
        fetch()
    }

    private fun fetch(refreshing: Boolean = false) {
        val s = _state.value
        _state.update {
            it.copy(
                loading = !refreshing && it.rows.isEmpty(),
                refreshing = refreshing,
                error = null,
            )
        }
        viewModelScope.launch {
            repo.searchUsers(query = s.query, role = s.selectedRole, limit = 50, offset = 0)
                .onSuccess { rows ->
                    // Honest empty state — DUMMY_USERS fallback removed
                    // 2026-05-08 e2e QA so the founder users surface
                    // doesn't lie when the platform genuinely has no
                    // matches for the current filter.
                    _state.update { it.copy(loading = false, refreshing = false, rows = rows) }
                }
                .onFailure { ex ->
                    _state.update {
                        it.copy(
                            loading = false,
                            refreshing = false,
                            rows = emptyList(),
                            error = ex.toUserMessage(),
                        )
                    }
                }
        }
    }

    fun onPullToRefresh() = fetch(refreshing = true)

    fun openRoleSheet(userId: String, name: String?) {
        if (_state.value.acting) return
        _state.update { it.copy(sheetUserId = userId, sheetUserName = name) }
    }

    fun closeSheet() {
        if (_state.value.acting) return
        _state.update { it.copy(sheetUserId = null, sheetUserName = null) }
    }

    fun onSetRole(userId: String, newRole: String) {
        _state.update { it.copy(acting = true, error = null) }
        viewModelScope.launch {
            repo.forceRoleChange(userId, newRole)
                .onSuccess {
                    _state.update {
                        it.copy(
                            acting = false,
                            sheetUserId = null,
                            sheetUserName = null,
                        )
                    }
                    fetch()
                }
                .onFailure { e -> _state.update { it.copy(acting = false, error = e.toUserMessage()) } }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FounderUsersScreen(
    onBack: () -> Unit,
    viewModel: FounderUsersViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(title = "Users", onBack = onBack)
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 8.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                OutlinedTextField(
                    value = state.query,
                    onValueChange = viewModel::onQueryChange,
                    label = { Text("Search name, email, phone") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .horizontalScroll(rememberScrollState()),
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    EsChip(
                        text = "All",
                        active = state.selectedRole == null,
                        onClick = { viewModel.onRoleSelected(null) },
                    )
                    VALID_ROLES.forEach { role ->
                        EsChip(
                            text = role.replace('_', ' '),
                            active = state.selectedRole == role,
                            onClick = { viewModel.onRoleSelected(role) },
                        )
                    }
                }
            }

            // Round 380 — pull-to-refresh on the Users list. Matches
            // r378/r379 pattern.
            androidx.compose.material3.pulltorefresh.PullToRefreshBox(
                isRefreshing = state.refreshing,
                onRefresh = viewModel::onPullToRefresh,
                modifier = Modifier.fillMaxSize(),
            ) {
                when {
                    state.loading && state.rows.isEmpty() -> Box(
                        Modifier.fillMaxSize(),
                        contentAlignment = Alignment.Center,
                    ) { CircularProgressIndicator() }
                    state.error != null && state.rows.isEmpty() -> EmptyStateView(
                        icon = Icons.Outlined.ErrorOutline,
                        title = "Couldn't load",
                        subtitle = state.error,
                    )
                    state.rows.isEmpty() -> EmptyStateView(
                        icon = Icons.Outlined.Group,
                        title = "No matches",
                        subtitle = "Adjust the search or role filter",
                    )
                    else -> LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(12.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        items(state.rows, key = { it.userId }) { row ->
                            UserRow(
                                row = row,
                                onChangeRole = { viewModel.openRoleSheet(row.userId, row.fullName) },
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
                    text = "Change role · ${state.sheetUserName ?: "user"}",
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Bold,
                    color = SevaInk900,
                )
                Text(
                    text = "Pick the new role. This change is immediate.",
                    color = SevaInk500,
                    fontSize = 13.sp,
                )
                VALID_ROLES.forEach { role ->
                    EsBtn(
                        text = if (state.acting) "…" else role.replace('_', ' '),
                        onClick = { viewModel.onSetRole(state.sheetUserId!!, role) },
                        kind = EsBtnKind.Primary,
                        full = true,
                        disabled = state.acting,
                    )
                }
                EsBtn(
                    text = "Cancel",
                    onClick = { viewModel.closeSheet() },
                    kind = EsBtnKind.Secondary,
                    full = true,
                    disabled = state.acting,
                )
            }
        }
    }
}

@Composable
private fun UserRow(
    row: FounderRepository.UserRow,
    onChangeRole: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
            .padding(12.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
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
                    text = row.fullName?.firstOrNull()?.uppercaseChar()?.toString()
                        ?: row.email?.firstOrNull()?.uppercaseChar()?.toString()
                        ?: "?",
                    color = Color.White,
                    fontWeight = FontWeight.Bold,
                )
            }
            Column(modifier = Modifier.weight(1f)) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(
                        text = row.fullName?.takeIf { it.isNotBlank() }
                            ?: row.email
                            ?: row.phone
                            ?: "User · ${row.userId.take(8)}",
                        fontWeight = FontWeight.Bold,
                        color = SevaInk900,
                    )
                    Box(
                        modifier = Modifier
                            .size(8.dp)
                            .clip(CircleShape)
                            .background(if (row.isActive) SevaGreen700 else SevaDanger500),
                    )
                }
                Text(
                    text = listOfNotNull(row.email, row.phone).joinToString(" · ").ifBlank { "no contact" },
                    color = SevaInk500,
                    fontSize = 12.sp,
                )
            }
            IconButton(onClick = onChangeRole) {
                Icon(Icons.Filled.Edit, contentDescription = "Change role", tint = SevaGreen700)
            }
        }
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            RoleChip(role = row.role)
            // Round 367 — surface device-integrity risk on the Users
            // queue. Mirror of r351 Payments badge so the founder can
            // spot risky users at a glance regardless of which surface
            // they're inspecting.
            if (row.failedIntegrityCount > 0) {
                Pill(
                    text = "⚠ ${row.failedIntegrityCount} integrity",
                    kind = PillKind.Danger,
                )
            }
        }
    }
}

@Composable
private fun RoleChip(role: String?) {
    val label = role ?: "unknown"
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(999.dp))
            .background(Paper2)
            .padding(horizontal = 10.dp, vertical = 3.dp),
    ) {
        Text(
            text = label.replace('_', ' '),
            color = SevaInk700,
            fontSize = 11.sp,
            fontWeight = FontWeight.Medium,
        )
    }
}

