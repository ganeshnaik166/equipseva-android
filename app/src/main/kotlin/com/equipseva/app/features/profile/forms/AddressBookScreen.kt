package com.equipseva.app.features.profile.forms

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
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.outlined.LocationOn
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.data.addresses.AddressRepository
import com.equipseva.app.designsystem.components.ESBackTopBar
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.theme.AccentLime
import com.equipseva.app.designsystem.theme.AccentLimeSoft
import com.equipseva.app.designsystem.theme.BrandGreen
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
class AddressBookViewModel @Inject constructor(
    private val repo: AddressRepository,
) : ViewModel() {
    data class UiState(
        val loading: Boolean = true,
        val error: String? = null,
        val rows: List<AddressRepository.UserAddress> = emptyList(),
        val acting: String? = null,
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init { reload() }

    fun reload() {
        _state.update { it.copy(loading = true, error = null) }
        viewModelScope.launch {
            repo.list()
                .onSuccess { rows -> _state.update { it.copy(loading = false, rows = rows) } }
                .onFailure { e -> _state.update { it.copy(loading = false, error = e.message ?: "Failed to load") } }
        }
    }

    fun setDefault(id: String) {
        if (_state.value.acting != null) return
        _state.update { it.copy(acting = id, error = null) }
        viewModelScope.launch {
            repo.setDefault(id)
                .onSuccess { reload() }
                .onFailure { e ->
                    _state.update { it.copy(acting = null, error = e.message ?: "Failed") }
                }
        }
    }

    fun delete(id: String) {
        if (_state.value.acting != null) return
        _state.update { it.copy(acting = id, error = null) }
        viewModelScope.launch {
            repo.delete(id)
                .onSuccess {
                    _state.update { it.copy(acting = null, rows = it.rows.filterNot { row -> row.id == id }) }
                }
                .onFailure { e ->
                    _state.update { it.copy(acting = null, error = e.message ?: "Failed") }
                }
        }
    }
}

@Composable
fun AddressBookScreen(
    onBack: () -> Unit,
    onAdd: () -> Unit,
    onEdit: (String) -> Unit,
    viewModel: AddressBookViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsState()
    Scaffold(
        topBar = { ESBackTopBar(title = "Saved addresses", onBack = onBack) },
        floatingActionButton = {
            FloatingActionButton(
                onClick = onAdd,
                containerColor = BrandGreen,
            ) {
                Icon(Icons.Filled.Add, contentDescription = "Add address", tint = Surface0)
            }
        },
    ) { padding ->
        Box(modifier = Modifier.fillMaxSize().padding(padding).background(Surface50)) {
            when {
                state.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }
                state.error != null && state.rows.isEmpty() -> EmptyStateView(
                    icon = Icons.Outlined.LocationOn,
                    title = "Couldn't load",
                    subtitle = state.error,
                )
                state.rows.isEmpty() -> EmptyStateView(
                    icon = Icons.Outlined.LocationOn,
                    title = "No saved addresses",
                    subtitle = "Tap + to add your first delivery address.",
                )
                else -> LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(Spacing.md),
                    verticalArrangement = Arrangement.spacedBy(Spacing.sm),
                ) {
                    items(state.rows, key = { it.id ?: it.line1 }) { row ->
                        AddressRowCard(
                            row = row,
                            actingThis = state.acting == row.id,
                            onEdit = { row.id?.let(onEdit) },
                            onDelete = { row.id?.let(viewModel::delete) },
                            onSetDefault = { row.id?.let(viewModel::setDefault) },
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun AddressRowCard(
    row: AddressRepository.UserAddress,
    actingThis: Boolean,
    onEdit: () -> Unit,
    onDelete: () -> Unit,
    onSetDefault: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(Surface0)
            .border(1.dp, Surface200, RoundedCornerShape(14.dp))
            .clickable(onClick = onEdit)
            .padding(Spacing.md),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                row.label?.takeIf { it.isNotBlank() } ?: "Address",
                color = Ink900,
                fontWeight = FontWeight.Bold,
                fontSize = 15.sp,
                modifier = Modifier.weight(1f),
            )
            if (row.isDefault) {
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(50))
                        .background(AccentLimeSoft)
                        .padding(horizontal = 10.dp, vertical = 3.dp),
                ) {
                    Text(
                        "Default",
                        color = BrandGreenDeep,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                    )
                }
            }
        }
        Text(row.fullName + " · " + row.phone, color = Ink700, fontSize = 13.sp)
        Text(
            listOfNotNull(row.line1, row.line2, row.landmark).joinToString(", "),
            color = Ink700,
            fontSize = 13.sp,
        )
        Text(
            "${row.city}, ${row.state} ${row.pincode}",
            color = Ink500,
            fontSize = 12.sp,
        )
        Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            if (!row.isDefault) {
                TextButton(onClick = onSetDefault, enabled = !actingThis) {
                    Text(
                        if (actingThis) "…" else "Make default",
                        fontSize = 12.sp,
                        color = AccentLime.let { _ ->
                            BrandGreen
                        },
                    )
                }
            }
            TextButton(onClick = onEdit, enabled = !actingThis) {
                Text("Edit", fontSize = 12.sp)
            }
            TextButton(onClick = onDelete, enabled = !actingThis) {
                Text("Delete", fontSize = 12.sp, color = androidx.compose.material3.MaterialTheme.colorScheme.error)
            }
        }
    }
}
