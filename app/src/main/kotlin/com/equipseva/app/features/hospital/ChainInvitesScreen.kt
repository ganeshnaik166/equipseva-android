package com.equipseva.app.features.hospital

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.GroupAdd
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.data.hospital.ChainRepository
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.core.util.prettyDate
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.EsBottomSheet
import com.equipseva.app.designsystem.components.EsBtn
import com.equipseva.app.designsystem.components.EsBtnKind
import com.equipseva.app.designsystem.components.EsBtnSize
import com.equipseva.app.designsystem.components.EsField
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.components.Pill
import com.equipseva.app.designsystem.components.PillKind
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaDanger500
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
class ChainInvitesViewModel @Inject constructor(
    savedState: SavedStateHandle,
    private val repo: ChainRepository,
) : ViewModel() {
    private val chainId: String = savedState.get<String>(Routes.CHAIN_INVITES_ARG_CHAIN_ID).orEmpty()
    val chainName: String = savedState.get<String>(Routes.CHAIN_INVITES_ARG_CHAIN_NAME).orEmpty()

    data class UiState(
        val loading: Boolean = true,
        val error: String? = null,
        val invites: List<ChainRepository.ChainInvite> = emptyList(),
        val submitting: Boolean = false,
        val actionError: String? = null,
        val revokingId: String? = null,
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init { reload() }

    fun reload() {
        _state.update { it.copy(loading = it.invites.isEmpty(), error = null) }
        viewModelScope.launch {
            repo.invites(chainId)
                .onSuccess { list -> _state.update { it.copy(loading = false, invites = list) } }
                .onFailure { e -> _state.update { it.copy(loading = false, error = e.toUserMessage()) } }
        }
    }

    /** Send a new site invite; on success close the sheet + reload the list. */
    fun invite(email: String, siteLabel: String, onSent: () -> Unit) {
        _state.update { it.copy(submitting = true, actionError = null) }
        viewModelScope.launch {
            repo.inviteSite(chainId, email, siteLabel)
                .onSuccess {
                    _state.update { it.copy(submitting = false, actionError = null) }
                    onSent()
                    reload()
                }
                .onFailure { e -> _state.update { it.copy(submitting = false, actionError = e.toUserMessage()) } }
        }
    }

    fun clearActionError() = _state.update { it.copy(actionError = null) }

    /** Revoke a pending invite, then reload. */
    fun revoke(inviteId: String) {
        _state.update { it.copy(revokingId = inviteId, error = null) }
        viewModelScope.launch {
            repo.revokeInvite(inviteId, reason = null)
                .onSuccess {
                    _state.update { it.copy(revokingId = null) }
                    reload()
                }
                .onFailure { e -> _state.update { it.copy(revokingId = null, error = e.toUserMessage()) } }
        }
    }
}

/**
 * Chain-admin site-invite management (r1422): list the chain's onboarding
 * invites (read straight from hospital_chain_invites under its admin RLS),
 * invite a new site by admin email (chain_admin_invite_site), and revoke a
 * still-pending invite (chain_admin_revoke_invite). Reached from the r1419
 * chain cockpit; only meaningful to a chain's primary admin.
 */
@Composable
fun ChainInvitesScreen(
    onBack: () -> Unit,
    viewModel: ChainInvitesViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    com.equipseva.app.designsystem.util.RefreshOnReturn { viewModel.reload() }

    var showInviteSheet by rememberSaveable { mutableStateOf(false) }
    var confirmRevoke by rememberSaveable { mutableStateOf<String?>(null) }

    if (showInviteSheet) {
        InviteSiteSheet(
            submitting = state.submitting,
            error = state.actionError,
            onClose = {
                showInviteSheet = false
                viewModel.clearActionError()
            },
            onSubmit = { email, label -> viewModel.invite(email, label) { showInviteSheet = false } },
        )
    }

    confirmRevoke?.let { inviteId ->
        val email = state.invites.firstOrNull { it.id == inviteId }?.invitedEmail.orEmpty()
        AlertDialog(
            onDismissRequest = { confirmRevoke = null },
            title = { Text("Revoke invite?") },
            text = { Text("The invite to $email will be cancelled. They won't be able to join with the old link.") },
            confirmButton = {
                TextButton(onClick = {
                    viewModel.revoke(inviteId)
                    confirmRevoke = null
                }) { Text("Revoke", color = SevaDanger500) }
            },
            dismissButton = { TextButton(onClick = { confirmRevoke = null }) { Text("Keep") } },
        )
    }

    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(title = "Site invites", onBack = onBack)
            when {
                state.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }
                state.error != null -> EmptyStateView(
                    icon = Icons.Outlined.GroupAdd,
                    title = "Couldn't load invites",
                    subtitle = state.error,
                    ctaLabel = "Try again",
                    onCta = { viewModel.reload() },
                )
                else -> LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(12.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    item(key = "invite-cta") {
                        EsBtn(
                            text = "Invite a site",
                            onClick = { showInviteSheet = true },
                            kind = EsBtnKind.Primary,
                            size = EsBtnSize.Lg,
                            full = true,
                        )
                    }
                    if (state.invites.isEmpty()) {
                        item(key = "empty") {
                            Text(
                                "No invites yet. Invite a site's admin by email to add them to ${viewModel.chainName.ifBlank { "your chain" }}.",
                                style = EsType.BodySm,
                                color = SevaInk500,
                                modifier = Modifier.padding(horizontal = 4.dp, vertical = 8.dp),
                            )
                        }
                    } else {
                        items(state.invites, key = { it.id }) { inv ->
                            InviteCard(
                                invite = inv,
                                revoking = state.revokingId == inv.id,
                                onRevoke = { confirmRevoke = inv.id },
                            )
                        }
                    }
                    item(key = "tail") { Spacer(Modifier.height(8.dp)) }
                }
            }
        }
    }
}

@Composable
private fun InviteCard(
    invite: ChainRepository.ChainInvite,
    revoking: Boolean,
    onRevoke: () -> Unit,
) {
    val (pillText, pillKind) = chainInviteStatusPill(invite.status)
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
            .padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                invite.invitedEmail,
                style = EsType.Body.copy(fontWeight = FontWeight.Medium),
                color = SevaInk900,
                modifier = Modifier.weight(1f),
            )
            Pill(text = pillText, kind = pillKind)
        }
        invite.siteLabel?.takeIf { it.isNotBlank() }?.let {
            Text(it, style = EsType.Caption, color = SevaInk700)
        }
        invite.expiresAt?.takeIf { it.isNotBlank() }?.let {
            Text("Expires ${prettyDate(it)}", style = EsType.Caption, color = SevaInk500)
        }
        if (canRevokeInvite(invite.status)) {
            EsBtn(
                text = if (revoking) "Revoking…" else "Revoke",
                onClick = onRevoke,
                kind = EsBtnKind.DangerOutline,
                size = EsBtnSize.Sm,
                disabled = revoking,
            )
        }
    }
}

@Composable
private fun InviteSiteSheet(
    submitting: Boolean,
    error: String?,
    onClose: () -> Unit,
    onSubmit: (email: String, siteLabel: String) -> Unit,
) {
    var email by rememberSaveable { mutableStateOf("") }
    var label by rememberSaveable { mutableStateOf("") }
    EsBottomSheet(onClose = onClose, title = "Invite a site") {
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text(
                "Enter the site admin's email. They'll get a link to join your chain; the invite expires in 14 days.",
                style = EsType.BodySm,
                color = SevaInk700,
            )
            EsField(
                value = email,
                onChange = { email = it },
                label = "Site admin email",
                placeholder = "admin@site-hospital.in",
            )
            EsField(
                value = label,
                onChange = { label = it },
                label = "Site label (optional)",
                placeholder = "e.g. Andheri branch",
                imeAction = ImeAction.Done,
            )
            if (error != null) {
                Text(error, style = EsType.BodySm, color = SevaDanger500)
            }
            EsBtn(
                text = if (submitting) "Sending…" else "Send invite",
                onClick = { onSubmit(email, label) },
                kind = EsBtnKind.Primary,
                size = EsBtnSize.Lg,
                full = true,
                disabled = submitting || !isValidInviteEmail(email),
            )
            Spacer(Modifier.height(4.dp))
        }
    }
}

// ---------------------------------------------------------------------
//  Pinned helpers
// ---------------------------------------------------------------------

/** Invite status → pill. Pending awaits action (Warn); accepted is done
 *  (Success); revoked/expired are muted (Neutral). */
internal fun chainInviteStatusPill(status: String): Pair<String, PillKind> = when (status) {
    "pending" -> "Pending" to PillKind.Warn
    "accepted" -> "Accepted" to PillKind.Success
    "revoked" -> "Revoked" to PillKind.Neutral
    "expired" -> "Expired" to PillKind.Neutral
    else -> status.replace('_', ' ').replaceFirstChar { it.uppercase() } to PillKind.Neutral
}

/** Only a still-pending invite can be revoked (mirrors the server guard). */
internal fun canRevokeInvite(status: String): Boolean = status == "pending"

/** Minimal, testable email gate for the invite button; the DB enforces the
 *  authoritative CHECK. Requires local@domain.tld with no whitespace. */
internal fun isValidInviteEmail(email: String): Boolean =
    Regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]{2,}$").matches(email.trim())
