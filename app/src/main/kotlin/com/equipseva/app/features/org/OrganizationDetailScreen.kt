package com.equipseva.app.features.org

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
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
import androidx.compose.material.icons.outlined.Business
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
import com.equipseva.app.core.data.org.OrganizationRepository
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.designsystem.components.EmptyStateView
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
class OrganizationDetailViewModel @Inject constructor(
    private val repo: OrganizationRepository,
) : ViewModel() {
    data class UiState(
        val loading: Boolean = true,
        val error: String? = null,
        val loaded: Boolean = false,
        val org: OrganizationRepository.OrgDetail? = null,
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init { reload() }

    fun reload() {
        _state.update { it.copy(loading = !it.loaded, error = null) }
        viewModelScope.launch {
            repo.myOrganization()
                .onSuccess { o -> _state.update { it.copy(loading = false, loaded = true, org = o) } }
                .onFailure { e -> _state.update { it.copy(loading = false, error = e.toUserMessage()) } }
        }
    }
}

/**
 * Organization details (r1448): a member views their organization's full
 * registration + compliance record — GSTIN, PAN, licence documents — beyond the
 * public name/city summary. Surfaces organization_full (round 428). Reached
 * from Profile.
 */
@Composable
fun OrganizationDetailScreen(
    onBack: () -> Unit,
    viewModel: OrganizationDetailViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(title = "Organization", onBack = onBack)
            when {
                state.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }
                state.error != null -> EmptyStateView(
                    icon = Icons.Outlined.Business,
                    title = "Couldn't load organization",
                    subtitle = state.error,
                    ctaLabel = "Try again",
                    onCta = { viewModel.reload() },
                )
                state.org == null -> EmptyStateView(
                    icon = Icons.Outlined.Business,
                    title = "No organization",
                    subtitle = "Your account isn't linked to an organization. Registration details appear here once it is.",
                )
                else -> {
                    val o = state.org!!
                    Column(
                        modifier = Modifier
                            .fillMaxSize()
                            .verticalScroll(rememberScrollState())
                            .padding(16.dp),
                        verticalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        HeroCard(o)
                        o.gstin?.takeIf { it.isNotBlank() }?.let { DetailRow("GSTIN", it) }
                        o.pan?.takeIf { it.isNotBlank() }?.let { DetailRow("PAN", it) }
                        o.accreditation?.takeIf { it.isNotBlank() }?.let { DetailRow("Accreditation", it) }
                        o.bedsCount?.let { DetailRow("Beds", it.toString()) }
                        o.gstCertificateUrl?.takeIf { it.isNotBlank() }?.let { LinkRow("GST certificate", it) }
                        o.tradeLicenceUrl?.takeIf { it.isNotBlank() }?.let { LinkRow("Trade licence", it) }
                    }
                }
            }
        }
    }
}

@Composable
private fun HeroCard(o: OrganizationRepository.OrgDetail) {
    val (pillText, pillKind) = orgVerificationPill(o.verificationStatus)
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(SevaGreen50)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(o.name.ifBlank { "Organization" }, style = EsType.H4.copy(fontWeight = FontWeight.Bold), color = SevaInk900, modifier = Modifier.weight(1f))
            Pill(text = pillText, kind = pillKind)
        }
        val place = listOfNotNull(o.type?.takeIf { it.isNotBlank() }, o.city?.takeIf { it.isNotBlank() }, o.state?.takeIf { it.isNotBlank() }).joinToString(" · ")
        if (place.isNotBlank()) {
            Text(place, style = EsType.Caption, color = SevaInk700)
        }
    }
}

@Composable
private fun DetailRow(label: String, value: String) {
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

@Composable
private fun LinkRow(label: String, url: String) {
    val uriHandler = androidx.compose.ui.platform.LocalUriHandler.current
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(10.dp))
            .clickable { runCatching { uriHandler.openUri(url) } }
            .padding(14.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(label, style = EsType.Body, color = SevaInk700, modifier = Modifier.weight(1f))
        Text("View", style = EsType.Body.copy(fontWeight = FontWeight.SemiBold), color = SevaGreen700)
    }
}

// ---------------------------------------------------------------------
//  Pinned helper
// ---------------------------------------------------------------------

/** Organization verification status -> pill (verified/pending/rejected/unknown). */
internal fun orgVerificationPill(status: String?): Pair<String, PillKind> = when (status?.trim()?.lowercase()) {
    "verified" -> "Verified" to PillKind.Success
    "pending", null, "" -> "Pending" to PillKind.Warn
    "rejected" -> "Rejected" to PillKind.Danger
    else -> status.replace('_', ' ').replaceFirstChar { it.uppercase() } to PillKind.Neutral
}
