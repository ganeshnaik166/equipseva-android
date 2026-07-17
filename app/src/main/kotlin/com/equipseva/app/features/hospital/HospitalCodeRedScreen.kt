package com.equipseva.app.features.hospital

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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Emergency
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Surface
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.codered.CodeRedRepository
import com.equipseva.app.core.data.repair.RepairEquipmentCategory
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.core.util.SlaUrgency
import com.equipseva.app.core.util.formatRupees
import com.equipseva.app.core.util.prettyDate
import com.equipseva.app.core.util.slaCountdownLabel
import com.equipseva.app.core.util.slaUrgency
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.EsBottomSheet
import com.equipseva.app.designsystem.components.EsBtn
import com.equipseva.app.designsystem.components.EsBtnKind
import com.equipseva.app.designsystem.components.EsBtnSize
import com.equipseva.app.designsystem.components.EsDropdown
import com.equipseva.app.designsystem.components.EsField
import com.equipseva.app.designsystem.components.EsFieldType
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.components.Pill
import com.equipseva.app.designsystem.components.PillKind
import com.equipseva.app.designsystem.util.PollingEffect
import com.equipseva.app.designsystem.util.rememberNowTicker
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaDanger500
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk700
import com.equipseva.app.designsystem.theme.SevaInk900
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

@HiltViewModel
class HospitalCodeRedViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val repo: CodeRedRepository,
) : ViewModel() {
    data class UiState(
        val loading: Boolean = true,
        val error: String? = null,
        val requests: List<CodeRedRepository.HospitalCodeRed> = emptyList(),
        val equipmentTypes: List<String> = emptyList(),
        val submitting: Boolean = false,
        val actionError: String? = null,
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init { reload() }

    fun reload() {
        _state.update { it.copy(loading = it.requests.isEmpty(), error = null) }
        viewModelScope.launch {
            val session = authRepository.sessionState.first { it !is AuthSession.Unknown }
            val uid = (session as? AuthSession.SignedIn)?.userId
            if (uid == null) {
                _state.update { it.copy(loading = false, error = "Sign in again to manage emergencies.") }
                return@launch
            }
            // r1441: don't swallow a taxonomy failure — without types the Fire
            // form is unusable, so surface it (shown in the fire sheet) instead
            // of leaving the dropdown stuck on "Loading…" with no explanation.
            repo.allowedEquipmentTypes()
                .onSuccess { t -> _state.update { it.copy(equipmentTypes = t, actionError = null) } }
                .onFailure { e ->
                    _state.update {
                        it.copy(actionError = "Couldn't load equipment types (${e.toUserMessage()}). Reopen this screen to retry.")
                    }
                }
            repo.myRequests(uid)
                .onSuccess { list -> _state.update { it.copy(loading = false, requests = list) } }
                .onFailure { e ->
                    _state.update { if (it.requests.isEmpty()) it.copy(loading = false, error = e.toUserMessage()) else it.copy(loading = false) }
                }
        }
    }

    fun clearActionError() = _state.update { it.copy(actionError = null) }

    fun open(
        equipmentType: String,
        serial: String,
        description: String,
        feeCeilingRupees: Double,
        slaMinutes: Int,
        onDone: () -> Unit,
    ) {
        _state.update { it.copy(submitting = true, actionError = null) }
        viewModelScope.launch {
            repo.open(equipmentType, brand = null, model = null, serial = serial, description = description, feeCeilingRupees = feeCeilingRupees, slaMinutes = slaMinutes)
                .onSuccess {
                    _state.update { it.copy(submitting = false, actionError = null) }
                    onDone()
                    reload()
                }
                .onFailure { e -> _state.update { it.copy(submitting = false, actionError = e.toUserMessage()) } }
        }
    }
}

/**
 * Hospital Code Red (r1426): fire an emergency dispatch for a critical
 * equipment failure and track the ones you've raised. Backed by
 * open_code_red_request + a direct read of code_red_requests (RLS-scoped to
 * the hospital). Equipment types come live from the v0.4-allowed taxonomy so
 * the picker can't offer a class the server would reject. Reached from
 * Profile.
 */
@Composable
fun HospitalCodeRedScreen(
    onBack: () -> Unit,
    viewModel: HospitalCodeRedViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    com.equipseva.app.designsystem.util.RefreshOnReturn { viewModel.reload() }
    val now by rememberNowTicker()
    // While a Code Red is still paging, poll so "Paging engineers" flips to
    // "Engineer accepted" live, without a manual refresh.
    PollingEffect(enabled = state.requests.any { it.status == "open" }) { viewModel.reload() }

    var showForm by rememberSaveable { mutableStateOf(false) }
    if (showForm) {
        FireCodeRedSheet(
            equipmentTypes = state.equipmentTypes,
            submitting = state.submitting,
            error = state.actionError,
            onClose = {
                showForm = false
                viewModel.clearActionError()
            },
            onSubmit = { type, serial, desc, fee, sla ->
                viewModel.open(type, serial, desc, fee, sla) { showForm = false }
            },
        )
    }

    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(title = "Code Red", onBack = onBack)
            when {
                state.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }
                state.error != null -> EmptyStateView(
                    icon = Icons.Outlined.Emergency,
                    title = "Couldn't load Code Red",
                    subtitle = state.error,
                    ctaLabel = "Try again",
                    onCta = { viewModel.reload() },
                )
                else -> LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(12.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    item(key = "fire") {
                        EsBtn(
                            text = "Fire a Code Red",
                            onClick = { showForm = true },
                            kind = EsBtnKind.Primary,
                            size = EsBtnSize.Lg,
                            full = true,
                        )
                    }
                    if (state.requests.isEmpty()) {
                        item(key = "empty") {
                            Text(
                                "No emergencies raised. Use this only for critical equipment failures that need an engineer on site fast.",
                                style = EsType.BodySm,
                                color = SevaInk500,
                                modifier = Modifier.padding(horizontal = 4.dp, vertical = 8.dp),
                            )
                        }
                    } else {
                        items(state.requests, key = { it.id }) { req -> HospitalCodeRedCard(req, now) }
                    }
                    item(key = "tail") { Spacer(Modifier.height(8.dp)) }
                }
            }
        }
    }
}

@Composable
private fun HospitalCodeRedCard(req: CodeRedRepository.HospitalCodeRed, now: Long) {
    val (pillText, pillKind) = codeRedRequestStatusPill(req.status)
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
            .padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                equipmentTypeLabel(req.equipmentType),
                style = EsType.Body.copy(fontWeight = FontWeight.Bold),
                color = SevaInk900,
                modifier = Modifier.weight(1f),
            )
            Pill(text = pillText, kind = pillKind)
        }
        Text(req.description, style = EsType.BodySm, color = SevaInk700)
        req.slaDeadlineAt?.takeIf { it.isNotBlank() }?.let { iso ->
            val countdown = if (req.status == "open") slaCountdownLabel(iso, now) else null
            if (countdown != null) {
                val urgent = slaUrgency(iso, now) != SlaUrgency.Ok
                Text(
                    "$countdown · SLA ${prettyDate(iso)}",
                    style = EsType.Caption.copy(fontWeight = if (urgent) FontWeight.Bold else FontWeight.Normal),
                    color = if (urgent) SevaDanger500 else SevaInk500,
                )
            } else {
                Text("SLA by ${prettyDate(iso)}", style = EsType.Caption, color = SevaInk500)
            }
        }
        Text(
            "Up to ${formatRupees(req.feeCeilingRupees)} emergency fee" +
                (req.acceptedAt?.takeIf { it.isNotBlank() }?.let { " · accepted ${prettyDate(it)}" } ?: ""),
            style = EsType.Caption,
            color = SevaInk500,
        )
        // r1437 — one-tap into the emergency coordination channel while the
        // Code Red is still active. Only shows when ops attached a war-room link.
        val warroom = req.warroomUrl?.takeIf { it.isNotBlank() }
        if (warroom != null && (req.status == "open" || req.status == "engineer_accepted")) {
            val uriHandler = androidx.compose.ui.platform.LocalUriHandler.current
            EsBtn(
                text = "Open war room",
                onClick = { runCatching { uriHandler.openUri(warroom) } },
                kind = EsBtnKind.Secondary,
                size = EsBtnSize.Sm,
            )
        }
    }
}

@Composable
private fun FireCodeRedSheet(
    equipmentTypes: List<String>,
    submitting: Boolean,
    error: String?,
    onClose: () -> Unit,
    onSubmit: (type: String, serial: String, description: String, feeCeiling: Double, slaMinutes: Int) -> Unit,
) {
    var typeLabel by rememberSaveable { mutableStateOf<String?>(null) }
    var serial by rememberSaveable { mutableStateOf("") }
    var description by rememberSaveable { mutableStateOf("") }
    var fee by rememberSaveable { mutableStateOf("5000") }
    var slaLabel by rememberSaveable { mutableStateOf(slaMinutesLabel(60)) }

    val typeOptions = equipmentTypes.map { equipmentTypeLabel(it) }
    val selectedType = typeLabel?.let { label -> equipmentTypes.firstOrNull { equipmentTypeLabel(it) == label } }
    val feeValue = parseFeeCeiling(fee)
    val slaMinutes = SLA_MINUTE_OPTIONS.firstOrNull { slaMinutesLabel(it) == slaLabel } ?: 60
    val canSubmit = selectedType != null &&
        isValidCodeRedDescription(description) &&
        feeValue != null &&
        !submitting

    EsBottomSheet(onClose = onClose, title = "Fire a Code Red") {
        Column(
            modifier = Modifier.verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(
                "Pages nearby verified engineers immediately. Only in-scope equipment classes are eligible.",
                style = EsType.BodySm,
                color = SevaInk700,
            )
            EsDropdown(
                value = typeLabel,
                onValueChange = { typeLabel = it },
                options = typeOptions,
                label = "Equipment type",
                placeholder = if (typeOptions.isEmpty()) "Loading…" else "Select",
            )
            EsField(
                value = serial,
                onChange = { serial = it },
                label = "Serial / asset tag (optional)",
                placeholder = "e.g. GE-CARE-2213",
            )
            EsField(
                value = description,
                onChange = { description = it },
                label = "What's wrong?",
                placeholder = "e.g. Monitor dead in ICU bed 4, patient waiting",
                hint = "At least 10 characters",
            )
            EsDropdown(
                value = slaLabel,
                onValueChange = { slaLabel = it },
                options = SLA_MINUTE_OPTIONS.map { slaMinutesLabel(it) },
                label = "Response window",
            )
            EsField(
                value = fee,
                onChange = { fee = it },
                label = "Emergency fee ceiling (₹)",
                hint = "Auto-approve engineer surcharge up to this",
                type = EsFieldType.Number,
                imeAction = ImeAction.Done,
            )
            if (error != null) {
                Text(error, style = EsType.BodySm, color = SevaDanger500)
            }
            EsBtn(
                text = if (submitting) "Firing…" else "Fire Code Red",
                onClick = {
                    val t = selectedType
                    val f = feeValue
                    if (t != null && f != null) onSubmit(t, serial, description, f, slaMinutes)
                },
                kind = EsBtnKind.Primary,
                size = EsBtnSize.Lg,
                full = true,
                disabled = !canSubmit,
            )
            Spacer(Modifier.height(4.dp))
        }
    }
}

// ---------------------------------------------------------------------
//  Pinned helpers
// ---------------------------------------------------------------------

internal val SLA_MINUTE_OPTIONS = listOf(30, 60, 120, 240)

/** Human label for an SLA window in minutes. */
internal fun slaMinutesLabel(minutes: Int): String = when {
    minutes < 60 -> "$minutes minutes"
    minutes == 60 -> "1 hour"
    minutes % 60 == 0 -> "${minutes / 60} hours"
    else -> "$minutes minutes"
}

/** Friendly equipment-type label; reuses the repair category names, falling
 *  back to a de-snaked key. */
internal fun equipmentTypeLabel(key: String): String {
    val cat = RepairEquipmentCategory.fromKey(key)
    return if (cat == RepairEquipmentCategory.Other && key != RepairEquipmentCategory.Other.storageKey) {
        key.trim().replace('_', ' ').replaceFirstChar { it.uppercase() }
    } else {
        cat.displayName
    }
}

/** Code Red request status → pill for the hospital view. */
internal fun codeRedRequestStatusPill(status: String): Pair<String, PillKind> = when (status) {
    "open" -> "Paging engineers" to PillKind.Warn
    "engineer_accepted" -> "Engineer accepted" to PillKind.Success
    "resolved" -> "Resolved" to PillKind.Success
    "timed_out" -> "Timed out" to PillKind.Danger
    "cancelled" -> "Cancelled" to PillKind.Neutral
    else -> status.replace('_', ' ').replaceFirstChar { it.uppercase() } to PillKind.Neutral
}

/** Description must be 10-2000 chars (mirrors the server CHECK). */
internal fun isValidCodeRedDescription(description: String): Boolean =
    description.trim().length in 10..2000

/** Parses the fee-ceiling field to a valid 0-50000 rupee amount, or null. */
internal fun parseFeeCeiling(text: String): Double? {
    val v = text.trim().toDoubleOrNull() ?: return null
    return if (v in 0.0..50000.0) v else null
}
