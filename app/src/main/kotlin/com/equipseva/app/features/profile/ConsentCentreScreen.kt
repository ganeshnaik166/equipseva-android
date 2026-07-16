package com.equipseva.app.features.profile

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.PrivacyTip
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
import com.equipseva.app.core.data.consent.ConsentGroup
import com.equipseva.app.core.data.consent.ConsentRepository
import com.equipseva.app.core.data.consent.consentTypeLabel
import com.equipseva.app.core.data.consent.groupConsents
import com.equipseva.app.core.data.consent.isWithdrawableConsent
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
import com.equipseva.app.designsystem.theme.PaperDefault
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
class ConsentCentreViewModel @Inject constructor(
    private val repo: ConsentRepository,
) : ViewModel() {
    data class UiState(
        val loading: Boolean = true,
        val refreshing: Boolean = false,
        val error: String? = null,
        val groups: List<ConsentGroup> = emptyList(),
        // r1418 — grant/withdraw toggle for optional consents.
        val togglingType: String? = null,
        val actionError: String? = null,
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init { reload(initial = true) }

    fun reload(initial: Boolean = false) {
        _state.update {
            it.copy(
                loading = initial || it.groups.isEmpty(),
                refreshing = !initial && it.groups.isNotEmpty(),
                error = null,
            )
        }
        viewModelScope.launch {
            repo.fetch()
                .onSuccess { rows ->
                    _state.update { it.copy(loading = false, refreshing = false, groups = groupConsents(rows)) }
                }
                .onFailure { e ->
                    _state.update {
                        if (it.groups.isEmpty()) it.copy(loading = false, refreshing = false, error = e.toUserMessage())
                        else it.copy(loading = false, refreshing = false)
                    }
                }
        }
    }

    fun onPullToRefresh() = reload(initial = false)

    /** Grant ⇄ withdraw an optional consent, reusing the row's existing policy
     *  version so the ledger references the same document. Append-only server-
     *  side; on success the latest state changes, so we reload. */
    fun onToggle(row: ConsentRepository.ConsentRow) {
        if (_state.value.togglingType != null) return
        val newAction = if (row.action == "granted") "revoked" else "granted"
        val version = row.documentVersion.ifBlank { "unversioned" }
        _state.update { it.copy(togglingType = row.consentType, actionError = null) }
        viewModelScope.launch {
            repo.record(row.consentType, version, newAction)
                .onSuccess {
                    _state.update { it.copy(togglingType = null) }
                    reload()
                }
                .onFailure { e -> _state.update { it.copy(togglingType = null, actionError = e.toUserMessage()) } }
        }
    }
}

/**
 * Read-only DPDP consent centre: the current state (granted / withdrawn), the
 * exact policy version, and the date for each consent the user has recorded,
 * grouped by category. Reachable from the Profile "Privacy & consents" row
 * (both roles). Surfaces current_consents() (round 485), which had no Android
 * screen before r1402.
 */
@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
fun ConsentCentreScreen(
    onBack: () -> Unit,
    viewModel: ConsentCentreViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    com.equipseva.app.designsystem.util.RefreshOnReturn { viewModel.reload() }

    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(title = "Privacy & consents", onBack = onBack)
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
                        icon = Icons.Outlined.PrivacyTip,
                        title = "Couldn't load consents",
                        subtitle = state.error,
                        ctaLabel = "Try again",
                        onCta = { viewModel.reload() },
                    )
                    state.groups.isEmpty() -> EmptyStateView(
                        icon = Icons.Outlined.PrivacyTip,
                        title = "No consents recorded yet",
                        subtitle = "The permissions and policy agreements you accept appear here, with the version and date — as required under India's DPDP Act.",
                    )
                    else -> LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(12.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        if (state.actionError != null) {
                            item(key = "actionError") {
                                Text(
                                    state.actionError!!,
                                    color = Color(0xFFC62828),
                                    fontSize = 12.sp,
                                    modifier = Modifier.padding(horizontal = 4.dp),
                                )
                            }
                        }
                        state.groups.forEach { group ->
                            item(key = "cat-${group.categoryLabel}") { CategoryHeader(group.categoryLabel) }
                            items(group.rows, key = { it.consentType }) { row ->
                                ConsentRow(
                                    row = row,
                                    toggling = state.togglingType == row.consentType,
                                    onToggle = { viewModel.onToggle(row) },
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun CategoryHeader(label: String) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(SevaGreen50)
            .padding(horizontal = 14.dp, vertical = 8.dp),
    ) {
        Text(label, color = SevaInk900, fontWeight = FontWeight.Bold, fontSize = 13.sp)
    }
}

@Composable
private fun ConsentRow(
    row: ConsentRepository.ConsentRow,
    toggling: Boolean,
    onToggle: () -> Unit,
) {
    val (pillText, pillKind) = consentActionPillTextAndKind(row.action)
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
            .padding(12.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(consentTypeLabel(row.consentType), color = SevaInk900, fontWeight = FontWeight.Medium, fontSize = 14.sp)
                val meta = listOfNotNull(
                    row.documentVersion.takeIf { it.isNotBlank() },
                    row.grantedAt?.takeIf { it.isNotBlank() }?.let { prettyDate(it) },
                ).joinToString(" · ")
                if (meta.isNotEmpty()) {
                    Text(meta, color = SevaInk500, fontSize = 12.sp)
                }
            }
            Pill(text = pillText, kind = pillKind)
        }
        if (isWithdrawableConsent(row.consentType)) {
            val granted = row.action == "granted"
            EsBtn(
                text = consentToggleLabel(granted, toggling),
                onClick = onToggle,
                kind = if (granted) EsBtnKind.Ghost else EsBtnKind.Primary,
                size = EsBtnSize.Sm,
                disabled = toggling,
            )
        }
    }
}

/** Label for the consent grant/withdraw toggle. */
internal fun consentToggleLabel(granted: Boolean, busy: Boolean): String = when {
    busy -> "Updating…"
    granted -> "Withdraw"
    else -> "Re-grant"
}

/**
 * Consent action → pill. "granted" reads Success; "revoked" reads Neutral
 * ("Withdrawn" — a user choice, not an error); any other action capitalises
 * with a Neutral tone (defensive default).
 */
internal fun consentActionPillTextAndKind(action: String): Pair<String, PillKind> = when (action) {
    "granted" -> "Granted" to PillKind.Success
    "revoked" -> "Withdrawn" to PillKind.Neutral
    else -> action.replaceFirstChar { it.uppercase() } to PillKind.Neutral
}
