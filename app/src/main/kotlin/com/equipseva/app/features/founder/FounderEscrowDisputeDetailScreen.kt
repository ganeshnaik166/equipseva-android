package com.equipseva.app.features.founder

import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Inbox
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
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
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.core.util.prettyDateTime
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaDanger500
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk700
import com.equipseva.app.designsystem.theme.SevaInk900
import com.equipseva.app.designsystem.theme.SevaWarning500
import com.equipseva.app.navigation.Routes
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

@HiltViewModel
class FounderEscrowDisputeDetailViewModel @Inject constructor(
    private val repo: FounderRepository,
    savedStateHandle: SavedStateHandle,
) : ViewModel() {
    private val escrowId: String =
        savedStateHandle.get<String>(Routes.FOUNDER_ESCROW_DISPUTE_DETAIL_ARG_ESCROW_ID).orEmpty()

    data class UiState(
        val loading: Boolean = true,
        // Round 416 — pull-to-refresh inline indicator distinct from cold-load.
        val refreshing: Boolean = false,
        val error: String? = null,
        val rows: List<FounderRepository.EscrowEventRow> = emptyList(),
        val track: FounderRepository.DisputePartyTrackRecord? = null,
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init { reload(initial = true) }

    fun onPullToRefresh() = reload(initial = false)

    fun reload(initial: Boolean = false) {
        if (escrowId.isBlank()) {
            _state.update { it.copy(loading = false, refreshing = false, error = "Missing escrow id") }
            return
        }
        _state.update {
            it.copy(
                loading = initial || it.rows.isEmpty(),
                refreshing = !initial && it.rows.isNotEmpty(),
                error = null,
            )
        }
        viewModelScope.launch {
            val timeline = repo.fetchEscrowEventTimeline(escrowId)
            val track = repo.fetchDisputePartyTrackRecord(escrowId)
            timeline
                .onSuccess { rows ->
                    _state.update { it.copy(loading = false, refreshing = false, rows = rows, track = track.getOrNull()) }
                }
                .onFailure { e ->
                    _state.update { it.copy(loading = false, refreshing = false, error = e.toUserMessage()) }
                }
        }
    }
}

@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
fun FounderEscrowDisputeDetailScreen(
    onBack: () -> Unit,
    viewModel: FounderEscrowDisputeDetailViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    // Round 429 — refresh on return so new admin notes / status flips
    // landed while the user was off-screen surface immediately.
    com.equipseva.app.designsystem.util.RefreshOnReturn { viewModel.reload() }
    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(
                title = "Escrow timeline",
                subtitle = state.rows.size.takeIf { it > 0 }?.let { if (it == 1) "1 event" else "$it events" },
                onBack = onBack,
            )
            // Round 416 — pull-to-refresh. Admin reviewing a dispute timeline
            // wants to pick up new events (admin comments, resolution events)
            // without backing out + re-entering.
            androidx.compose.material3.pulltorefresh.PullToRefreshBox(
                isRefreshing = state.refreshing,
                onRefresh = viewModel::onPullToRefresh,
                modifier = Modifier.fillMaxSize(),
            ) {
                when {
                    state.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator()
                    }
                    state.error != null && state.rows.isEmpty() -> EmptyStateView(
                        icon = Icons.Outlined.Inbox,
                        title = "Couldn't load",
                        subtitle = state.error,
                        ctaLabel = "Try again",
                        onCta = { viewModel.reload() },
                    )
                    state.rows.isEmpty() -> EmptyStateView(
                        icon = Icons.Outlined.Inbox,
                        title = "No events",
                        subtitle = "This escrow has no recorded events.",
                    )
                    else -> LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(12.dp),
                        verticalArrangement = Arrangement.spacedBy(0.dp),
                    ) {
                        // PR-D35: dispute-pattern context. 90-day breakdown
                        // for both parties so admin can see "this hospital
                        // filed 5 disputes, 1 upheld" before deciding.
                        state.track?.let { rec ->
                            item("track") { TrackRecordCard(rec) }
                        }
                        items(state.rows, key = { it.eventId }) { row -> EscrowEventRow(row) }
                    }
                }
            }
        }
    }
}

@Composable
private fun EscrowEventRow(row: FounderRepository.EscrowEventRow) {
    val tint = when (row.eventKind) {
        "created" -> SevaInk700
        "paid", "released" -> SevaGreen700
        "release_scheduled" -> SevaInk700
        "disputed" -> SevaDanger500
        "dispute_resolved" -> SevaWarning500
        "refunded", "cancelled" -> SevaDanger500
        else -> SevaInk500
    }
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 8.dp),
        verticalAlignment = Alignment.Top,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.width(20.dp)) {
            Box(
                modifier = Modifier
                    .size(12.dp)
                    .clip(CircleShape)
                    .background(tint),
            )
            Box(
                modifier = Modifier
                    .padding(top = 4.dp)
                    .width(2.dp)
                    .height(36.dp)
                    .background(BorderDefault),
            )
        }
        Column(
            modifier = Modifier
                .weight(1f)
                .clip(RoundedCornerShape(10.dp))
                .background(Color.White)
                .border(1.dp, BorderDefault, RoundedCornerShape(10.dp))
                .padding(12.dp),
            verticalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            Text(
                text = escrowEventKindLabel(row.eventKind),
                fontSize = 13.sp,
                fontWeight = FontWeight.SemiBold,
                color = SevaInk900,
            )
            row.occurredAt?.let {
                Text("Occurred: ${prettyDateTime(it)}", color = SevaInk500, fontSize = 11.sp)
            }
            val actorLabel = escrowEventActorLine(row.actorName, row.actorUserId)
            if (actorLabel != null) {
                Text(actorLabel, color = SevaInk500, fontSize = 11.sp)
            }
            val payloadText = escrowEventPayloadDisplay(row.payload?.toString())
            if (payloadText != null) {
                Text(
                    text = payloadText,
                    color = SevaInk700,
                    fontSize = 11.sp,
                )
            }
        }
    }
}

@Composable
private fun TrackRecordCard(rec: FounderRepository.DisputePartyTrackRecord) {
    androidx.compose.foundation.layout.Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(bottom = 12.dp)
            .clip(androidx.compose.foundation.shape.RoundedCornerShape(12.dp))
            .background(Color.White)
            .border(
                1.dp,
                com.equipseva.app.designsystem.theme.BorderDefault,
                androidx.compose.foundation.shape.RoundedCornerShape(12.dp),
            )
            .padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Text(
            text = "PARTY TRACK RECORD · LAST 90 DAYS",
            color = SevaInk500,
            fontSize = 11.sp,
            fontWeight = androidx.compose.ui.text.font.FontWeight.SemiBold,
            letterSpacing = 0.5.sp,
        )
        TrackPartyRow(
            label = "Hospital",
            filed = rec.hospitalDisputesFiled,
            wonLabel = "won",
            won = rec.hospitalDisputesWon,
            lost = rec.hospitalDisputesLost,
            open = rec.hospitalDisputesOpen,
        )
        TrackPartyRow(
            label = "Engineer",
            filed = rec.engineerDisputesRecv,
            wonLabel = "released to them",
            won = rec.engineerDisputesWon,
            lost = rec.engineerDisputesLost,
            open = rec.engineerDisputesOpen,
        )
        if (rec.hospitalDisputesFiled >= 3 || rec.engineerDisputesRecv >= 3) {
            Text(
                text = "Pattern flag — 3+ disputes in window. Weight evidence accordingly.",
                color = SevaWarning500,
                fontSize = 11.sp,
                fontWeight = androidx.compose.ui.text.font.FontWeight.SemiBold,
            )
        }
    }
}

@Composable
private fun TrackPartyRow(
    label: String,
    filed: Int,
    wonLabel: String,
    won: Int,
    lost: Int,
    open: Int,
) {
    androidx.compose.foundation.layout.Column(
        verticalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        Text(
            text = label,
            color = com.equipseva.app.designsystem.theme.SevaInk900,
            fontSize = 13.sp,
            fontWeight = androidx.compose.ui.text.font.FontWeight.SemiBold,
        )
        Text(
            text = "$filed total · $won $wonLabel · $lost lost · $open open",
            color = SevaInk700,
            fontSize = 12.sp,
        )
    }
}

/**
 * Event-kind label on the founder escrow-dispute timeline.
 *
 * Server stores snake_case event kinds (`created`, `release_scheduled`,
 * `dispute_resolved`, …); render as Title-cased prose with underscores
 * → spaces and first-letter capitalised.
 *
 * Pin so a refactor to a lookup table doesn't accidentally drop the
 * underscore→space step (would surface "Dispute_resolved").
 */
internal fun escrowEventKindLabel(eventKind: String): String =
    eventKind.replace('_', ' ').replaceFirstChar { it.uppercase() }

/**
 * Actor line on the founder escrow-dispute timeline event row.
 *
 * 3-state decision tree:
 *   1. actorName non-blank AND not "(system)" placeholder → "Actor: $name"
 *   2. actorName is blank OR is "(system)" → if actorUserId is null,
 *      surface "Actor: system" (the explicit system-actor label).
 *      Otherwise return null (don't show actor at all — there IS a
 *      user but the name didn't resolve, so showing "Actor: (system)"
 *      or "Actor:" would be misleading).
 *
 * Pin the "(system)" placeholder check — this is a server-side
 * sentinel that mustn't leak to the UI. Pin the actorUserId-null
 * gate too — a non-null userId without a resolved name is a join
 * miss, not a system event.
 */
internal fun escrowEventActorLine(actorName: String?, actorUserId: String?): String? = when {
    !actorName.isNullOrBlank() && actorName != "(system)" -> "Actor: $actorName"
    actorUserId == null -> "Actor: system"
    else -> null
}

/**
 * Payload display on the founder escrow-dispute timeline event row.
 *
 * Returns null when the payload is null, blank, or the JSON-empty
 * "{}" sentinel. Otherwise returns the payload string verbatim for
 * direct rendering.
 *
 * Critical pin: the "{}" filter — JSONB columns surface "{}" for
 * events with no extra data, and rendering that as a literal in the
 * UI would be visual noise.
 */
internal fun escrowEventPayloadDisplay(payloadText: String?): String? =
    payloadText?.takeIf { it.isNotBlank() && it != "{}" }
