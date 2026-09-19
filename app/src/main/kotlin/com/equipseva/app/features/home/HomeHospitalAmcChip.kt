package com.equipseva.app.features.home

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Verified
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.util.prettyDate
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.SevaDanger500
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaInk900
import com.equipseva.app.designsystem.theme.SevaWarning700
import com.equipseva.app.features.amc.HospitalAmcTierPerksRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import java.time.LocalDate
import java.time.format.DateTimeParseException
import java.time.temporal.ChronoUnit
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

@HiltViewModel
class HomeHospitalAmcChipViewModel @Inject constructor(
    private val repo: HospitalAmcTierPerksRepository,
) : ViewModel() {
    data class UiState(
        val loading: Boolean = true,
        val rows: List<HospitalAmcTierPerksRepository.TierPerks> = emptyList(),
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init {
        viewModelScope.launch {
            repo.fetchActiveTierPerks()
                .onSuccess { list ->
                    _state.update { UiState(loading = false, rows = list) }
                }
                .onFailure {
                    // Silent fail — chip just hides.
                    _state.update { UiState(loading = false, rows = emptyList()) }
                }
        }
    }
}

@Composable
fun HomeHospitalAmcChip(
    onClick: () -> Unit,
    viewModel: HomeHospitalAmcChipViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    if (state.loading || state.rows.isEmpty()) return

    // Pick the soonest-expiring contract (rows are already sorted ASC by
    // end_date server-side).
    val top = state.rows.first()
    val daysLeft = daysUntil(top.endDate)
    // r786 — urgency-tone overrides the tier-tone when the soonest contract
    // is expiring soon. Pulls the same signal as founder /amc-near-expiry
    // (r660) and AmcDetailScreen ExpiringSoonBanner (r784) onto the home
    // chip so hospitals see it without drilling in.
    val tone = when {
        daysLeft != null && daysLeft <= 7 -> SevaDanger500
        daysLeft != null && daysLeft <= 30 -> SevaWarning700
        top.amcTier == "gold" -> SevaGreen700
        else -> SevaInk900
    }

    val expiryLine = amcChipExpiryLine(daysLeft, top.endDate)

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(androidx.compose.ui.graphics.Color.White)
            .border(1.dp, tone, RoundedCornerShape(12.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Icon(
            imageVector = Icons.Outlined.Verified,
            contentDescription = null,
            modifier = Modifier.size(20.dp),
            tint = tone,
        )
        Text(
            text = "${top.displayLabel} · $expiryLine",
            style = EsType.BodySm.copy(fontWeight = FontWeight.SemiBold),
            color = SevaInk900,
        )
    }
}

/**
 * Expiry phrase on the hospital home AMC chip.
 *
 * Critical pins:
 *  - A negative [daysLeft] is an already-expired contract. It used to fall
 *    into the `<= 0` branch and read "expires today", which told the hospital
 *    its cover was still live on the day it had already lapsed.
 *  - The far branch and the unparseable branch render a formatted date;
 *    the raw server value ("2027-03-05") leaked the wire format into the UI.
 *  - Singular "1 day" — "expires in 1 days" is the classic plural slip on the
 *    last day before the danger tone takes over.
 */
internal fun amcChipExpiryLine(daysLeft: Long?, endDate: String): String = when {
    daysLeft == null -> prettyDate(endDate)
    daysLeft < 0L -> "expired on ${prettyDate(endDate)}"
    daysLeft == 0L -> "expires today"
    daysLeft == 1L -> "expires in 1 day"
    daysLeft <= 30L -> "expires in $daysLeft days"
    else -> "expires ${prettyDate(endDate)}"
}

private fun daysUntil(isoDate: String): Long? = try {
    val end = LocalDate.parse(isoDate)
    val today = LocalDate.now()
    ChronoUnit.DAYS.between(today, end)
} catch (_: DateTimeParseException) {
    null
}
