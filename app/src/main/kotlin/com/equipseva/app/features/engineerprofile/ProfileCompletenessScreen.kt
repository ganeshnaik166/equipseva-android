package com.equipseva.app.features.engineerprofile

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
import androidx.compose.material.icons.outlined.Checklist
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
import com.equipseva.app.core.data.engineers.ProfileCompletenessRepository
import com.equipseva.app.core.network.toUserMessage
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
import com.equipseva.app.designsystem.theme.SevaGreen50
import com.equipseva.app.designsystem.theme.SevaGreen700
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
class ProfileCompletenessViewModel @Inject constructor(
    private val repo: ProfileCompletenessRepository,
) : ViewModel() {
    data class UiState(
        val loading: Boolean = true,
        val error: String? = null,
        val data: ProfileCompletenessRepository.ProfileCompleteness? = null,
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
 * "Profile strength" — the engineer's completeness score, band, and the
 * concrete checklist of what's left, with a CTA into the profile editor.
 * A verified engineer who fills these out ranks + converts better.
 */
@Composable
fun ProfileCompletenessScreen(
    onBack: () -> Unit,
    onEditProfile: () -> Unit,
    viewModel: ProfileCompletenessViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    com.equipseva.app.designsystem.util.RefreshOnReturn { viewModel.reload() }

    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(title = "Profile strength", onBack = onBack)
            when {
                state.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }
                state.error != null || state.data == null -> EmptyStateView(
                    icon = Icons.Outlined.Checklist,
                    title = "Couldn't load profile strength",
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
                        ScoreCard(score = d.score, band = d.band, hasMissingItems = d.missingItems.isNotEmpty())
                        if (d.missingItems.isEmpty()) {
                            Text(
                                "Your profile is fully complete — you're as visible to hospitals as it gets.",
                                style = EsType.Body,
                                color = SevaInk700,
                            )
                        } else {
                            Text(
                                "To reach 100%",
                                style = EsType.H5,
                                color = SevaInk900,
                                modifier = Modifier.padding(top = 4.dp),
                            )
                            d.missingItems.forEach { key -> MissingItemRow(missingItemLabel(key)) }
                            Spacer(Modifier.height(4.dp))
                            EsBtn(
                                text = "Complete your profile",
                                onClick = onEditProfile,
                                kind = EsBtnKind.Primary,
                                size = EsBtnSize.Lg,
                                full = true,
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
private fun ScoreCard(score: Int, band: String, hasMissingItems: Boolean) {
    // Server band "complete" starts at score 90, but 90–99 can still have
    // missing items. Don't show the green "Complete" pill while the screen
    // below lists items "To reach 100%".
    val effectiveBand = if (band == "complete" && hasMissingItems) "partial" else band
    val (bandText, bandKind) = completenessBandTextAndKind(effectiveBand)
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
            Text("Profile strength", style = EsType.BodySm, color = SevaInk700)
            Pill(text = bandText, kind = bandKind)
        }
        Text("$score%", style = EsType.H3.copy(fontWeight = FontWeight.Bold), color = SevaGreen700)
        Text("of your profile is complete", style = EsType.Caption, color = SevaInk500)
    }
}

@Composable
private fun MissingItemRow(label: String) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(10.dp))
            .padding(14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Text("○", color = SevaInk500, style = EsType.Body)
        Text(label, style = EsType.Body, color = SevaInk900)
    }
}

// ---------------------------------------------------------------------
//  Pinned helpers
// ---------------------------------------------------------------------

/**
 * Band pill for the completeness meter. Server bands: complete (≥90),
 * partial (≥60), incomplete (else).
 */
internal fun completenessBandTextAndKind(band: String): Pair<String, PillKind> = when (band) {
    "complete" -> "Complete" to PillKind.Success
    "partial" -> "Almost there" to PillKind.Warn
    else -> "Incomplete" to PillKind.Danger
}

/**
 * Human label for each server missing_items key (r504). Unknown keys
 * degrade to a de-snaked Title-case fallback so a new server key never
 * renders a raw token.
 */
internal fun missingItemLabel(key: String): String = when (key) {
    "engineer_profile_not_created" -> "Create your engineer profile"
    "aadhaar_verification" -> "Verify your Aadhaar"
    "pan_verified" -> "Verify your PAN"
    "police_verification" -> "Add police verification"
    "specializations" -> "List your specializations"
    "certificates" -> "Upload your certificates"
    "profile_photo" -> "Add a profile photo"
    "location" -> "Set your service location"
    "profitability_floor" -> "Set your net-pay floor"
    "gstin" -> "Add your GSTIN"
    "needs_6_completed_jobs" -> "Complete 6 repair jobs"
    else -> key.replace('_', ' ').replaceFirstChar { it.uppercase() }
}
