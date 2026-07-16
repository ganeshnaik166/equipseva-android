package com.equipseva.app.features.hospital

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Apartment
import androidx.compose.material.icons.outlined.CheckCircle
import androidx.compose.material3.Icon
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.data.hospital.ChainRepository
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.designsystem.components.EsBtn
import com.equipseva.app.designsystem.components.EsBtnKind
import com.equipseva.app.designsystem.components.EsBtnSize
import com.equipseva.app.designsystem.components.EsField
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaDanger500
import com.equipseva.app.designsystem.theme.SevaGreen700
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
class JoinChainViewModel @Inject constructor(
    private val repo: ChainRepository,
) : ViewModel() {
    data class UiState(
        val submitting: Boolean = false,
        val error: String? = null,
        val joined: Boolean = false,
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    fun clearError() = _state.update { it.copy(error = null) }

    fun join(token: String) {
        if (_state.value.submitting) return
        _state.update { it.copy(submitting = true, error = null) }
        viewModelScope.launch {
            repo.acceptInvite(token)
                .onSuccess { _state.update { it.copy(submitting = false, joined = true) } }
                .onFailure { e -> _state.update { it.copy(submitting = false, error = e.toUserMessage()) } }
        }
    }
}

/**
 * Join a hospital chain (r1444): the invited hospital pastes the invite token
 * it received (out-of-band) to redeem a chain-site invite created via r1422's
 * chain_admin_invite_site. Backed by accept_hospital_chain_invite, which
 * matches the caller's email to the invite. Reached from Profile.
 */
@Composable
fun JoinChainScreen(
    onBack: () -> Unit,
    viewModel: JoinChainViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    var token by rememberSaveable { mutableStateOf("") }

    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(title = "Join a chain", onBack = onBack)
            if (state.joined) {
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(24.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center,
                ) {
                    Icon(Icons.Outlined.CheckCircle, contentDescription = null, tint = SevaGreen700, modifier = Modifier.height(56.dp))
                    Spacer(Modifier.height(12.dp))
                    Text("You've joined the chain", style = EsType.H4, color = SevaInk900)
                    Spacer(Modifier.height(6.dp))
                    Text(
                        "Your site is now part of the hospital chain. The chain admin can see it in their cockpit.",
                        style = EsType.BodySm,
                        color = SevaInk700,
                    )
                    Spacer(Modifier.height(20.dp))
                    EsBtn(text = "Done", onClick = onBack, kind = EsBtnKind.Primary, size = EsBtnSize.Lg, full = true)
                }
            } else {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    Box(modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp), contentAlignment = Alignment.Center) {
                        Icon(Icons.Outlined.Apartment, contentDescription = null, tint = SevaGreen700, modifier = Modifier.height(40.dp))
                    }
                    Text(
                        "Received an invite to join a hospital chain? Paste the invite code from your email to join. " +
                            "The code must have been sent to this account's email address.",
                        style = EsType.BodySm,
                        color = SevaInk700,
                    )
                    EsField(
                        value = token,
                        onChange = { token = it },
                        label = "Invite code",
                        placeholder = "Paste the code from your invite email",
                        imeAction = ImeAction.Done,
                    )
                    state.error?.let {
                        Text(it, style = EsType.BodySm, color = SevaDanger500)
                    }
                    EsBtn(
                        text = if (state.submitting) "Joining…" else "Join chain",
                        onClick = { viewModel.join(token) },
                        kind = EsBtnKind.Primary,
                        size = EsBtnSize.Lg,
                        full = true,
                        disabled = state.submitting || !isValidInviteToken(token),
                    )
                }
            }
        }
    }
}

// ---------------------------------------------------------------------
//  Pinned helper
// ---------------------------------------------------------------------

/** Gate for the Join button: the server token is a long random hex string, so
 *  require a non-trivial trimmed length to catch empty / obviously-wrong input
 *  before hitting the RPC. The server does the authoritative lookup. */
internal fun isValidInviteToken(token: String): Boolean = token.trim().length >= 16
