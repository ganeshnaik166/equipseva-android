package com.equipseva.app.features.hospital

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Redeem
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Surface
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
import com.equipseva.app.core.data.hospital.FirstJobFreeRepository
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.core.util.formatRupees
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.components.Pill
import com.equipseva.app.designsystem.components.PillKind
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaGreen50
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk700
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

@HiltViewModel
class FirstJobFreeViewModel @Inject constructor(
    private val repo: FirstJobFreeRepository,
) : ViewModel() {
    data class UiState(
        val loading: Boolean = true,
        val error: String? = null,
        val data: FirstJobFreeRepository.FirstJobFree? = null,
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init { reload() }

    fun reload() {
        _state.update { it.copy(loading = it.data == null, error = null) }
        viewModelScope.launch {
            repo.fetch()
                .onSuccess { d -> _state.update { it.copy(loading = false, data = d) } }
                .onFailure { e -> _state.update { it.copy(loading = false, error = e.toUserMessage()) } }
        }
    }
}

/**
 * Hospital "first job free" promo self-view (r1407): whether the caller
 * qualifies for the first-job platform-fee waiver, the rupee cap, and a
 * friendly reason when not eligible. Surfaces first_job_free_eligible()
 * (round 504), which had no Android screen before. Reachable from Profile.
 */
@Composable
fun FirstJobFreeScreen(
    onBack: () -> Unit,
    viewModel: FirstJobFreeViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    com.equipseva.app.designsystem.util.RefreshOnReturn { viewModel.reload() }

    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(title = "First job free", onBack = onBack)
            when {
                state.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }
                state.error != null || state.data == null -> EmptyStateView(
                    icon = Icons.Outlined.Redeem,
                    title = "Couldn't load offer",
                    subtitle = state.error ?: "No data available.",
                    ctaLabel = "Try again",
                    onCta = { viewModel.reload() },
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
                        OfferHeroCard(d)
                        if (d.eligible) {
                            Text(
                                "The waiver applies automatically to the platform fee on your first completed repair job — no code needed. Post a job to use it.",
                                style = EsType.Body,
                                color = SevaInk700,
                            )
                        } else {
                            Text(
                                firstJobFreeReasonLabel(d.reasonIfNot),
                                style = EsType.Body,
                                color = SevaInk700,
                            )
                        }
                        Spacer(Modifier.height(8.dp))
                    }
                }
            }
        }
    }
}

@Composable
private fun OfferHeroCard(d: FirstJobFreeRepository.FirstJobFree) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(SevaGreen50)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Pill(
            text = if (d.eligible) "Eligible" else "Not available",
            kind = if (d.eligible) PillKind.Success else PillKind.Neutral,
        )
        Text(
            firstJobFreeHeadline(d.eligible),
            style = EsType.H4.copy(fontWeight = FontWeight.Bold),
            color = SevaGreen700,
        )
        if (d.eligible && d.capRupees > 0) {
            Text(
                "Up to ${formatRupees(d.capRupees)} off the platform fee on your first completed job.",
                style = EsType.Caption,
                color = SevaInk500,
            )
        }
    }
}

// ---------------------------------------------------------------------
//  Pinned helpers
// ---------------------------------------------------------------------

/** Big line for the promo card. */
internal fun firstJobFreeHeadline(eligible: Boolean): String =
    if (eligible) "Your first repair job is free" else "This offer isn't available"

/**
 * Friendly explanation for the server reason code when not eligible. Unknown
 * codes degrade to a de-snaked fallback so a new server reason never renders a
 * raw token.
 */
internal fun firstJobFreeReasonLabel(reason: String?): String = when (reason) {
    null -> "You're eligible for this offer."
    "already_redeemed" -> "You've already used this offer."
    "not_first_time_user" -> "This offer is for first-time hospitals only — you've already completed a job with us."
    "account_under_review" -> "Your account is under review, so this offer isn't available right now."
    else -> reason.replace('_', ' ').replaceFirstChar { it.uppercase() }
}
