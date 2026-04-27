package com.equipseva.app.features.repair.directory

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
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Engineering
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.Verified
import androidx.compose.material.icons.outlined.Inbox
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
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
import coil3.compose.AsyncImage
import com.equipseva.app.core.data.engineers.EngineerDirectoryRepository
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
import kotlinx.coroutines.FlowPreview
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.debounce
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.drop
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

@OptIn(FlowPreview::class)
@HiltViewModel
class EngineerDirectoryViewModel @Inject constructor(
    private val repo: EngineerDirectoryRepository,
) : ViewModel() {
    data class UiState(
        val loading: Boolean = true,
        val error: String? = null,
        val query: String = "",
        val rows: List<EngineerDirectoryRepository.DirectoryRow> = emptyList(),
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init {
        refresh()
        _state
            .map { it.query }
            .distinctUntilChanged()
            .drop(1)
            .debounce(300L)
            .onEach { refresh() }
            .launchIn(viewModelScope)
    }

    fun onQueryChange(v: String) = _state.update { it.copy(query = v) }

    private fun refresh() {
        _state.update { it.copy(loading = true, error = null) }
        viewModelScope.launch {
            repo.search(query = _state.value.query.takeIf { it.isNotBlank() })
                .onSuccess { rows -> _state.update { it.copy(loading = false, rows = rows) } }
                .onFailure { e -> _state.update { it.copy(loading = false, error = e.message ?: "Failed to load") } }
        }
    }
}

@Composable
fun EngineerDirectoryScreen(
    onBack: () -> Unit,
    onOpenProfile: (engineerId: String) -> Unit,
    onAnyEngineer: () -> Unit,
    viewModel: EngineerDirectoryViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsState()
    Scaffold(topBar = { ESBackTopBar(title = "Book a repairman", onBack = onBack) }) { padding ->
        Column(modifier = Modifier.fillMaxSize().padding(padding).background(Surface50)) {
            OutlinedTextField(
                value = state.query,
                onValueChange = viewModel::onQueryChange,
                placeholder = { Text("Search by name, brand, district…") },
                singleLine = true,
                leadingIcon = { Icon(Icons.Filled.Search, contentDescription = null) },
                modifier = Modifier.fillMaxWidth().padding(Spacing.md),
            )
            // Big "skip the comparison" CTA. Hospitals who don't want to browse
            // engineer-by-engineer post one job that gets broadcast to all
            // verified engineers in the area; first to accept wins.
            OutlinedButton(
                onClick = onAnyEngineer,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = Spacing.md, vertical = 4.dp)
                    .height(56.dp),
                shape = RoundedCornerShape(14.dp),
                border = androidx.compose.foundation.BorderStroke(2.dp, AccentLime),
                colors = ButtonDefaults.outlinedButtonColors(
                    containerColor = AccentLimeSoft,
                ),
            ) {
                Icon(
                    imageVector = Icons.Filled.Engineering,
                    contentDescription = null,
                    tint = BrandGreen,
                    modifier = Modifier.size(20.dp),
                )
                Text(
                    text = "  Skip comparison — request from any verified engineer",
                    fontSize = 14.sp,
                    color = BrandGreen,
                    fontWeight = androidx.compose.ui.text.font.FontWeight.SemiBold,
                )
            }
            Box(modifier = Modifier.fillMaxSize()) {
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
                        icon = Icons.Filled.Engineering,
                        title = "No verified engineers yet",
                        subtitle = "Try a different search or request from any engineer.",
                    )
                    else -> LazyColumn(
                        contentPadding = PaddingValues(Spacing.md),
                        verticalArrangement = Arrangement.spacedBy(Spacing.sm),
                    ) {
                        items(state.rows, key = { it.engineerId }) { row ->
                            EngineerCard(row = row, onClick = { onOpenProfile(row.engineerId) })
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun EngineerCard(
    row: EngineerDirectoryRepository.DirectoryRow,
    onClick: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(Surface0)
            .border(1.dp, Surface200, RoundedCornerShape(14.dp))
            .clickable(onClick = onClick)
            .padding(Spacing.md),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.Top,
    ) {
        Box(
            modifier = Modifier
                .size(56.dp)
                .clip(CircleShape)
                .background(AccentLimeSoft),
            contentAlignment = Alignment.Center,
        ) {
            val img = row.avatarUrl
            if (!img.isNullOrBlank()) {
                AsyncImage(
                    model = img,
                    contentDescription = null,
                    modifier = Modifier.fillMaxSize().clip(CircleShape),
                    contentScale = androidx.compose.ui.layout.ContentScale.Crop,
                )
            } else {
                Text(
                    row.fullName.firstOrNull()?.uppercaseChar()?.toString() ?: "E",
                    color = BrandGreenDeep,
                    fontWeight = FontWeight.Bold,
                    fontSize = 20.sp,
                )
            }
        }
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(
                    row.fullName,
                    color = Ink900,
                    fontWeight = FontWeight.Bold,
                    fontSize = 15.sp,
                    modifier = Modifier.weight(1f),
                )
                // Directory RPC only returns engineers with verification_status='verified',
                // so every row earns the badge. Pure trust signal for hospitals.
                Icon(
                    imageVector = Icons.Filled.Verified,
                    contentDescription = "Verified",
                    tint = BrandGreen,
                    modifier = Modifier.size(14.dp),
                )
                if (row.isAvailable) {
                    Box(
                        modifier = Modifier
                            .size(8.dp)
                            .clip(CircleShape)
                            .background(AccentLime),
                    )
                }
            }
            val locLine = listOfNotNull(row.city, row.state).joinToString(", ").ifBlank { null }
            if (locLine != null) {
                Text(locLine, color = Ink500, fontSize = 12.sp)
            }
            val specs = row.specializations.orEmpty().take(3)
            if (specs.isNotEmpty()) {
                Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    specs.forEach { sp ->
                        Box(
                            modifier = Modifier
                                .clip(RoundedCornerShape(50))
                                .background(AccentLimeSoft)
                                .padding(horizontal = 8.dp, vertical = 2.dp),
                        ) {
                            Text(prettyKey(sp), color = BrandGreenDeep, fontSize = 10.sp, fontWeight = FontWeight.Bold)
                        }
                    }
                }
            }
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                Icon(Icons.Filled.Star, contentDescription = null, tint = AccentLime, modifier = Modifier.size(12.dp))
                Text(
                    "${"%.1f".format(row.ratingAvg)} · ${row.totalJobs} jobs · ${row.experienceYears} yrs",
                    color = Ink700,
                    fontSize = 11.sp,
                )
            }
            row.hourlyRate?.let { rate ->
                Text("₹${rate.toInt()}/hr", color = BrandGreen, fontWeight = FontWeight.Bold, fontSize = 12.sp)
            }
        }
    }
}

private fun prettyKey(k: String): String =
    k.split('_', '-').joinToString(" ") { it.replaceFirstChar { c -> c.uppercase() } }
