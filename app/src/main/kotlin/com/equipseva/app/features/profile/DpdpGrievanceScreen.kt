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
import androidx.compose.material.icons.outlined.Shield
import androidx.compose.material3.CircularProgressIndicator
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
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import com.equipseva.app.R
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.core.util.prettyDate
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.EsBtn
import com.equipseva.app.designsystem.components.EsBtnKind
import com.equipseva.app.designsystem.components.EsChip
import com.equipseva.app.designsystem.components.EsField
import com.equipseva.app.designsystem.components.EsFieldType
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.components.Pill
import com.equipseva.app.designsystem.components.PillKind
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk900
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

@HiltViewModel
class DpdpGrievanceViewModel @Inject constructor(
    private val repo: DpdpGrievanceRepository,
) : ViewModel() {

    data class UiState(
        val loading: Boolean = true,
        val error: String? = null,
        val grievances: List<DpdpGrievanceRepository.Grievance> = emptyList(),
        val submitting: Boolean = false,
        val submitError: String? = null,
        val submitted: Boolean = false,
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init {
        refresh()
    }

    fun refresh() {
        _state.update { it.copy(loading = true, error = null) }
        viewModelScope.launch {
            repo.fetchMyGrievances()
                .onSuccess { list -> _state.update { it.copy(loading = false, grievances = list) } }
                .onFailure { e ->
                    _state.update {
                        it.copy(loading = false, error = e.toUserMessage("Could not load your requests."))
                    }
                }
        }
    }

    fun submit(grievanceType: String, description: String) {
        _state.update { it.copy(submitting = true, submitError = null, submitted = false) }
        viewModelScope.launch {
            repo.fileGrievance(grievanceType, description)
                .onSuccess {
                    _state.update { it.copy(submitting = false, submitted = true) }
                    refresh()
                }
                .onFailure { e ->
                    _state.update {
                        it.copy(submitting = false, submitError = e.toUserMessage("Could not submit your request."))
                    }
                }
        }
    }

    fun clearSubmitted() = _state.update { it.copy(submitted = false) }
}

private val GRIEVANCE_TYPES = listOf(
    "access_request" to "Access my data",
    "deletion_request" to "Delete my data",
    "correction_request" to "Correct my data",
    "data_portability" to "Export my data",
    "consent_withdrawal" to "Withdraw consent",
    "complaint" to "File a complaint",
)

@Composable
fun DpdpGrievanceScreen(
    onBack: () -> Unit,
    viewModel: DpdpGrievanceViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    var composerOpen by rememberSaveable { mutableStateOf(false) }
    var selectedType by rememberSaveable { mutableStateOf(GRIEVANCE_TYPES.first().first) }
    var description by rememberSaveable { mutableStateOf("") }

    Box(Modifier.fillMaxSize().background(PaperDefault)) {
        Column(Modifier.fillMaxSize()) {
            EsTopBar(title = stringResource(R.string.dpdp_grievance_title), onBack = onBack)

            when {
                state.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }

                state.error != null && state.grievances.isEmpty() -> EmptyStateView(
                    icon = Icons.Outlined.Shield,
                    title = stringResource(R.string.dpdp_grievance_couldnt_load),
                    subtitle = state.error,
                    ctaLabel = stringResource(R.string.dpdp_grievance_try_again),
                    onCta = { viewModel.refresh() },
                )

                else -> LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(horizontal = 16.dp, vertical = 12.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    item {
                        Text(
                            stringResource(R.string.dpdp_grievance_explainer),
                            style = EsType.BodySm,
                            color = SevaInk500,
                        )
                    }
                    item {
                        if (!composerOpen) {
                            EsBtn(
                                text = stringResource(R.string.dpdp_grievance_file_new),
                                onClick = {
                                    viewModel.clearSubmitted()
                                    composerOpen = true
                                },
                                kind = EsBtnKind.Primary,
                                full = true,
                            )
                        } else {
                            GrievanceComposer(
                                selectedType = selectedType,
                                onSelectType = { selectedType = it },
                                description = description,
                                onDescriptionChange = { description = it },
                                submitting = state.submitting,
                                submitError = state.submitError,
                                submitted = state.submitted,
                                onSubmit = {
                                    viewModel.submit(selectedType, description.trim())
                                },
                                onCancel = { composerOpen = false },
                            )
                        }
                    }
                    if (state.submitted && !composerOpen) {
                        item {
                            Text(
                                stringResource(R.string.dpdp_grievance_submitted_note),
                                style = EsType.BodySm.copy(fontWeight = FontWeight.SemiBold),
                                color = SevaInk900,
                            )
                        }
                    }
                    item {
                        Text(
                            stringResource(R.string.dpdp_grievance_history_title),
                            style = EsType.H5,
                            color = SevaInk900,
                        )
                    }
                    if (state.grievances.isEmpty()) {
                        item {
                            Text(
                                stringResource(R.string.dpdp_grievance_history_empty),
                                style = EsType.BodySm,
                                color = SevaInk500,
                            )
                        }
                    } else {
                        items(state.grievances, key = { it.id }) { g -> GrievanceCard(g) }
                    }
                }
            }
        }
    }
}

@Composable
private fun GrievanceComposer(
    selectedType: String,
    onSelectType: (String) -> Unit,
    description: String,
    onDescriptionChange: (String) -> Unit,
    submitting: Boolean,
    submitError: String?,
    submitted: Boolean,
    onSubmit: () -> Unit,
    onCancel: () -> Unit,
) {
    Box(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
            .padding(16.dp),
    ) {
        Column {
            Text(
                stringResource(R.string.dpdp_grievance_type_label),
                style = EsType.Label,
                color = SevaInk500,
            )
            Spacer(Modifier.height(6.dp))
            // Simple 2-column-ish wrap via Row groups of 2 keeps this from
            // needing a FlowRow dependency.
            GRIEVANCE_TYPES.chunked(2).forEach { pair ->
                Row(
                    Modifier.fillMaxWidth().padding(vertical = 3.dp),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    pair.forEach { (key, label) ->
                        EsChip(
                            text = label,
                            active = selectedType == key,
                            onClick = { onSelectType(key) },
                        )
                    }
                }
            }
            Spacer(Modifier.height(10.dp))
            EsField(
                value = description,
                onChange = onDescriptionChange,
                label = stringResource(R.string.dpdp_grievance_description_label),
                hint = stringResource(R.string.dpdp_grievance_description_hint, description.length),
                type = EsFieldType.Multiline,
            )
            if (submitError != null) {
                Spacer(Modifier.height(6.dp))
                Text(submitError, style = EsType.Caption, color = com.equipseva.app.designsystem.theme.SevaDanger500)
            }
            Spacer(Modifier.height(10.dp))
            Row(
                Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                EsBtn(
                    text = stringResource(R.string.dpdp_grievance_cancel),
                    onClick = onCancel,
                    kind = EsBtnKind.Secondary,
                    disabled = submitting,
                    modifier = Modifier.weight(1f),
                )
                EsBtn(
                    text = if (submitting) {
                        stringResource(R.string.dpdp_grievance_submitting)
                    } else {
                        stringResource(R.string.dpdp_grievance_submit)
                    },
                    onClick = onSubmit,
                    kind = EsBtnKind.Primary,
                    disabled = submitting || description.trim().length < 10,
                    modifier = Modifier.weight(1f),
                )
            }
        }
    }
}

@Composable
private fun GrievanceCard(g: DpdpGrievanceRepository.Grievance) {
    val (label, kind) = dpdpGrievanceStatusLabelAndKind(g.status)
    Box(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
            .padding(14.dp),
    ) {
        Column {
            Row(
                Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    dpdpGrievanceTypeLabel(g.grievanceType),
                    style = EsType.Body.copy(fontWeight = FontWeight.SemiBold),
                    color = SevaInk900,
                )
                Pill(text = label, kind = kind)
            }
            Spacer(Modifier.height(4.dp))
            Text(g.description, style = EsType.BodySm, color = SevaInk500)
            Spacer(Modifier.height(4.dp))
            Text(
                stringResource(R.string.dpdp_grievance_deadline, prettyDate(g.deadlineAt)),
                style = EsType.Caption,
                color = SevaInk500,
            )
        }
    }
}

internal fun dpdpGrievanceTypeLabel(key: String): String =
    GRIEVANCE_TYPES.firstOrNull { it.first == key }?.second
        ?: key.replace('_', ' ').replaceFirstChar { it.uppercase() }

internal fun dpdpGrievanceStatusLabelAndKind(status: String): Pair<String, PillKind> = when (status) {
    "open" -> "Open" to PillKind.Warn
    "in_review" -> "In review" to PillKind.Info
    "resolved" -> "Resolved" to PillKind.Success
    "escalated" -> "Escalated" to PillKind.Danger
    "rejected" -> "Rejected" to PillKind.Neutral
    else -> status.replaceFirstChar { it.uppercase() } to PillKind.Neutral
}
