package com.equipseva.app.features.home

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.TrendingUp
import androidx.compose.material3.Icon
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
import androidx.compose.material3.Text
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.SevaGreen50
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk900
import com.equipseva.app.features.engineer.EngineerGraduationRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import java.text.NumberFormat
import java.util.Locale
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

@HiltViewModel
class HomeEngineerTierChipViewModel @Inject constructor(
    private val repo: EngineerGraduationRepository,
) : ViewModel() {
    data class UiState(
        val loading: Boolean = true,
        val data: EngineerGraduationRepository.TierEarningsProjection? = null,
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init {
        viewModelScope.launch {
            repo.fetchTierEarningsProjection()
                .onSuccess { row ->
                    _state.update { UiState(loading = false, data = row) }
                }
                .onFailure {
                    // Silent fail — chip simply hides. No noisy error on home.
                    _state.update { UiState(loading = false, data = null) }
                }
        }
    }
}

@Composable
fun HomeEngineerTierChip(
    onClick: () -> Unit,
    viewModel: HomeEngineerTierChipViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val d = state.data ?: return  // hide silently when no data
    if (state.loading) return

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(SevaGreen50)
            .border(1.dp, SevaGreen700, RoundedCornerShape(12.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Icon(
            imageVector = Icons.Outlined.TrendingUp,
            contentDescription = null,
            modifier = Modifier.size(20.dp),
            tint = SevaGreen700,
        )
        Spacer(modifier = Modifier.size(0.dp))
        when {
            d.nextTier == null -> {
                Text(
                    text = "${d.currentTier.replaceFirstChar { it.uppercase() }} tier · top of ladder",
                    style = EsType.BodySm.copy(fontWeight = FontWeight.SemiBold),
                    color = SevaInk900,
                )
            }
            d.projectedMonthlyUpliftRupees > 0.0 -> {
                Text(
                    text = "Reach ${d.nextTier.replaceFirstChar { it.uppercase() }} → ${formatRupees(d.projectedMonthlyUpliftRupees)}/mo more",
                    style = EsType.BodySm.copy(fontWeight = FontWeight.SemiBold),
                    color = SevaInk900,
                )
            }
            else -> {
                Text(
                    text = "Currently ${d.currentTier.replaceFirstChar { it.uppercase() }} · next ${d.nextTier.replaceFirstChar { it.uppercase() }}",
                    style = EsType.BodySm.copy(fontWeight = FontWeight.SemiBold),
                    color = SevaInk900,
                )
            }
        }
    }
}

private val rupeeFmt: NumberFormat =
    NumberFormat.getCurrencyInstance(Locale("en", "IN")).apply {
        maximumFractionDigits = 0
    }

private fun formatRupees(amount: Double): String = rupeeFmt.format(amount)
