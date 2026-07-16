package com.equipseva.app.features.profile

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
import androidx.compose.material.icons.outlined.Gavel
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
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.data.consent.FILABLE_GRIEVANCE_TYPES
import com.equipseva.app.core.data.consent.GrievanceRepository
import com.equipseva.app.core.data.consent.grievanceDescriptionError
import com.equipseva.app.core.data.consent.grievanceTypeLabel
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.core.util.prettyDate
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.EsBottomSheet
import com.equipseva.app.designsystem.components.EsBtn
import com.equipseva.app.designsystem.components.EsBtnKind
import com.equipseva.app.designsystem.components.EsDropdown
import com.equipseva.app.designsystem.components.EsField
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.components.Pill
import com.equipseva.app.designsystem.components.PillKind
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.PaperDefault
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
class GrievancesViewModel @Inject constructor(
    private val repo: GrievanceRepository,
) : ViewModel() {
    data class UiState(
        val loading: Boolean = true,
        val refreshing: Boolean = false,
        val error: String? = null,
        val grievances: List<GrievanceRepository.Grievance> = emptyList(),
        // File-a-grievance form.
        val sheetOpen: Boolean = false,
        val formTypeKey: String? = null,
        val formDescription: String = "",
        val submitting: Boolean = false,
        val submitError: String? = null,
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init { reload(initial = true) }

    fun reload(initial: Boolean = false) {
        _state.update {
            it.copy(
                loading = initial || it.grievances.isEmpty(),
                refreshing = !initial && it.grievances.isNotEmpty(),
                error = null,
            )
        }
        viewModelScope.launch {
            repo.fetch()
                .onSuccess { rows -> _state.update { it.copy(loading = false, refreshing = false, grievances = rows) } }
                .onFailure { e -> _state.update { it.copy(loading = false, refreshing = false, error = e.toUserMessage()) } }
        }
    }

    fun onPullToRefresh() = reload(initial = false)

    fun openSheet() = _state.update {
        it.copy(sheetOpen = true, formTypeKey = null, formDescription = "", submitError = null)
    }

    fun closeSheet() = _state.update { it.copy(sheetOpen = false) }

    fun onFormType(key: String) = _state.update { it.copy(formTypeKey = key, submitError = null) }

    fun onFormDescription(text: String) = _state.update { it.copy(formDescription = text, submitError = null) }

    fun submit() {
        val s = _state.value
        val type = s.formTypeKey ?: return
        if (grievanceDescriptionError(s.formDescription) != null) return
        _state.update { it.copy(submitting = true, submitError = null) }
        viewModelScope.launch {
            repo.file(type, s.formDescription)
                .onSuccess {
                    _state.update { it.copy(submitting = false, sheetOpen = false) }
                    reload()
                }
                .onFailure { e ->
                    _state.update { it.copy(submitting = false, submitError = e.toUserMessage()) }
                }
        }
    }
}

/**
 * DPDP grievances (r1403 read + r1415 file): the list of data-rights requests
 * the user has filed, with status + statutory deadline, PLUS a "File a
 * grievance" form that writes via file_dpdp_grievance (round 485). Reachable
 * from the Profile "My grievances" row (both roles).
 */
@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
fun GrievancesScreen(
    onBack: () -> Unit,
    viewModel: GrievancesViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    com.equipseva.app.designsystem.util.RefreshOnReturn { viewModel.reload() }

    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(title = "My grievances", onBack = onBack)
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
                        icon = Icons.Outlined.Gavel,
                        title = "Couldn't load grievances",
                        subtitle = state.error,
                        ctaLabel = "Try again",
                        onCta = { viewModel.reload() },
                    )
                    state.grievances.isEmpty() -> EmptyStateView(
                        icon = Icons.Outlined.Gavel,
                        title = "No grievances filed",
                        subtitle = "Data-rights requests you raise under India's DPDP Act (access, correction, deletion) show up here with their status and deadline.",
                        ctaLabel = "File a grievance",
                        onCta = { viewModel.openSheet() },
                    )
                    else -> LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(12.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        item(key = "__file_cta") {
                            EsBtn(
                                text = "File a grievance",
                                onClick = { viewModel.openSheet() },
                                kind = EsBtnKind.Primary,
                                full = true,
                            )
                        }
                        items(state.grievances, key = { it.id }) { g -> GrievanceRow(g) }
                    }
                }
            }
        }
    }

    if (state.sheetOpen) {
        EsBottomSheet(onClose = { viewModel.closeSheet() }, title = "File a grievance") {
            FileGrievanceForm(
                typeKey = state.formTypeKey,
                description = state.formDescription,
                submitting = state.submitting,
                submitError = state.submitError,
                onType = viewModel::onFormType,
                onDescription = viewModel::onFormDescription,
                onSubmit = viewModel::submit,
            )
        }
    }
}

@Composable
private fun FileGrievanceForm(
    typeKey: String?,
    description: String,
    submitting: Boolean,
    submitError: String?,
    onType: (String) -> Unit,
    onDescription: (String) -> Unit,
    onSubmit: () -> Unit,
) {
    val labels = FILABLE_GRIEVANCE_TYPES.map { grievanceTypeLabel(it) }
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .padding(bottom = 16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        EsDropdown(
            value = typeKey?.let { grievanceTypeLabel(it) },
            onValueChange = { label ->
                FILABLE_GRIEVANCE_TYPES.firstOrNull { grievanceTypeLabel(it) == label }?.let(onType)
            },
            options = labels,
            label = "Type of request",
            placeholder = "Select a request type",
            searchable = false,
        )
        EsField(
            value = description,
            onChange = onDescription,
            label = "Details",
            placeholder = "Briefly describe your data-rights request",
        )
        Text(
            "We respond within 30 days, as required under India's DPDP Act.",
            color = SevaInk500,
            fontSize = 11.sp,
        )
        if (submitError != null) {
            Text(submitError, color = Color(0xFFC62828), fontSize = 12.sp)
        }
        val valid = typeKey != null && grievanceDescriptionError(description) == null
        EsBtn(
            text = if (submitting) "Filing…" else "Submit request",
            onClick = onSubmit,
            kind = EsBtnKind.Primary,
            full = true,
            disabled = submitting || !valid,
        )
        Spacer(Modifier.height(4.dp))
    }
}

@Composable
private fun GrievanceRow(g: GrievanceRepository.Grievance) {
    val (pillText, pillKind) = grievanceStatusPillTextAndKind(g.status)
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
            .padding(12.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(
                grievanceTypeLabel(g.grievanceType),
                color = SevaInk900,
                fontWeight = FontWeight.Bold,
                fontSize = 14.sp,
                modifier = Modifier.weight(1f),
            )
            Pill(text = pillText, kind = pillKind)
        }
        if (g.description.isNotBlank()) {
            Text(g.description, color = SevaInk700, fontSize = 12.sp, maxLines = 3)
        }
        val meta = when {
            g.resolvedAt?.isNotBlank() == true -> "Resolved ${prettyDate(g.resolvedAt)}"
            g.deadlineAt?.isNotBlank() == true -> "Response due by ${prettyDate(g.deadlineAt)}"
            g.createdAt?.isNotBlank() == true -> "Filed ${prettyDate(g.createdAt)}"
            else -> null
        }
        meta?.let { Text(it, color = SevaInk500, fontSize = 11.sp) }
    }
}

/**
 * Grievance status → pill:
 *   * open      → "Open"      (Warn)
 *   * in_review → "In review" (Info)
 *   * resolved  → "Resolved"  (Success)
 *   * escalated → "Escalated" (Danger)
 *   * rejected  → "Rejected"  (Neutral)
 *   * other     → capitalised (Neutral, defensive default)
 */
internal fun grievanceStatusPillTextAndKind(status: String): Pair<String, PillKind> = when (status) {
    "open" -> "Open" to PillKind.Warn
    "in_review" -> "In review" to PillKind.Info
    "resolved" -> "Resolved" to PillKind.Success
    "escalated" -> "Escalated" to PillKind.Danger
    "rejected" -> "Rejected" to PillKind.Neutral
    else -> status.replace('_', ' ').replaceFirstChar { it.uppercase() } to PillKind.Neutral
}
