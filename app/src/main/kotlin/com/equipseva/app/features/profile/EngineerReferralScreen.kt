package com.equipseva.app.features.profile

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
import androidx.compose.material.icons.outlined.Star
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import com.equipseva.app.R
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.core.util.formatRupees
import com.equipseva.app.core.util.prettyDate
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.EsBtn
import com.equipseva.app.designsystem.components.EsBtnKind
import com.equipseva.app.designsystem.components.EsField
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.components.Pill
import com.equipseva.app.designsystem.components.PillKind
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaDanger500
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk600
import com.equipseva.app.designsystem.theme.SevaInk900
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.filterIsInstance
import kotlinx.coroutines.flow.firstOrNull
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

@HiltViewModel
class EngineerReferralViewModel @Inject constructor(
    private val repo: EngineerReferralRepository,
    private val auth: AuthRepository,
) : ViewModel() {

    data class UiState(
        val loading: Boolean = true,
        val error: String? = null,
        val myUserId: String? = null,
        val referrals: List<EngineerReferralRepository.Referral> = emptyList(),
        val pending: List<EngineerReferralRepository.PendingConfirmation> = emptyList(),
        val registering: Boolean = false,
        val registerError: String? = null,
        val registerSuccess: Boolean = false,
        val confirmingId: String? = null,
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    init {
        refresh()
    }

    fun refresh() {
        _state.update { it.copy(loading = true, error = null) }
        viewModelScope.launch {
            val userId = auth.sessionState.filterIsInstance<AuthSession.SignedIn>().firstOrNull()?.userId
            val referrals = repo.fetchMyReferrals()
            val pending = repo.fetchPendingConfirmations()
            if (referrals.isFailure) {
                _state.update {
                    it.copy(
                        loading = false,
                        myUserId = userId,
                        error = referrals.exceptionOrNull()?.toUserMessage("Could not load your referrals."),
                    )
                }
                return@launch
            }
            _state.update {
                it.copy(
                    loading = false,
                    myUserId = userId,
                    referrals = referrals.getOrDefault(emptyList()),
                    pending = pending.getOrDefault(emptyList()),
                )
            }
        }
    }

    fun registerReferral(referrerUserId: String) {
        _state.update { it.copy(registering = true, registerError = null, registerSuccess = false) }
        viewModelScope.launch {
            repo.registerReferral(referrerUserId)
                .onSuccess {
                    _state.update { it.copy(registering = false, registerSuccess = true) }
                    refresh()
                }
                .onFailure { e ->
                    _state.update {
                        it.copy(registering = false, registerError = e.toUserMessage("Could not register that code."))
                    }
                }
        }
    }

    fun confirm(referralId: String) {
        _state.update { it.copy(confirmingId = referralId) }
        viewModelScope.launch {
            repo.confirmReferral(referralId)
                .onSuccess {
                    _state.update { it.copy(confirmingId = null) }
                    refresh()
                }
                .onFailure { e ->
                    _state.update {
                        it.copy(
                            confirmingId = null,
                            error = e.toUserMessage("Could not confirm that referral."),
                        )
                    }
                }
        }
    }
}

@Composable
fun EngineerReferralScreen(
    onBack: () -> Unit,
    viewModel: EngineerReferralViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val context = LocalContext.current
    var codeInput by rememberSaveable { mutableStateOf("") }

    Box(Modifier.fillMaxSize().background(PaperDefault)) {
        Column(Modifier.fillMaxSize()) {
            EsTopBar(title = stringResource(R.string.referral_title), onBack = onBack)

            when {
                state.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }

                state.error != null && state.referrals.isEmpty() && state.myUserId == null -> EmptyStateView(
                    icon = Icons.Outlined.Star,
                    title = stringResource(R.string.referral_couldnt_load),
                    subtitle = state.error,
                    ctaLabel = stringResource(R.string.referral_try_again),
                    onCta = { viewModel.refresh() },
                )

                else -> LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(horizontal = 16.dp, vertical = 12.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    item {
                        Text(
                            stringResource(R.string.referral_explainer),
                            style = EsType.BodySm,
                            color = SevaInk500,
                        )
                    }
                    if (state.myUserId != null) {
                        item {
                            ShareCodeCard(
                                code = state.myUserId!!,
                                onCopy = {
                                    copyReferralCodeToClipboard(context, state.myUserId!!)
                                },
                            )
                        }
                    }
                    item {
                        RegisterCodeCard(
                            codeInput = codeInput,
                            onCodeChange = { codeInput = it },
                            registering = state.registering,
                            registerError = state.registerError,
                            registerSuccess = state.registerSuccess,
                            onSubmit = { viewModel.registerReferral(codeInput.trim()) },
                        )
                    }
                    if (state.pending.isNotEmpty()) {
                        item {
                            Text(
                                stringResource(R.string.referral_pending_title, state.pending.size),
                                style = EsType.H5,
                                color = SevaInk900,
                            )
                        }
                        items(state.pending, key = { it.id }) { p ->
                            PendingConfirmationCard(
                                p = p,
                                confirming = state.confirmingId == p.id,
                                onConfirm = { viewModel.confirm(p.id) },
                            )
                        }
                    }
                    item {
                        Text(
                            stringResource(R.string.referral_history_title),
                            style = EsType.H5,
                            color = SevaInk900,
                        )
                    }
                    if (state.referrals.isEmpty()) {
                        item {
                            Text(
                                stringResource(R.string.referral_history_empty),
                                style = EsType.BodySm,
                                color = SevaInk500,
                            )
                        }
                    } else {
                        items(state.referrals, key = { it.id }) { r -> ReferralCard(r) }
                    }
                }
            }
        }
    }
}

@Composable
private fun ShareCodeCard(code: String, onCopy: () -> Unit) {
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
                stringResource(R.string.referral_your_code_title),
                style = EsType.Body.copy(fontWeight = FontWeight.SemiBold),
                color = SevaInk900,
            )
            Spacer(Modifier.height(6.dp))
            Text(code, style = EsType.BodySm, color = SevaInk600)
            Spacer(Modifier.height(10.dp))
            EsBtn(
                text = stringResource(R.string.referral_copy_code),
                onClick = onCopy,
                kind = EsBtnKind.Secondary,
                full = true,
            )
        }
    }
}

@Composable
private fun RegisterCodeCard(
    codeInput: String,
    onCodeChange: (String) -> Unit,
    registering: Boolean,
    registerError: String?,
    registerSuccess: Boolean,
    onSubmit: () -> Unit,
) {
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
                stringResource(R.string.referral_enter_code_title),
                style = EsType.Body.copy(fontWeight = FontWeight.SemiBold),
                color = SevaInk900,
            )
            Spacer(Modifier.height(8.dp))
            EsField(
                value = codeInput,
                onChange = onCodeChange,
                placeholder = stringResource(R.string.referral_enter_code_placeholder),
            )
            if (registerError != null) {
                Spacer(Modifier.height(6.dp))
                Text(registerError, style = EsType.Caption, color = SevaDanger500)
            }
            if (registerSuccess) {
                Spacer(Modifier.height(6.dp))
                Text(
                    stringResource(R.string.referral_registered_note),
                    style = EsType.Caption,
                    color = SevaGreen700,
                )
            }
            Spacer(Modifier.height(10.dp))
            EsBtn(
                text = if (registering) {
                    stringResource(R.string.referral_registering)
                } else {
                    stringResource(R.string.referral_register)
                },
                onClick = onSubmit,
                kind = EsBtnKind.Primary,
                full = true,
                disabled = registering || codeInput.isBlank(),
            )
        }
    }
}

@Composable
private fun PendingConfirmationCard(
    p: EngineerReferralRepository.PendingConfirmation,
    confirming: Boolean,
    onConfirm: () -> Unit,
) {
    Box(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
            .padding(14.dp),
    ) {
        Column {
            Text(
                stringResource(R.string.referral_pending_row_title, prettyDate(p.createdAt)),
                style = EsType.BodySm.copy(fontWeight = FontWeight.SemiBold),
                color = SevaInk900,
            )
            Spacer(Modifier.height(8.dp))
            EsBtn(
                text = if (confirming) {
                    stringResource(R.string.referral_confirming)
                } else {
                    stringResource(R.string.referral_confirm)
                },
                onClick = onConfirm,
                kind = EsBtnKind.Primary,
                disabled = confirming,
                full = true,
            )
        }
    }
}

@Composable
private fun ReferralCard(r: EngineerReferralRepository.Referral) {
    val (label, kind) = referralStatusLabelAndKind(r)
    Box(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
            .padding(14.dp),
    ) {
        Column {
            Row(
                Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    stringResource(R.string.referral_row_title, prettyDate(r.createdAt)),
                    style = EsType.Body.copy(fontWeight = FontWeight.SemiBold),
                    color = SevaInk900,
                )
                Pill(text = label, kind = kind)
            }
            Spacer(Modifier.height(4.dp))
            Text(
                stringResource(R.string.referral_bounty_amount, formatRupees(r.bountyAmountRupees)),
                style = EsType.BodySm,
                color = SevaInk500,
            )
        }
    }
}

internal fun referralStatusLabelAndKind(r: EngineerReferralRepository.Referral): Pair<String, PillKind> = when {
    r.bountyRevoked -> "Revoked" to PillKind.Danger
    r.payoutStatus == "paid" -> "Paid" to PillKind.Success
    r.payoutStatus == "queued" -> "Queued for payout" to PillKind.Info
    r.bountyEligible -> "Eligible" to PillKind.Success
    else -> "Pending" to PillKind.Warn
}

private fun copyReferralCodeToClipboard(context: android.content.Context, code: String) {
    val clip = context.getSystemService(android.content.Context.CLIPBOARD_SERVICE) as android.content.ClipboardManager
    clip.setPrimaryClip(android.content.ClipData.newPlainText("Referral code", code))
    android.widget.Toast.makeText(context, "Copied", android.widget.Toast.LENGTH_SHORT).show()
}
