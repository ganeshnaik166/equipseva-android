package com.equipseva.app.features.engineer

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
import com.equipseva.app.designsystem.components.EsField
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
class EngineerCodeRedViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val repo: CodeRedRepository,
) : ViewModel() {
    data class UiState(
        val loading: Boolean = true,
        val error: String? = null,
        val items: List<CodeRedRepository.CodeRed> = emptyList(),
        // r1438 — the emergency this engineer already accepted (kept visible
        // with its war-room link after it leaves the actionable feed).
        val accepted: List<CodeRedRepository.CodeRed> = emptyList(),
        val working: Boolean = false,
        val actionError: String? = null,
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init { reload() }

    fun reload() {
        // r1441: include accepted — an engineer attending an accepted emergency
        // (items empty, accepted non-empty) must not get a spinner flash each poll.
        _state.update { it.copy(loading = it.items.isEmpty() && it.accepted.isEmpty(), error = null) }
        viewModelScope.launch {
            val session = authRepository.sessionState.first { it !is AuthSession.Unknown }
            val uid = (session as? AuthSession.SignedIn)?.userId
            if (uid == null) {
                _state.update { it.copy(loading = false, error = "Sign in again to see emergencies.") }
                return@launch
            }
            val accepted = repo.acceptedByMe(uid).getOrNull().orEmpty()
            repo.openForMe(uid)
                .onSuccess { list -> _state.update { it.copy(loading = false, items = list, accepted = accepted) } }
                .onFailure { e -> _state.update { it.copy(loading = false, error = e.toUserMessage(), accepted = accepted) } }
        }
    }

    fun clearActionError() = _state.update { it.copy(actionError = null) }

    fun accept(codeRedId: String, onDone: () -> Unit) = act(onDone) { repo.accept(codeRedId) }

    fun decline(codeRedId: String, reason: String, onDone: () -> Unit) =
        act(onDone) { repo.decline(codeRedId, reason) }

    private fun act(onDone: () -> Unit, block: suspend () -> Result<Unit>) {
        _state.update { it.copy(working = true, actionError = null) }
        viewModelScope.launch {
            block()
                .onSuccess {
                    _state.update { it.copy(working = false, actionError = null) }
                    onDone()
                    reload()
                }
                .onFailure { e -> _state.update { it.copy(working = false, actionError = e.toUserMessage()) } }
        }
    }
}

/**
 * Engineer Code Red response (r1425): the still-open emergencies this engineer
 * was paged for, newest-SLA first, each with Accept (first wins) and Decline
 * (optional reason). Backed by a direct read of code_red_dispatch_events (with
 * the request embedded, RLS-scoped to the caller) + accept_code_red /
 * decline_code_red. Reached from the engineer Jobs hub.
 */
@Composable
fun EngineerCodeRedScreen(
    onBack: () -> Unit,
    viewModel: EngineerCodeRedViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    com.equipseva.app.designsystem.util.RefreshOnReturn { viewModel.reload() }
    val now by rememberNowTicker()
    // Live board: while emergencies are showing, poll so ones taken by another
    // engineer or timed out drop off without a manual refresh.
    PollingEffect(enabled = state.items.isNotEmpty() || state.accepted.isNotEmpty()) { viewModel.reload() }

    var declineFor by rememberSaveable { mutableStateOf<String?>(null) }

    declineFor?.let { codeRedId ->
        DeclineSheet(
            working = state.working,
            error = state.actionError,
            onClose = {
                declineFor = null
                viewModel.clearActionError()
            },
            onSubmit = { reason -> viewModel.decline(codeRedId, reason) { declineFor = null } },
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
                    title = "Couldn't load emergencies",
                    subtitle = state.error,
                    ctaLabel = "Try again",
                    onCta = { viewModel.reload() },
                )
                state.items.isEmpty() && state.accepted.isEmpty() -> EmptyStateView(
                    icon = Icons.Outlined.Emergency,
                    title = "No active emergencies",
                    subtitle = "When a hospital fires a Code Red near you, it appears here for you to accept.",
                )
                else -> LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(12.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    // r1450 — an accept failure sets actionError but that only
                    // renders inside the decline sheet; show it inline too so a
                    // failed accept isn't silent.
                    if (declineFor == null) {
                        state.actionError?.let { msg ->
                            item(key = "action-error") {
                                Text(msg, style = EsType.BodySm, color = SevaDanger500, modifier = Modifier.padding(horizontal = 4.dp))
                            }
                        }
                    }
                    if (state.accepted.isNotEmpty()) {
                        item(key = "accepted-header") {
                            Text(
                                "You're attending",
                                style = EsType.H5,
                                color = SevaInk900,
                                modifier = Modifier.padding(horizontal = 4.dp, vertical = 2.dp),
                            )
                        }
                        items(state.accepted, key = { "acc-${it.id}" }) { cr ->
                            AcceptedCodeRedCard(cr = cr)
                        }
                        if (state.items.isNotEmpty()) {
                            item(key = "open-header") {
                                Text(
                                    "Also paged to you",
                                    style = EsType.H5,
                                    color = SevaInk900,
                                    modifier = Modifier.padding(horizontal = 4.dp, vertical = 2.dp),
                                )
                            }
                        }
                    }
                    items(state.items, key = { it.id }) { cr ->
                        CodeRedCard(
                            cr = cr,
                            now = now,
                            working = state.working,
                            onAccept = { viewModel.accept(cr.id) {} },
                            onDecline = { declineFor = cr.id },
                        )
                    }
                    item(key = "tail") { Spacer(Modifier.height(8.dp)) }
                }
            }
        }
    }
}

@Composable
private fun CodeRedCard(
    cr: CodeRedRepository.CodeRed,
    now: Long,
    working: Boolean,
    onAccept: () -> Unit,
    onDecline: () -> Unit,
) {
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
                codeRedEquipmentTitle(cr.equipmentType, cr.equipmentBrand, cr.equipmentModel),
                style = EsType.Body.copy(fontWeight = FontWeight.Bold),
                color = SevaInk900,
                modifier = Modifier.weight(1f),
            )
            Pill(text = "SOS", kind = PillKind.Danger)
        }
        Text(cr.description, style = EsType.BodySm, color = SevaInk700)
        cr.slaDeadlineAt?.takeIf { it.isNotBlank() }?.let { iso ->
            val countdown = slaCountdownLabel(iso, now)
            if (countdown != null) {
                val urgent = slaUrgency(iso, now) != SlaUrgency.Ok
                Text(
                    "$countdown · respond by ${prettyDate(iso)}",
                    style = EsType.Caption.copy(fontWeight = if (urgent) FontWeight.Bold else FontWeight.Normal),
                    color = if (urgent) SevaDanger500 else SevaInk500,
                )
            } else {
                Text("Respond by ${prettyDate(iso)}", style = EsType.Caption, color = SevaInk500)
            }
        }
        Text(
            "Up to ${formatRupees(cr.feeCeilingRupees)} emergency fee" +
                (cr.distanceKmAtPage?.let { " · ${formatDistanceKm(it)} away" } ?: ""),
            style = EsType.Caption,
            color = SevaInk500,
        )
        Row(
            modifier = Modifier.fillMaxWidth().padding(top = 4.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            EsBtn(
                text = "Decline",
                onClick = onDecline,
                kind = EsBtnKind.Ghost,
                size = EsBtnSize.Sm,
                disabled = working,
                modifier = Modifier.weight(1f),
            )
            EsBtn(
                text = "Accept",
                onClick = onAccept,
                kind = EsBtnKind.Lime,
                size = EsBtnSize.Sm,
                disabled = working,
                modifier = Modifier.weight(1f),
            )
        }
    }
}

@Composable
private fun AcceptedCodeRedCard(cr: CodeRedRepository.CodeRed) {
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
                codeRedEquipmentTitle(cr.equipmentType, cr.equipmentBrand, cr.equipmentModel),
                style = EsType.Body.copy(fontWeight = FontWeight.Bold),
                color = SevaInk900,
                modifier = Modifier.weight(1f),
            )
            Pill(text = "Accepted", kind = PillKind.Success)
        }
        Text(cr.description, style = EsType.BodySm, color = SevaInk700)
        val warroom = cr.warroomUrl?.takeIf { it.isNotBlank() }
        if (warroom != null) {
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
private fun DeclineSheet(
    working: Boolean,
    error: String?,
    onClose: () -> Unit,
    onSubmit: (reason: String) -> Unit,
) {
    var reason by rememberSaveable { mutableStateOf("") }
    EsBottomSheet(onClose = onClose, title = "Decline emergency") {
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text(
                "Skipping this Code Red. A short reason helps us route the next engineer (optional).",
                style = EsType.BodySm,
                color = SevaInk700,
            )
            EsField(
                value = reason,
                onChange = { reason = it },
                label = "Reason (optional)",
                placeholder = "e.g. On another job",
                imeAction = ImeAction.Done,
            )
            if (error != null) {
                Text(error, style = EsType.BodySm, color = com.equipseva.app.designsystem.theme.SevaDanger500)
            }
            EsBtn(
                text = if (working) "Declining…" else "Confirm decline",
                onClick = { onSubmit(reason) },
                kind = EsBtnKind.DangerOutline,
                size = EsBtnSize.Lg,
                full = true,
                disabled = working,
            )
            Spacer(Modifier.height(4.dp))
        }
    }
}

// ---------------------------------------------------------------------
//  Pinned helpers
// ---------------------------------------------------------------------

/** Title line for a Code Red card: type plus any brand/model, space-joined
 *  and trimmed. Never blank (falls back to the type). */
internal fun codeRedEquipmentTitle(type: String, brand: String?, model: String?): String {
    val tail = listOfNotNull(brand?.trim()?.ifBlank { null }, model?.trim()?.ifBlank { null }).joinToString(" ")
    return listOf(type.trim(), tail).filter { it.isNotBlank() }.joinToString(" · ").ifBlank { "Equipment" }
}

/** Distance label: drops a redundant .0 and appends " km". */
internal fun formatDistanceKm(km: Double): String {
    val n = if (km % 1.0 == 0.0) km.toLong().toString() else km.toString()
    return "$n km"
}
