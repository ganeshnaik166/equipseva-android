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
import androidx.compose.material.icons.outlined.CheckCircleOutline
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.LinearProgressIndicator
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
import com.equipseva.app.designsystem.components.EmptyStateView
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
import com.equipseva.app.designsystem.theme.SevaWarning500
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

@HiltViewModel
class ProfileCompletenessViewModel @Inject constructor(
    private val repo: ProfileCompletenessRepository,
) : ViewModel() {

    data class UiState(
        val loading: Boolean = true,
        val error: String? = null,
        val completeness: ProfileCompletenessRepository.Completeness? = null,
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init {
        refresh()
    }

    fun refresh() {
        _state.update { it.copy(loading = true, error = null) }
        viewModelScope.launch {
            repo.fetchMyCompleteness()
                .onSuccess { c -> _state.update { UiState(loading = false, completeness = c) } }
                .onFailure { e ->
                    _state.update {
                        UiState(loading = false, error = e.toUserMessage("Could not load profile completeness."))
                    }
                }
        }
    }
}

@Composable
fun ProfileCompletenessScreen(
    onBack: () -> Unit,
    viewModel: ProfileCompletenessViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    Box(Modifier.fillMaxSize().background(PaperDefault)) {
        Column(Modifier.fillMaxSize()) {
            EsTopBar(title = stringResource(R.string.profile_completeness_title), onBack = onBack)

            when {
                state.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }

                state.error != null || state.completeness == null -> EmptyStateView(
                    icon = Icons.Outlined.CheckCircleOutline,
                    title = stringResource(R.string.profile_completeness_couldnt_load),
                    subtitle = state.error,
                    ctaLabel = stringResource(R.string.profile_completeness_try_again),
                    onCta = { viewModel.refresh() },
                )

                else -> Column(
                    Modifier.fillMaxSize().padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(14.dp),
                ) {
                    CompletenessCard(state.completeness!!)
                    if (state.completeness!!.missingItems.isNotEmpty()) {
                        MissingItemsCard(state.completeness!!.missingItems)
                    }
                }
            }
        }
    }
}

@Composable
private fun CompletenessCard(c: ProfileCompletenessRepository.Completeness) {
    val (label, kind, color) = profileCompletenessBandVisual(c.band)
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
                    "${c.score}%",
                    style = EsType.H2.copy(fontWeight = FontWeight.Bold),
                    color = color,
                )
                Pill(text = label, kind = kind)
            }
            Spacer(Modifier.height(10.dp))
            LinearProgressIndicator(
                progress = { (c.score.coerceIn(0, 100)) / 100f },
                modifier = Modifier.fillMaxWidth().height(8.dp).clip(RoundedCornerShape(4.dp)),
                color = color,
                trackColor = BorderDefault,
            )
        }
    }
}

@Composable
private fun MissingItemsCard(missingItems: List<String>) {
    Box(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
            .padding(16.dp),
    ) {
        Column {
            Text(
                stringResource(R.string.profile_completeness_missing_title),
                style = EsType.Body.copy(fontWeight = FontWeight.SemiBold),
                color = SevaInk900,
            )
            Spacer(Modifier.height(8.dp))
            missingItems.forEach { item ->
                Text(
                    "•  ${profileCompletenessMissingItemLabel(item)}",
                    style = EsType.BodySm,
                    color = SevaInk500,
                    modifier = Modifier.padding(vertical = 3.dp),
                )
            }
        }
    }
}

internal data class BandVisual(val label: String, val kind: PillKind, val color: Color)

internal fun profileCompletenessBandVisual(band: String): BandVisual = when (band) {
    "complete" -> BandVisual("Complete", PillKind.Success, SevaGreen700)
    "partial" -> BandVisual("Partial", PillKind.Warn, SevaWarning500)
    else -> BandVisual("Incomplete", PillKind.Danger, SevaDanger500)
}

/**
 * Maps the server's `missing_items` wire codes to engineer-facing
 * copy. Pin the full set — a code the app doesn't recognize still
 * needs SOME readable fallback rather than a raw snake_case string.
 */
internal fun profileCompletenessMissingItemLabel(code: String): String = when (code) {
    "engineer_profile_not_created" -> "Complete your engineer profile setup"
    "aadhaar_verification" -> "Verify your Aadhaar"
    "pan_verified" -> "Add and verify your PAN"
    "police_verification" -> "Complete police verification"
    "specializations" -> "Add at least one specialization"
    "certificates" -> "Upload at least one certificate"
    "profile_photo" -> "Add a profile photo"
    "location" -> "Set your service location"
    "profitability_floor" -> "Set your minimum payout floor"
    "gstin" -> "Add your GSTIN"
    "needs_6_completed_jobs" -> "Complete at least 6 jobs"
    else -> code.replace('_', ' ').replaceFirstChar { it.uppercase() }
}
