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
import androidx.compose.material.icons.outlined.Group
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.designsystem.components.ESBackTopBar
import com.equipseva.app.core.network.toUserMessage
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
        val error: String? = null,
        val rows: List<FounderRepository.UserRow> = emptyList(),
        val query: String = "",
        val selectedRole: String? = null,
        val acting: Boolean = false,
        val sheetUserId: String? = null,
        val sheetUserName: String? = null,
        val toast: String? = null,
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

    private fun fetch() {
        val s = _state.value
        _state.update { it.copy(loading = true, error = null) }
        viewModelScope.launch {
            repo.searchUsers(query = s.query, role = s.selectedRole, limit = 50, offset = 0)
                .onSuccess { rows -> _state.update { it.copy(loading = false, rows = rows) } }
                .onFailure { e -> _state.update { it.copy(loading = false, error = e.toUserMessage()) } }
        }
    }

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
                            toast = "Role updated to $newRole",
                        )
                    }
                    fetch()
                }
                .onFailure { e -> _state.update { it.copy(acting = false, error = e.toUserMessage()) } }
        }
    }

    fun clearToast() = _state.update { it.copy(toast = null) }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FounderUsersScreen(
    onBack: () -> Unit,
    viewModel: FounderUsersViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsState()
    Scaffold(topBar = { ESBackTopBar(title = "Users", onBack = onBack) }) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .background(Surface50),
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = Spacing.md, vertical = Spacing.sm),
                verticalArrangement = Arrangement.spacedBy(Spacing.sm),
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
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    FilterChip(
                        selected = state.selectedRole == null,
                        onClick = { viewModel.onRoleSelected(null) },
                        label = { Text("All") },
                        colors = FilterChipDefaults.filterChipColors(
                            selectedContainerColor = BrandGreen,
                            selectedLabelColor = Color.White,
                        ),
                    )
                    VALID_ROLES.forEach { role ->
                        FilterChip(
                            selected = state.selectedRole == role,
                            onClick = { viewModel.onRoleSelected(role) },
                            label = { Text(role.replace('_', ' ')) },
                            colors = FilterChipDefaults.filterChipColors(
                                selectedContainerColor = BrandGreen,
                                selectedLabelColor = Color.White,
                            ),
                        )
                    }
                }
            }

            Box(modifier = Modifier.fillMaxSize()) {
                when {
                    state.loading && state.rows.isEmpty() -> Box(
                        Modifier.fillMaxSize(),
                        contentAlignment = Alignment.Center,
                    ) { CircularProgressIndicator() }
                    state.error != null && state.rows.isEmpty() -> EmptyStateView(
                        icon = Icons.Outlined.Group,
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
                        contentPadding = PaddingValues(Spacing.md),
                        verticalArrangement = Arrangement.spacedBy(Spacing.sm),
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
                modifier = Modifier.fillMaxWidth().padding(Spacing.lg),
                verticalArrangement = Arrangement.spacedBy(Spacing.md),
            ) {
                Text(
                    text = "Change role · ${state.sheetUserName ?: "user"}",
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Bold,
                    color = Ink900,
                )
                Text(
                    text = "Pick the new role. This change is immediate.",
                    color = Ink500,
                    fontSize = 13.sp,
                )
                VALID_ROLES.forEach { role ->
                    Button(
                        onClick = { viewModel.onSetRole(state.sheetUserId!!, role) },
                        enabled = !state.acting,
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Text(if (state.acting) "…" else role.replace('_', ' '))
                    }
                }
                OutlinedButton(
                    onClick = { viewModel.closeSheet() },
                    enabled = !state.acting,
                    modifier = Modifier.fillMaxWidth(),
                ) { Text("Cancel") }
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
            .clip(RoundedCornerShape(14.dp))
            .background(Surface0)
            .border(1.dp, Surface200, RoundedCornerShape(14.dp))
            .padding(Spacing.md),
        verticalArrangement = Arrangement.spacedBy(6.dp),
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
                        text = row.fullName ?: "(no name)",
                        fontWeight = FontWeight.Bold,
                        color = Ink900,
                    )
                    Box(
                        modifier = Modifier
                            .size(8.dp)
                            .clip(CircleShape)
                            .background(if (row.isActive) BrandGreen else ErrorRed),
                    )
                }
                Text(
                    text = listOfNotNull(row.email, row.phone).joinToString(" · ").ifBlank { "no contact" },
                    color = Ink500,
                    fontSize = 12.sp,
                )
            }
            IconButton(onClick = onChangeRole) {
                Icon(Icons.Filled.Edit, contentDescription = "Change role", tint = BrandGreen)
            }
        }
        RoleChip(role = row.role)
    }
}

@Composable
private fun RoleChip(role: String?) {
    val label = role ?: "unknown"
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(999.dp))
            .background(Surface50)
            .border(1.dp, Surface200, RoundedCornerShape(999.dp))
            .padding(horizontal = 10.dp, vertical = 3.dp),
    ) {
        Text(
            text = label.replace('_', ' '),
            color = Ink700,
            fontSize = 11.sp,
            fontWeight = FontWeight.Medium,
        )
    }
}
