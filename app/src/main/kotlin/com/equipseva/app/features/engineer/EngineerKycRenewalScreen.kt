package com.equipseva.app.features.engineer

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Autorenew
import androidx.compose.material.icons.outlined.VerifiedUser
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
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.data.engineers.KycRenewalRepository
import com.equipseva.app.core.data.engineers.formatRenewalDue
import com.equipseva.app.core.data.engineers.renewalItemLabel
import com.equipseva.app.core.data.engineers.renewalUrgency
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.core.util.prettyDate
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.EsBtn
import com.equipseva.app.designsystem.components.EsBtnKind
import com.equipseva.app.designsystem.components.EsBtnSize
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.components.Pill
import com.equipseva.app.designsystem.components.PillKind
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaDanger500
import com.equipseva.app.designsystem.theme.SevaGreen50
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
class EngineerKycRenewalViewModel @Inject constructor(
    private val repo: KycRenewalRepository,
) : ViewModel() {
    data class UiState(
        val loading: Boolean = true,
        val error: String? = null,
        val loaded: Boolean = false,
        val data: KycRenewalRepository.KycRenewal? = null,
        // r1431 — checklist actions.
        val starting: Boolean = false,
        val busyItem: String? = null,
        val actionError: String? = null,
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init { reload() }

    fun reload() {
        _state.update { it.copy(loading = !it.loaded, error = null) }
        viewModelScope.launch {
            repo.fetch()
                .onSuccess { d -> _state.update { it.copy(loading = false, loaded = true, data = d) } }
                .onFailure { e ->
                    // r1441: a transient reload failure after a successful
                    // start/mark must not wipe the still-valid checklist — only
                    // go full-screen fatal on the initial load (no data yet).
                    _state.update {
                        if (it.data == null) it.copy(loading = false, error = e.toUserMessage())
                        else it.copy(loading = false, actionError = e.toUserMessage())
                    }
                }
        }
    }

    /** Begin the renewal (pending -> in_progress), then reload. */
    fun start() {
        val id = _state.value.data?.id ?: return
        if (_state.value.starting) return
        _state.update { it.copy(starting = true, actionError = null) }
        viewModelScope.launch {
            repo.start(id)
                .onSuccess { _state.update { it.copy(starting = false) }; reload() }
                .onFailure { e -> _state.update { it.copy(starting = false, actionError = e.toUserMessage()) } }
        }
    }

    /** Flag one required item refreshed, then reload so it leaves the list. */
    fun markRefreshed(item: String) {
        val id = _state.value.data?.id ?: return
        if (_state.value.busyItem != null) return
        _state.update { it.copy(busyItem = item, actionError = null) }
        viewModelScope.launch {
            repo.markItemRefreshed(id, item)
                .onSuccess { _state.update { it.copy(busyItem = null) }; reload() }
                .onFailure { e -> _state.update { it.copy(busyItem = null, actionError = e.toUserMessage()) } }
        }
    }
}

/**
 * "KYC renewal" — verified engineers are re-verified roughly yearly. When a
 * cycle is open this shows what's left to refresh, when it's due, and a CTA
 * into the KYC re-upload flow; otherwise it reassures the engineer they're up
 * to date. Surfaces my_kyc_renewal() (round 497), which had no Android screen
 * before r1401. Keeps the "verified engineer" trust promise real over time.
 */
@Composable
fun EngineerKycRenewalScreen(
    onBack: () -> Unit,
    onRenew: () -> Unit,
    viewModel: EngineerKycRenewalViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    com.equipseva.app.designsystem.util.RefreshOnReturn { viewModel.reload() }

    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(title = "KYC renewal", onBack = onBack)
            when {
                state.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }
                state.error != null -> EmptyStateView(
                    icon = Icons.Outlined.Autorenew,
                    title = "Couldn't load renewal status",
                    subtitle = state.error,
                    ctaLabel = "Try again",
                    onCta = { viewModel.reload() },
                )
                state.data == null -> EmptyStateView(
                    icon = Icons.Outlined.VerifiedUser,
                    title = "You're up to date",
                    subtitle = "No re-verification is due right now. We'll nudge you here when your yearly KYC refresh comes up.",
                )
                else -> {
                    val d = state.data!!
                    Column(
                        modifier = Modifier
                            .fillMaxSize()
                            .verticalScroll(rememberScrollState())
                            .padding(16.dp),
                        verticalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        DueCard(daysUntilDue = d.daysUntilDue, dueAt = d.dueAt, graceUntil = d.graceUntil)
                        state.actionError?.let {
                            Text(it, style = EsType.BodySm, color = SevaDanger500)
                        }
                        when {
                            d.remainingItems.isEmpty() -> Text(
                                "All documents refreshed — we're finishing your re-verification.",
                                style = EsType.Body,
                                color = SevaInk700,
                            )
                            d.status == "pending" -> {
                                Text(
                                    "Start your renewal, then re-upload each document and mark it done. Your verified badge holds through the grace window.",
                                    style = EsType.BodySm,
                                    color = SevaInk700,
                                )
                                EsBtn(
                                    text = if (state.starting) "Starting…" else "Start renewal",
                                    onClick = { viewModel.start() },
                                    kind = EsBtnKind.Primary,
                                    size = EsBtnSize.Lg,
                                    full = true,
                                    disabled = state.starting,
                                )
                            }
                            else -> {
                                Text("Still to refresh", style = EsType.H5, color = SevaInk900, modifier = Modifier.padding(top = 4.dp))
                                d.remainingItems.forEach { key ->
                                    ItemRow(
                                        label = renewalItemLabel(key),
                                        busy = state.busyItem == key,
                                        onMarkDone = { viewModel.markRefreshed(key) },
                                    )
                                }
                                Spacer(Modifier.height(4.dp))
                                EsBtn(
                                    text = "Re-upload documents",
                                    onClick = onRenew,
                                    kind = EsBtnKind.Secondary,
                                    size = EsBtnSize.Lg,
                                    full = true,
                                )
                            }
                        }
                        Spacer(Modifier.height(8.dp))
                    }
                }
            }
        }
    }
}

@Composable
private fun DueCard(daysUntilDue: Double, dueAt: String?, graceUntil: String?) {
    val (pillText, pillKind) = renewalPillTextAndKind(daysUntilDue)
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(SevaGreen50)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text("Re-verification", style = EsType.BodySm, color = SevaInk700)
            Pill(text = pillText, kind = pillKind)
        }
        Text(formatRenewalDue(daysUntilDue), style = EsType.H4.copy(fontWeight = FontWeight.Bold), color = SevaInk900)
        dueAt?.takeIf { it.isNotBlank() }?.let {
            Text("Due ${prettyDate(it)}", style = EsType.Caption, color = SevaInk500)
        }
        graceUntil?.takeIf { it.isNotBlank() }?.let {
            Text("Verified status holds through the grace window until ${prettyDate(it)}.", style = EsType.Caption, color = SevaInk500)
        }
    }
}

@Composable
private fun ItemRow(label: String, busy: Boolean, onMarkDone: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(10.dp))
            .padding(start = 14.dp, top = 8.dp, bottom = 8.dp, end = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Text("○", color = SevaInk500, style = EsType.Body)
        Text(label, style = EsType.Body, color = SevaInk900, modifier = Modifier.weight(1f))
        EsBtn(
            text = if (busy) "Saving…" else "Mark done",
            onClick = onMarkDone,
            kind = EsBtnKind.Secondary,
            size = EsBtnSize.Sm,
            disabled = busy,
        )
    }
}

/**
 * Renewal urgency → nudge pill. Reuses [renewalUrgency]:
 *   * overdue   → "Overdue"   (Danger)
 *   * due_soon  → "Due soon"  (Warn)
 *   * scheduled → "Scheduled" (Info)
 */
internal fun renewalPillTextAndKind(daysUntilDue: Double): Pair<String, PillKind> =
    when (renewalUrgency(daysUntilDue)) {
        "overdue" -> "Overdue" to PillKind.Danger
        "due_soon" -> "Due soon" to PillKind.Warn
        else -> "Scheduled" to PillKind.Info
    }
