package com.equipseva.app.features.profile

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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Shield
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
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
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.components.Pill
import com.equipseva.app.designsystem.components.PillKind
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaDanger500
import com.equipseva.app.designsystem.theme.SevaGreen700
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
class KycRenewalViewModel @Inject constructor(
    private val repo: KycRenewalRepository,
) : ViewModel() {

    data class UiState(
        val loading: Boolean = true,
        val error: String? = null,
        val renewal: KycRenewalRepository.KycRenewal? = null,
        val busyItem: String? = null,
        val starting: Boolean = false,
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init {
        refresh()
    }

    fun refresh() {
        _state.update { it.copy(loading = true, error = null) }
        viewModelScope.launch {
            repo.fetchMyRenewal()
                .onSuccess { r -> _state.update { UiState(loading = false, renewal = r) } }
                .onFailure { e ->
                    _state.update { UiState(loading = false, error = e.toUserMessage("Could not load your KYC renewal status.")) }
                }
        }
    }

    fun startRenewal(renewalId: String) {
        _state.update { it.copy(starting = true) }
        viewModelScope.launch {
            repo.startRenewal(renewalId)
                .onSuccess { _state.update { it.copy(starting = false) }; refresh() }
                .onFailure { e -> _state.update { it.copy(starting = false, error = e.toUserMessage()) } }
        }
    }

    fun markItemRefreshed(renewalId: String, item: String) {
        _state.update { it.copy(busyItem = item) }
        viewModelScope.launch {
            repo.markItemRefreshed(renewalId, item)
                .onSuccess { _state.update { it.copy(busyItem = null) }; refresh() }
                .onFailure { e -> _state.update { it.copy(busyItem = null, error = e.toUserMessage()) } }
        }
    }
}

@Composable
fun KycRenewalScreen(
    onBack: () -> Unit,
    viewModel: KycRenewalViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    Box(Modifier.fillMaxSize().background(PaperDefault)) {
        Column(Modifier.fillMaxSize()) {
            EsTopBar(title = stringResource(R.string.kyc_renewal_title), onBack = onBack)

            when {
                state.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }

                state.error != null && state.renewal == null -> EmptyStateView(
                    icon = Icons.Outlined.Shield,
                    title = stringResource(R.string.kyc_renewal_couldnt_load),
                    subtitle = state.error,
                    ctaLabel = stringResource(R.string.kyc_renewal_try_again),
                    onCta = { viewModel.refresh() },
                )

                state.renewal == null -> EmptyStateView(
                    icon = Icons.Outlined.Shield,
                    title = stringResource(R.string.kyc_renewal_empty_title),
                    subtitle = stringResource(R.string.kyc_renewal_empty_body),
                )

                else -> Column(
                    Modifier.fillMaxSize().padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(14.dp),
                ) {
                    RenewalCard(
                        r = state.renewal!!,
                        starting = state.starting,
                        busyItem = state.busyItem,
                        onStart = { viewModel.startRenewal(state.renewal!!.id) },
                        onMarkItem = { item -> viewModel.markItemRefreshed(state.renewal!!.id, item) },
                    )
                }
            }
        }
    }
}

@Composable
private fun RenewalCard(
    r: KycRenewalRepository.KycRenewal,
    starting: Boolean,
    busyItem: String?,
    onStart: () -> Unit,
    onMarkItem: (String) -> Unit,
) {
    val remaining = r.remainingItems ?: r.requiredItems.filterNot { it in r.refreshedItems }
    Box(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
            .padding(16.dp),
    ) {
        Column {
            Row(
                Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    kycRenewalDueInText(r.daysUntilDue),
                    style = EsType.H4.copy(fontWeight = FontWeight.Bold),
                    color = if (r.daysUntilDue < 0) SevaDanger500 else SevaInk900,
                )
                Pill(
                    text = if (r.status == "in_progress") "In progress" else "Action needed",
                    kind = if (r.status == "in_progress") PillKind.Info else PillKind.Warn,
                )
            }
            Spacer(Modifier.height(6.dp))
            Text(
                stringResource(R.string.kyc_renewal_grace_until, prettyDate(r.graceUntil)),
                style = EsType.BodySm,
                color = SevaInk500,
            )
            Spacer(Modifier.height(14.dp))
            if (r.status == "pending") {
                EsBtn(
                    text = if (starting) {
                        stringResource(R.string.kyc_renewal_starting)
                    } else {
                        stringResource(R.string.kyc_renewal_start)
                    },
                    onClick = onStart,
                    kind = EsBtnKind.Primary,
                    full = true,
                    disabled = starting,
                )
            } else {
                Text(
                    stringResource(R.string.kyc_renewal_items_title),
                    style = EsType.Body.copy(fontWeight = FontWeight.SemiBold),
                    color = SevaInk900,
                )
                Spacer(Modifier.height(8.dp))
                r.requiredItems.forEach { item ->
                    val done = item !in remaining
                    Row(
                        Modifier.fillMaxWidth().padding(vertical = 4.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(kycRenewalItemLabel(item), style = EsType.BodySm, color = SevaInk900)
                        if (done) {
                            Pill(text = stringResource(R.string.kyc_renewal_item_done), kind = PillKind.Success)
                        } else {
                            EsBtn(
                                text = if (busyItem == item) {
                                    stringResource(R.string.kyc_renewal_item_marking)
                                } else {
                                    stringResource(R.string.kyc_renewal_item_mark_done)
                                },
                                onClick = { onMarkItem(item) },
                                kind = EsBtnKind.Secondary,
                                size = com.equipseva.app.designsystem.components.EsBtnSize.Sm,
                                disabled = busyItem != null,
                            )
                        }
                    }
                }
            }
        }
    }
}

internal fun kycRenewalItemLabel(item: String): String = when (item) {
    "aadhaar" -> "Aadhaar"
    "degree_digilocker" -> "Degree (DigiLocker)"
    "police_verification" -> "Police verification"
    "photo" -> "Profile photo"
    else -> item.replace('_', ' ').replaceFirstChar { it.uppercase() }
}

/**
 * "Renewal overdue by N days" / "Renewal due today" / "Renewal due in
 * N days" from the server's fractional `days_until_due`.
 */
internal fun kycRenewalDueInText(daysUntilDue: Double): String {
    // Branch on the RAW sign first, not the rounded value: a renewal
    // that's -0.3 days from due has already passed its due_at, so it
    // must read as overdue — rounding -0.3 to 0 before checking the
    // sign would misreport it as "due today" instead (round()'s
    // nearest-value semantics cross zero for any |value| < 0.5).
    // overdueBy is floored at 1 so a just-crossed deadline never
    // shows "overdue by 0 days".
    return if (daysUntilDue < 0.0) {
        val overdueBy = kotlin.math.round(-daysUntilDue).toLong().coerceAtLeast(1L)
        if (overdueBy == 1L) "Renewal overdue by 1 day" else "Renewal overdue by $overdueBy days"
    } else if (daysUntilDue < 1.0) {
        "Renewal due today"
    } else {
        val n = kotlin.math.round(daysUntilDue).toLong()
        if (n == 1L) "Renewal due in 1 day" else "Renewal due in $n days"
    }
}
