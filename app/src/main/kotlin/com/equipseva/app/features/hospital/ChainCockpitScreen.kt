package com.equipseva.app.features.hospital

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
import androidx.compose.material.icons.outlined.Apartment
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
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.hospital.ChainRepository
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.core.util.formatRupees
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
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk700
import com.equipseva.app.designsystem.theme.SevaInk900
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

@HiltViewModel
class ChainCockpitViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val repo: ChainRepository,
) : ViewModel() {
    data class UiState(
        val loading: Boolean = true,
        val error: String? = null,
        val chain: ChainRepository.Chain? = null,
        val multipleChains: Boolean = false,
        val kpis: ChainRepository.ChainKpis? = null,
        val sites: List<ChainRepository.ChainSite> = emptyList(),
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init { reload() }

    fun reload() {
        _state.update { it.copy(loading = it.chain == null, error = null) }
        viewModelScope.launch {
            val session = authRepository.sessionState.first { it !is AuthSession.Unknown }
            val uid = (session as? AuthSession.SignedIn)?.userId
            if (uid == null) {
                _state.update { it.copy(loading = false, error = "Sign in again to view your chain.") }
                return@launch
            }
            repo.myChains(uid)
                .onSuccess { chains ->
                    val chain = chains.firstOrNull()
                    _state.update { it.copy(chain = chain, multipleChains = chains.size > 1) }
                    if (chain == null) {
                        _state.update { it.copy(loading = false) }
                        return@onSuccess
                    }
                    repo.kpis(chain.id).onSuccess { k -> _state.update { it.copy(kpis = k) } }
                    repo.perSite(chain.id).onSuccess { s -> _state.update { it.copy(sites = s) } }
                    _state.update { it.copy(loading = false) }
                }
                .onFailure { e ->
                    _state.update { if (it.chain == null) it.copy(loading = false, error = e.toUserMessage()) else it.copy(loading = false) }
                }
        }
    }
}

/**
 * Hospital-chain admin cockpit (r1419): a single snapshot for the caller's
 * chain — member count, open/completed/disputed jobs (30d), active vs
 * pending-payment AMCs, escrow held, open dispute packs — plus a per-site
 * breakdown. Surfaces chain_kpis() + chain_per_site_summary() (round 549),
 * neither of which had an Android surface before. Read-only; reachable from
 * Profile (only meaningful to chain primary admins).
 */
@Composable
fun ChainCockpitScreen(
    onBack: () -> Unit,
    onManageInvites: (chainId: String, chainName: String) -> Unit = { _, _ -> },
    viewModel: ChainCockpitViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    com.equipseva.app.designsystem.util.RefreshOnReturn { viewModel.reload() }

    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(title = "Chain cockpit", onBack = onBack)
            when {
                state.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }
                state.error != null -> EmptyStateView(
                    icon = Icons.Outlined.Apartment,
                    title = "Couldn't load chain",
                    subtitle = state.error,
                    ctaLabel = "Try again",
                    onCta = { viewModel.reload() },
                )
                state.chain == null -> EmptyStateView(
                    icon = Icons.Outlined.Apartment,
                    title = "No chain to manage",
                    subtitle = "This cockpit is for hospital-chain primary admins. If you manage a multi-site chain, it appears here with per-site KPIs.",
                )
                else -> {
                    val chain = state.chain!!
                    LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(12.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        item(key = "hero") { ChainHero(chain.name, state.kpis) }
                        item(key = "invites-cta") {
                            EsBtn(
                                text = "Manage site invites",
                                onClick = { onManageInvites(chain.id, chain.name) },
                                kind = EsBtnKind.Secondary,
                                size = EsBtnSize.Md,
                                full = true,
                            )
                        }
                        if (state.multipleChains) {
                            item(key = "multi") {
                                Text(
                                    "Showing your first chain. Multi-chain switching is coming soon.",
                                    style = EsType.Caption,
                                    color = SevaInk500,
                                    modifier = Modifier.padding(horizontal = 4.dp),
                                )
                            }
                        }
                        item(key = "sites-header") {
                            Text(
                                "Sites",
                                style = EsType.H5,
                                color = SevaInk900,
                                modifier = Modifier.padding(horizontal = 4.dp, vertical = 4.dp),
                            )
                        }
                        if (state.sites.isEmpty()) {
                            item(key = "no-sites") {
                                Text("No member sites yet.", style = EsType.Body, color = SevaInk700, modifier = Modifier.padding(horizontal = 4.dp))
                            }
                        } else {
                            items(state.sites, key = { it.hospitalUserId }) { site -> SiteCard(site) }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun ChainHero(name: String, kpis: ChainRepository.ChainKpis?) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(SevaGreen50)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Text(name.ifBlank { "Chain" }, style = EsType.H4.copy(fontWeight = FontWeight.Bold), color = SevaInk900)
        if (kpis != null) {
            StatRow("Member sites", kpis.memberCount.toString())
            StatRow("Open jobs", kpis.jobsOpen.toString())
            StatRow("Completed (30d)", kpis.jobsCompletedWindow.toString())
            StatRow("Disputed (30d)", kpis.jobsDisputedWindow.toString())
            StatRow("Active AMCs", kpis.amcActive.toString())
            StatRow("AMCs pending payment", kpis.amcPendingPayment.toString())
            StatRow("Escrow held", formatRupees(kpis.totalEscrowHeldRupees))
            StatRow("Open dispute packs", kpis.openDisputePacks.toString())
        } else {
            Text("Chain KPIs unavailable right now.", style = EsType.Caption, color = SevaInk500)
        }
    }
}

@Composable
private fun StatRow(label: String, value: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(label, style = EsType.BodySm, color = SevaInk700)
        Text(value, style = EsType.BodySm.copy(fontWeight = FontWeight.Bold), color = SevaInk900)
    }
}

@Composable
private fun SiteCard(site: ChainRepository.ChainSite) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
            .padding(12.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Text(site.siteLabel.ifBlank { "Site" }, style = EsType.Body.copy(fontWeight = FontWeight.Medium), color = SevaInk900)
        Text(chainSiteSummaryLine(site.jobsOpen, site.jobsCompletedWindow, site.jobsDisputedWindow), style = EsType.Caption, color = SevaInk700)
        Text("${site.amcActive} active AMC · ${formatRupees(site.escrowHeldRupees)} escrow", style = EsType.Caption, color = SevaInk500)
    }
}

// ---------------------------------------------------------------------
//  Pinned helper
// ---------------------------------------------------------------------

/** Per-site jobs summary line for the chain cockpit. */
internal fun chainSiteSummaryLine(open: Int, completedWindow: Int, disputedWindow: Int): String =
    "$open open · $completedWindow done (30d) · $disputedWindow disputed"
