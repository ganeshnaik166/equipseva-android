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
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaInk900
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
    val tone = when (top.amcTier) {
        "gold" -> SevaGreen700
        else -> SevaInk900
    }

    val daysLeft = daysUntil(top.endDate)
    val expiryLine = when {
        daysLeft == null -> top.endDate
        daysLeft <= 0 -> "expires today"
        daysLeft <= 30 -> "expires in $daysLeft days"
        else -> top.endDate
    }

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

private fun daysUntil(isoDate: String): Long? = try {
    val end = LocalDate.parse(isoDate)
    val today = LocalDate.now()
    ChronoUnit.DAYS.between(today, end)
} catch (_: DateTimeParseException) {
    null
}
