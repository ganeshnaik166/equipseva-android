package com.equipseva.app.features.amc

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
import androidx.compose.material.icons.outlined.SupportAgent
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
import com.equipseva.app.core.util.formatRupees
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
import com.equipseva.app.designsystem.theme.SevaDanger500
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk900
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

private enum class PortalTab { Requests, Disputes }

private val REQUEST_KINDS = listOf(
    "tier_upgrade" to "Upgrade AMC tier",
    "tier_downgrade" to "Downgrade AMC tier",
    "contract_pause" to "Pause contract",
    "contract_resume" to "Resume contract",
    "contract_cancel" to "Cancel contract",
    "payment_method_change" to "Change payment method",
    "billing_address_update" to "Update billing address",
    "add_equipment" to "Add equipment",
    "remove_equipment" to "Remove equipment",
    "transfer_ownership" to "Transfer ownership",
    "other" to "Other",
)

private val DISPUTE_KINDS = listOf(
    "billing_dispute" to "Billing dispute",
    "service_quality" to "Service quality",
    "sla_breach" to "SLA breach",
    "engineer_behavior" to "Engineer behavior",
    "spare_part_quality" to "Spare part quality",
    "warranty_claim" to "Warranty claim",
    "data_privacy" to "Data privacy",
    "other" to "Other",
)

private val AMC_TIERS = listOf("bronze", "silver", "gold")

@HiltViewModel
class HospitalPortalViewModel @Inject constructor(
    private val repo: HospitalPortalRepository,
) : ViewModel() {

    data class UiState(
        val loading: Boolean = true,
        val error: String? = null,
        val requests: List<HospitalPortalRepository.SelfServiceRequest> = emptyList(),
        val disputes: List<HospitalPortalRepository.DisputeRequest> = emptyList(),
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
            val requests = repo.fetchMyRequests()
            val disputes = repo.fetchMyDisputes()
            if (requests.isFailure) {
                _state.update {
                    it.copy(loading = false, error = requests.exceptionOrNull()?.toUserMessage("Could not load."))
                }
                return@launch
            }
            _state.update {
                it.copy(
                    loading = false,
                    requests = requests.getOrDefault(emptyList()),
                    disputes = disputes.getOrDefault(emptyList()),
                )
            }
        }
    }

    fun submitRequest(kind: String, desiredTier: String?) {
        _state.update { it.copy(submitting = true, submitError = null, submitted = false) }
        viewModelScope.launch {
            repo.submitSelfServiceRequest(kind, desiredTier)
                .onSuccess {
                    _state.update { it.copy(submitting = false, submitted = true) }
                    refresh()
                }
                .onFailure { e ->
                    _state.update { it.copy(submitting = false, submitError = e.toUserMessage("Could not submit.")) }
                }
        }
    }

    fun submitDispute(kind: String, description: String, amount: Double?) {
        _state.update { it.copy(submitting = true, submitError = null, submitted = false) }
        viewModelScope.launch {
            repo.submitDispute(kind, description, amount)
                .onSuccess {
                    _state.update { it.copy(submitting = false, submitted = true) }
                    refresh()
                }
                .onFailure { e ->
                    _state.update { it.copy(submitting = false, submitError = e.toUserMessage("Could not submit.")) }
                }
        }
    }

    fun clearSubmitted() = _state.update { it.copy(submitted = false, submitError = null) }
}

@Composable
fun HospitalPortalScreen(
    onBack: () -> Unit,
    viewModel: HospitalPortalViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    var tab by rememberSaveable { mutableStateOf(PortalTab.Requests) }
    var composerOpen by rememberSaveable { mutableStateOf(false) }

    Box(Modifier.fillMaxSize().background(PaperDefault)) {
        Column(Modifier.fillMaxSize()) {
            EsTopBar(title = stringResource(R.string.hospital_portal_title), onBack = onBack)

            Row(
                Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                EsChip(
                    text = stringResource(R.string.hospital_portal_tab_requests),
                    active = tab == PortalTab.Requests,
                    onClick = { tab = PortalTab.Requests; composerOpen = false },
                )
                EsChip(
                    text = stringResource(R.string.hospital_portal_tab_disputes),
                    active = tab == PortalTab.Disputes,
                    onClick = { tab = PortalTab.Disputes; composerOpen = false },
                )
            }

            when {
                state.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }

                state.error != null && state.requests.isEmpty() && state.disputes.isEmpty() -> EmptyStateView(
                    icon = Icons.Outlined.SupportAgent,
                    title = stringResource(R.string.hospital_portal_couldnt_load),
                    subtitle = state.error,
                    ctaLabel = stringResource(R.string.hospital_portal_try_again),
                    onCta = { viewModel.refresh() },
                )

                tab == PortalTab.Requests -> LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    item {
                        if (!composerOpen) {
                            EsBtn(
                                text = stringResource(R.string.hospital_portal_new_request),
                                onClick = { viewModel.clearSubmitted(); composerOpen = true },
                                kind = EsBtnKind.Primary,
                                full = true,
                            )
                        } else {
                            SelfServiceComposer(
                                submitting = state.submitting,
                                submitError = state.submitError,
                                submitted = state.submitted,
                                onSubmit = { kind, tierOrNull -> viewModel.submitRequest(kind, tierOrNull) },
                                onCancel = { composerOpen = false },
                            )
                        }
                    }
                    if (state.requests.isEmpty()) {
                        item {
                            Text(
                                stringResource(R.string.hospital_portal_requests_empty),
                                style = EsType.BodySm,
                                color = SevaInk500,
                            )
                        }
                    } else {
                        items(state.requests, key = { it.id }) { r -> RequestCard(r) }
                    }
                }

                else -> LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    item {
                        if (!composerOpen) {
                            EsBtn(
                                text = stringResource(R.string.hospital_portal_new_dispute),
                                onClick = { viewModel.clearSubmitted(); composerOpen = true },
                                kind = EsBtnKind.Primary,
                                full = true,
                            )
                        } else {
                            DisputeComposer(
                                submitting = state.submitting,
                                submitError = state.submitError,
                                submitted = state.submitted,
                                onSubmit = { kind, desc, amount -> viewModel.submitDispute(kind, desc, amount) },
                                onCancel = { composerOpen = false },
                            )
                        }
                    }
                    if (state.disputes.isEmpty()) {
                        item {
                            Text(
                                stringResource(R.string.hospital_portal_disputes_empty),
                                style = EsType.BodySm,
                                color = SevaInk500,
                            )
                        }
                    } else {
                        items(state.disputes, key = { it.id }) { d -> DisputeCard(d) }
                    }
                }
            }
        }
    }
}

@Composable
private fun SelfServiceComposer(
    submitting: Boolean,
    submitError: String?,
    submitted: Boolean,
    onSubmit: (kind: String, desiredTier: String?) -> Unit,
    onCancel: () -> Unit,
) {
    var selectedKind by rememberSaveable { mutableStateOf(REQUEST_KINDS.first().first) }
    var selectedTier by rememberSaveable { mutableStateOf(AMC_TIERS.first()) }
    val needsTier = selectedKind == "tier_upgrade" || selectedKind == "tier_downgrade"

    ComposerShell(submitError, submitted, stringResource(R.string.hospital_portal_request_submitted_note)) {
        Text(stringResource(R.string.hospital_portal_request_kind_label), style = EsType.Label, color = SevaInk500)
        Spacer(Modifier.height(6.dp))
        REQUEST_KINDS.chunked(2).forEach { pair ->
            Row(Modifier.fillMaxWidth().padding(vertical = 3.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                pair.forEach { (key, label) ->
                    EsChip(text = label, active = selectedKind == key, onClick = { selectedKind = key })
                }
            }
        }
        if (needsTier) {
            Spacer(Modifier.height(10.dp))
            Text(stringResource(R.string.hospital_portal_desired_tier_label), style = EsType.Label, color = SevaInk500)
            Spacer(Modifier.height(6.dp))
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                AMC_TIERS.forEach { tier ->
                    EsChip(
                        text = tier.replaceFirstChar { it.uppercase() },
                        active = selectedTier == tier,
                        onClick = { selectedTier = tier },
                    )
                }
            }
        }
        Spacer(Modifier.height(10.dp))
        ComposerActions(
            submitting = submitting,
            enabled = !submitting,
            onCancel = onCancel,
            onSubmit = { onSubmit(selectedKind, if (needsTier) selectedTier else null) },
        )
    }
}

@Composable
private fun DisputeComposer(
    submitting: Boolean,
    submitError: String?,
    submitted: Boolean,
    onSubmit: (kind: String, description: String, amount: Double?) -> Unit,
    onCancel: () -> Unit,
) {
    var selectedKind by rememberSaveable { mutableStateOf(DISPUTE_KINDS.first().first) }
    var description by rememberSaveable { mutableStateOf("") }
    var amountText by rememberSaveable { mutableStateOf("") }

    ComposerShell(submitError, submitted, stringResource(R.string.hospital_portal_dispute_submitted_note)) {
        Text(stringResource(R.string.hospital_portal_dispute_kind_label), style = EsType.Label, color = SevaInk500)
        Spacer(Modifier.height(6.dp))
        DISPUTE_KINDS.chunked(2).forEach { pair ->
            Row(Modifier.fillMaxWidth().padding(vertical = 3.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                pair.forEach { (key, label) ->
                    EsChip(text = label, active = selectedKind == key, onClick = { selectedKind = key })
                }
            }
        }
        Spacer(Modifier.height(10.dp))
        EsField(
            value = description,
            onChange = { description = it },
            label = stringResource(R.string.hospital_portal_dispute_description_label),
            type = EsFieldType.Multiline,
        )
        Spacer(Modifier.height(10.dp))
        EsField(
            value = amountText,
            onChange = { amountText = it.filter { c -> c.isDigit() } },
            label = stringResource(R.string.hospital_portal_dispute_amount_label),
            type = EsFieldType.Number,
        )
        Spacer(Modifier.height(10.dp))
        ComposerActions(
            submitting = submitting,
            enabled = !submitting && description.trim().length >= 10,
            onCancel = onCancel,
            onSubmit = { onSubmit(selectedKind, description.trim(), amountText.toDoubleOrNull()) },
        )
    }
}

@Composable
private fun ComposerShell(
    submitError: String?,
    submitted: Boolean,
    submittedNote: String,
    content: @Composable androidx.compose.foundation.layout.ColumnScope.() -> Unit,
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
            content()
            if (submitError != null) {
                Spacer(Modifier.height(6.dp))
                Text(submitError, style = EsType.Caption, color = SevaDanger500)
            }
            if (submitted) {
                Spacer(Modifier.height(6.dp))
                Text(submittedNote, style = EsType.Caption, color = com.equipseva.app.designsystem.theme.SevaGreen700)
            }
        }
    }
}

@Composable
private fun ComposerActions(
    submitting: Boolean,
    enabled: Boolean,
    onCancel: () -> Unit,
    onSubmit: () -> Unit,
) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        EsBtn(
            text = stringResource(R.string.hospital_portal_cancel),
            onClick = onCancel,
            kind = EsBtnKind.Secondary,
            disabled = submitting,
            modifier = Modifier.weight(1f),
        )
        EsBtn(
            text = if (submitting) {
                stringResource(R.string.hospital_portal_submitting)
            } else {
                stringResource(R.string.hospital_portal_submit)
            },
            onClick = onSubmit,
            kind = EsBtnKind.Primary,
            disabled = !enabled,
            modifier = Modifier.weight(1f),
        )
    }
}

@Composable
private fun RequestCard(r: HospitalPortalRepository.SelfServiceRequest) {
    val (label, kind) = hospitalPortalRequestStatusLabelAndKind(r.status)
    Box(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp)).padding(14.dp),
    ) {
        Column {
            Row(
                Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    hospitalPortalRequestKindLabel(r.requestKind),
                    style = EsType.Body.copy(fontWeight = FontWeight.SemiBold),
                    color = SevaInk900,
                )
                Pill(text = label, kind = kind)
            }
            Spacer(Modifier.height(4.dp))
            Text(prettyDate(r.submittedAt), style = EsType.BodySm, color = SevaInk500)
            if (!r.founderResponse.isNullOrBlank()) {
                Spacer(Modifier.height(4.dp))
                Text(r.founderResponse, style = EsType.BodySm, color = SevaInk500)
            }
        }
    }
}

@Composable
private fun DisputeCard(d: HospitalPortalRepository.DisputeRequest) {
    val (label, kind) = hospitalPortalDisputeStatusLabelAndKind(d.status)
    Box(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp)).padding(14.dp),
    ) {
        Column {
            Row(
                Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    hospitalPortalDisputeKindLabel(d.disputeKind),
                    style = EsType.Body.copy(fontWeight = FontWeight.SemiBold),
                    color = SevaInk900,
                )
                Pill(text = label, kind = kind)
            }
            Spacer(Modifier.height(4.dp))
            Text(prettyDate(d.submittedAt), style = EsType.BodySm, color = SevaInk500)
            if (d.amountClaimedRupees != null) {
                Spacer(Modifier.height(4.dp))
                Text(
                    "Claimed: ${formatRupees(d.amountClaimedRupees)}",
                    style = EsType.BodySm,
                    color = SevaInk500,
                )
            }
        }
    }
}

internal fun hospitalPortalRequestKindLabel(key: String): String =
    REQUEST_KINDS.firstOrNull { it.first == key }?.second
        ?: key.replace('_', ' ').replaceFirstChar { it.uppercase() }

internal fun hospitalPortalDisputeKindLabel(key: String): String =
    DISPUTE_KINDS.firstOrNull { it.first == key }?.second
        ?: key.replace('_', ' ').replaceFirstChar { it.uppercase() }

internal fun hospitalPortalRequestStatusLabelAndKind(status: String): Pair<String, PillKind> = when (status) {
    "submitted" -> "Submitted" to PillKind.Warn
    "under_review" -> "Under review" to PillKind.Info
    "approved" -> "Approved" to PillKind.Success
    "rejected" -> "Rejected" to PillKind.Danger
    "cancelled_by_hospital" -> "Cancelled" to PillKind.Neutral
    "expired" -> "Expired" to PillKind.Neutral
    else -> status.replaceFirstChar { it.uppercase() } to PillKind.Neutral
}

internal fun hospitalPortalDisputeStatusLabelAndKind(status: String): Pair<String, PillKind> = when (status) {
    "submitted" -> "Submitted" to PillKind.Warn
    "under_review" -> "Under review" to PillKind.Info
    "mediation_requested" -> "Mediation requested" to PillKind.Info
    "accepted" -> "Accepted" to PillKind.Success
    "rejected" -> "Rejected" to PillKind.Danger
    "withdrawn" -> "Withdrawn" to PillKind.Neutral
    "escalated" -> "Escalated" to PillKind.Danger
    else -> status.replaceFirstChar { it.uppercase() } to PillKind.Neutral
}
