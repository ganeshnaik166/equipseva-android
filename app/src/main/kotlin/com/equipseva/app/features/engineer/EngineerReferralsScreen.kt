package com.equipseva.app.features.engineer

import android.content.Intent
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
import androidx.compose.material.icons.outlined.ContentCopy
import androidx.compose.material.icons.outlined.Share
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.core.util.formatRupees
import com.equipseva.app.designsystem.components.ErrorBanner
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
import com.equipseva.app.designsystem.theme.SevaGreen50
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaInk400
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk600
import com.equipseva.app.designsystem.theme.SevaInk900
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

@HiltViewModel
class EngineerReferralsViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val referralRepository: EngineerReferralRepository,
) : ViewModel() {

    data class UiState(
        val loading: Boolean = true,
        val myUserId: String? = null,
        val referrals: List<EngineerReferralRepository.MyReferral> = emptyList(),
        val summary: ReferralSummary = ReferralSummary(),
        val errorMessage: String? = null,
        val codeInput: String = "",
        val registering: Boolean = false,
    ) {
        val codeError: String? get() = referralCodeInputError(codeInput, myUserId)
        val canSubmitCode: Boolean get() = codeInput.isNotBlank() && codeError == null && !registering
    }

    sealed interface Effect {
        data class ShowMessage(val text: String) : Effect
    }

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    private val _effects = MutableSharedFlow<Effect>(extraBufferCapacity = 4)
    val effects: Flow<Effect> = _effects

    init {
        viewModelScope.launch {
            authRepository.sessionState.collect { session ->
                when (session) {
                    is AuthSession.SignedIn -> {
                        _state.update { it.copy(myUserId = session.userId) }
                        load()
                    }
                    AuthSession.SignedOut ->
                        _state.update {
                            it.copy(loading = false, errorMessage = "Sign in to see your referrals.")
                        }
                    AuthSession.Unknown -> Unit
                }
            }
        }
    }

    fun reload() = load()

    private fun load() {
        viewModelScope.launch {
            _state.update { it.copy(loading = it.referrals.isEmpty(), errorMessage = null) }
            referralRepository.fetchMyReferrals()
                .onSuccess { rows ->
                    _state.update {
                        it.copy(loading = false, referrals = rows, summary = referralSummary(rows))
                    }
                }
                .onFailure { e ->
                    _state.update { it.copy(loading = false, errorMessage = e.toUserMessage()) }
                }
        }
    }

    fun onCodeChange(v: String) = _state.update { it.copy(codeInput = v) }

    fun onSubmitCode() {
        val current = _state.value
        if (!current.canSubmitCode) return
        val code = current.codeInput.trim()
        viewModelScope.launch {
            _state.update { it.copy(registering = true) }
            referralRepository.registerReferral(code)
                .onSuccess {
                    _state.update { it.copy(registering = false, codeInput = "") }
                    _effects.tryEmit(
                        Effect.ShowMessage(
                            "Referral recorded. Your referrer earns ₹2,000 once your first paid job completes.",
                        ),
                    )
                    load()
                }
                .onFailure { e ->
                    _state.update { it.copy(registering = false) }
                    _effects.tryEmit(Effect.ShowMessage(e.toUserMessage()))
                }
        }
    }
}

@Composable
fun EngineerReferralsScreen(
    onBack: () -> Unit,
    onShowMessage: (String) -> Unit,
    viewModel: EngineerReferralsViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val clipboard = LocalClipboardManager.current
    val context = LocalContext.current

    com.equipseva.app.designsystem.util.RefreshOnReturn { viewModel.reload() }

    androidx.compose.runtime.LaunchedEffect(viewModel) {
        viewModel.effects.collect { eff ->
            when (eff) {
                is EngineerReferralsViewModel.Effect.ShowMessage -> onShowMessage(eff.text)
            }
        }
    }

    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState()),
        ) {
            EsTopBar(title = "Refer an engineer", onBack = onBack)
            ErrorBanner(message = state.errorMessage)

            if (state.loading) {
                Box(
                    Modifier.fillMaxWidth().padding(40.dp),
                    contentAlignment = Alignment.Center,
                ) { CircularProgressIndicator() }
            } else {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 12.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    ShareCodeCard(
                        code = state.myUserId,
                        onCopy = {
                            state.myUserId?.let {
                                clipboard.setText(AnnotatedString(it))
                                onShowMessage("Referral code copied")
                            }
                        },
                        onShare = {
                            state.myUserId?.let { code ->
                                val send = Intent(Intent.ACTION_SEND).apply {
                                    type = "text/plain"
                                    putExtra(
                                        Intent.EXTRA_TEXT,
                                        "Join EquipSeva as a verified biomedical engineer and enter my " +
                                            "referral code when you sign up: $code",
                                    )
                                }
                                context.startActivity(
                                    Intent.createChooser(send, "Share referral code"),
                                )
                            }
                        },
                    )

                    SummaryRow(state.summary)

                    EnterCodeCard(
                        value = state.codeInput,
                        error = state.codeError,
                        registering = state.registering,
                        canSubmit = state.canSubmitCode,
                        onChange = viewModel::onCodeChange,
                        onSubmit = viewModel::onSubmitCode,
                    )

                    Text(
                        text = "Your referrals",
                        style = EsType.H5,
                        color = SevaInk900,
                        modifier = Modifier.padding(top = 4.dp),
                    )

                    if (state.referrals.isEmpty()) {
                        Text(
                            text = "No referrals yet. Share your code with engineers you'd vouch for — " +
                                "you earn ₹2,000 when each one completes their first paid job.",
                            style = EsType.BodySm,
                            color = SevaInk600,
                        )
                    } else {
                        state.referrals.forEach { ReferralRow(it) }
                    }
                }
            }
            Spacer(Modifier.height(24.dp))
        }
    }
}

@Composable
private fun ShareCodeCard(
    code: String?,
    onCopy: () -> Unit,
    onShare: () -> Unit,
) {
    CardSurface {
        Text(text = "Your referral code", style = EsType.Label, color = SevaInk500)
        Spacer(Modifier.height(6.dp))
        Text(
            text = code ?: "—",
            style = EsType.Body.copy(fontWeight = FontWeight.SemiBold),
            color = SevaInk900,
        )
        Spacer(Modifier.height(4.dp))
        Text(
            text = "Engineers you refer enter this code at sign-up. You earn ₹2,000 per engineer once " +
                "their first paid job completes and clears escrow.",
            style = EsType.Caption,
            color = SevaInk600,
        )
        Spacer(Modifier.height(12.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            EsBtn(
                text = "Copy",
                onClick = onCopy,
                kind = EsBtnKind.Secondary,
                size = EsBtnSize.Sm,
                disabled = code == null,
                leading = {
                    Icon(Icons.Outlined.ContentCopy, contentDescription = null, tint = SevaInk900)
                },
            )
            EsBtn(
                text = "Share",
                onClick = onShare,
                kind = EsBtnKind.Primary,
                size = EsBtnSize.Sm,
                disabled = code == null,
                leading = {
                    Icon(Icons.Outlined.Share, contentDescription = null, tint = Color.White)
                },
            )
        }
    }
}

@Composable
private fun SummaryRow(summary: ReferralSummary) {
    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        StatCell(
            modifier = Modifier.weight(1f),
            value = summary.totalReferred.toString(),
            label = "Referred",
        )
        StatCell(
            modifier = Modifier.weight(1f),
            value = "₹${formatRupees(summary.earnedRupees)}",
            label = "Earned (${summary.paidCount})",
        )
        StatCell(
            modifier = Modifier.weight(1f),
            value = "₹${formatRupees(summary.queuedRupees)}",
            label = "Pending (${summary.pendingCount})",
        )
    }
}

@Composable
private fun StatCell(modifier: Modifier, value: String, label: String) {
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
            .padding(vertical = 14.dp, horizontal = 12.dp),
    ) {
        Text(text = value, style = EsType.H5, color = SevaGreen700)
        Spacer(Modifier.height(2.dp))
        Text(text = label, style = EsType.Caption, color = SevaInk500)
    }
}

@Composable
private fun EnterCodeCard(
    value: String,
    error: String?,
    registering: Boolean,
    canSubmit: Boolean,
    onChange: (String) -> Unit,
    onSubmit: () -> Unit,
) {
    CardSurface {
        Text(
            text = "Were you referred?",
            style = EsType.Body.copy(fontWeight = FontWeight.SemiBold),
            color = SevaInk900,
        )
        Spacer(Modifier.height(2.dp))
        Text(
            text = "Enter the referral code of the engineer who invited you. You can only do this once.",
            style = EsType.Caption,
            color = SevaInk600,
        )
        Spacer(Modifier.height(10.dp))
        EsField(
            value = value,
            onChange = onChange,
            label = "Referral code",
            placeholder = "Paste your referrer's code",
            error = error,
            enabled = !registering,
            imeAction = ImeAction.Done,
            onImeAction = { if (canSubmit) onSubmit() },
        )
        Spacer(Modifier.height(10.dp))
        EsBtn(
            text = if (registering) "Submitting…" else "Submit code",
            onClick = onSubmit,
            kind = EsBtnKind.Primary,
            size = EsBtnSize.Md,
            full = true,
            disabled = !canSubmit,
        )
    }
}

@Composable
private fun ReferralRow(r: EngineerReferralRepository.MyReferral) {
    val (pillText, pillKind) = referralBountyPillTextAndKind(
        bountyEligible = r.bountyEligible,
        bountyRevoked = r.bountyRevoked,
        payoutStatus = r.payoutStatus,
    )
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
            .padding(14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = refereeShortLabel(r.refereeUserId),
                style = EsType.Body.copy(fontWeight = FontWeight.SemiBold),
                color = SevaInk900,
            )
            Spacer(Modifier.height(2.dp))
            Text(
                text = "Referred ${r.createdAt.take(10)} · ₹${formatRupees(r.bountyAmountRupees)}",
                style = EsType.Caption,
                color = SevaInk500,
            )
            if (r.bountyRevoked && !r.bountyRevokeReason.isNullOrBlank()) {
                Spacer(Modifier.height(2.dp))
                Text(text = r.bountyRevokeReason, style = EsType.Caption, color = SevaInk400)
            }
        }
        Pill(text = pillText, kind = pillKind)
    }
}

@Composable
private fun CardSurface(content: @Composable androidx.compose.foundation.layout.ColumnScope.() -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(SevaGreen50.copy(alpha = 0.35f))
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
            .padding(16.dp),
        content = content,
    )
}

// ---------------------------------------------------------------------
//  Extracted, unit-pinned helpers (behaviour-pinning convention).
// ---------------------------------------------------------------------

/**
 * Roll-up of a referrer's [EngineerReferralRepository.MyReferral] rows.
 *
 *  - [totalReferred]  every row, including revoked (they still referred them)
 *  - [paidCount] / [earnedRupees]  bounties actually paid out
 *  - [pendingCount] / [queuedRupees]  eligible-but-unpaid; queued rupees only
 *    count rows with an actual queued payout row (an eligible row without a
 *    payout row yet contributes to pendingCount but ₹0 to queuedRupees)
 *
 * Revoked rows are excluded from every money/pending tally.
 */
data class ReferralSummary(
    val totalReferred: Int = 0,
    val paidCount: Int = 0,
    val earnedRupees: Double = 0.0,
    val pendingCount: Int = 0,
    val queuedRupees: Double = 0.0,
)

internal fun referralSummary(
    referrals: List<EngineerReferralRepository.MyReferral>,
): ReferralSummary {
    var paidCount = 0
    var earned = 0.0
    var pending = 0
    var queued = 0.0
    for (r in referrals) {
        if (r.bountyRevoked) continue
        when {
            r.payoutStatus == "paid" -> {
                paidCount++
                earned += r.bountyAmountRupees
            }
            r.payoutStatus == "queued" -> {
                pending++
                queued += r.bountyAmountRupees
            }
            r.bountyEligible -> pending++ // eligible, payout row not minted yet
        }
    }
    return ReferralSummary(
        totalReferred = referrals.size,
        paidCount = paidCount,
        earnedRupees = earned,
        pendingCount = pending,
        queuedRupees = queued,
    )
}

/**
 * Status pill for one referral. Precedence pinned deliberately:
 *  1. revoked wins over any payout state (a revoked bounty's payout row is
 *     cancelled, so it must never read "Paid"/"Queued")
 *  2. an explicit payout row ("paid" / "queued") beats the eligible flag
 *  3. eligible-but-no-payout-row = "Eligible"
 *  4. default = still awaiting the referee's first paid job
 */
internal fun referralBountyPillTextAndKind(
    bountyEligible: Boolean,
    bountyRevoked: Boolean,
    payoutStatus: String?,
): Pair<String, PillKind> = when {
    bountyRevoked -> "Revoked" to PillKind.Danger
    payoutStatus == "paid" -> "Paid" to PillKind.Success
    payoutStatus == "queued" -> "Bounty queued" to PillKind.Info
    bountyEligible -> "Eligible" to PillKind.Info
    else -> "Awaiting first job" to PillKind.Neutral
}

/**
 * The RPC exposes only the referee's user_id (never their name — that would
 * leak PII across the referral edge). Render a stable masked label built
 * from the last 4 id chars. Uppercased via [java.util.Locale.ROOT] so the
 * Turkish-locale i-casing bug can't shift a hex digit's rendering.
 * The mask glyph is U+2022 BULLET (••).
 */
internal fun refereeShortLabel(refereeUserId: String): String {
    val tail = refereeUserId.takeLast(4).uppercase(java.util.Locale.ROOT)
    return "Engineer ••$tail"
}

/**
 * Validation for the "were you referred?" code box.
 *  - blank input → null (no error shown; the submit button gates on
 *    isNotBlank separately)
 *  - the engineer's own code → self-referral, which the server also blocks
 *    (cannot_refer_self); catch it client-side for an instant, friendlier
 *    message
 *  - otherwise null (the server does the authoritative existence checks)
 */
internal fun referralCodeInputError(input: String, ownUserId: String?): String? {
    val code = input.trim()
    if (code.isEmpty()) return null
    if (ownUserId != null && code.equals(ownUserId.trim(), ignoreCase = true)) {
        return "That's your own code — you can't refer yourself."
    }
    return null
}
