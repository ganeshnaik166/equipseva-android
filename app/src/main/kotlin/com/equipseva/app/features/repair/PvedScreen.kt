package com.equipseva.app.features.repair

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
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
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.data.repair.PvedRepository
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.core.util.prettyDate
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.components.Pill
import com.equipseva.app.designsystem.components.PillKind
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaGreen50
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk700
import com.equipseva.app.designsystem.theme.SevaInk900
import com.equipseva.app.navigation.Routes
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

@HiltViewModel
class PvedViewModel @Inject constructor(
    savedState: SavedStateHandle,
    private val repo: PvedRepository,
) : ViewModel() {
    private val jobId: String =
        checkNotNull(savedState.get<String>(Routes.PVED_ARG_JOB_ID)) {
            "PvedViewModel requires arg ${Routes.PVED_ARG_JOB_ID}"
        }

    data class UiState(
        val loading: Boolean = true,
        val error: String? = null,
        val dossier: PvedRepository.Pved? = null,
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init { reload() }

    fun reload() {
        _state.update { it.copy(loading = it.dossier == null, error = null) }
        viewModelScope.launch {
            repo.dossierForJob(jobId)
                .onSuccess { d -> _state.update { it.copy(loading = false, dossier = d) } }
                .onFailure { e -> _state.update { it.copy(loading = false, error = e.toUserMessage()) } }
        }
    }
}

/**
 * Pre-Visit Engineer Dossier (r1447): the hospital reviews the accepted
 * engineer's verified snapshot — identity, verification, certifications and
 * track record — before granting site access. Surfaces build_pved +
 * mark_pved_consumed (round 493). Reached from the job "Records".
 */
@Composable
fun PvedScreen(
    onBack: () -> Unit,
    viewModel: PvedViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(title = "Engineer verification", onBack = onBack)
            when {
                state.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }
                state.error != null -> EmptyStateView(
                    icon = Icons.Outlined.VerifiedUser,
                    title = "Couldn't load dossier",
                    subtitle = state.error,
                    ctaLabel = "Try again",
                    onCta = { viewModel.reload() },
                )
                state.dossier == null -> EmptyStateView(
                    icon = Icons.Outlined.VerifiedUser,
                    title = "No dossier",
                    subtitle = "A verification dossier is available once an engineer is assigned to this job.",
                )
                else -> {
                    val d = state.dossier!!
                    Column(
                        modifier = Modifier
                            .fillMaxSize()
                            .verticalScroll(rememberScrollState())
                            .padding(16.dp),
                        verticalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        HeroCard(d)
                        StatRow("Identity", d.aadhaarMaskedId?.takeIf { it.isNotBlank() } ?: "Not on file")
                        StatRow("Certifications", "${d.certificateCount}")
                        StatRow("Jobs completed", "${d.totalJobsCompleted}")
                        StatRow("Average rating", pvedRatingLabel(d.averageRating))
                        d.verifiedAt?.takeIf { it.isNotBlank() }?.let {
                            StatRow("Verified on", prettyDate(it))
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun HeroCard(d: PvedRepository.Pved) {
    val (pillText, pillKind) = pvedVerificationPill(d.verificationStatus)
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(SevaGreen50)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                d.engineerDisplayName.ifBlank { "Engineer" },
                style = EsType.H4.copy(fontWeight = FontWeight.Bold),
                color = SevaInk900,
                modifier = Modifier.weight(1f),
            )
            Pill(text = pillText, kind = pillKind)
        }
        Text(
            "Reviewed before granting site access. This snapshot is recorded for the job's audit trail.",
            style = EsType.Caption,
            color = SevaInk700,
        )
    }
}

@Composable
private fun StatRow(label: String, value: String) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(10.dp))
            .padding(14.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(label, style = EsType.Body, color = SevaInk700, modifier = Modifier.weight(1f))
        Text(value, style = EsType.Body.copy(fontWeight = FontWeight.SemiBold), color = SevaInk900)
    }
}

// ---------------------------------------------------------------------
//  Pinned helpers
// ---------------------------------------------------------------------

/** Verification status -> pill. Verified reads Success; pending Warn;
 *  rejected Danger; unknown de-snakes Neutral. */
internal fun pvedVerificationPill(status: String): Pair<String, PillKind> = when (status.trim().lowercase()) {
    "verified" -> "Verified" to PillKind.Success
    "pending" -> "Pending" to PillKind.Warn
    "rejected" -> "Rejected" to PillKind.Danger
    else -> status.replace('_', ' ').replaceFirstChar { it.uppercase() }.ifBlank { "Unknown" } to PillKind.Neutral
}

/** Average-rating label: one decimal with a star, or "No ratings yet" when null. */
internal fun pvedRatingLabel(rating: Double?): String {
    if (rating == null) return "No ratings yet"
    val r = (kotlin.math.round(rating * 10.0) / 10.0)
    val s = if (r % 1.0 == 0.0) r.toLong().toString() else r.toString()
    return "★ $s"
}
