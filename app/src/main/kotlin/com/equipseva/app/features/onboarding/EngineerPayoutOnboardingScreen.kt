package com.equipseva.app.features.onboarding

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.AccountBalance
import androidx.compose.material.icons.outlined.AccountBalanceWallet
import androidx.compose.material.icons.outlined.CheckCircle
import androidx.compose.material.icons.outlined.RadioButtonUnchecked
import androidx.compose.material3.Icon
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import com.equipseva.app.R
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.data.payouts.EngineerPayoutRepository
import com.equipseva.app.core.data.payouts.PayoutMethodKind
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.designsystem.components.EsBtn
import com.equipseva.app.designsystem.components.EsBtnKind
import com.equipseva.app.designsystem.components.EsBtnSize
import com.equipseva.app.designsystem.components.EsField
import com.equipseva.app.designsystem.components.EsFieldType
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaDanger500
import com.equipseva.app.designsystem.theme.SevaGreen50
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk900
import com.equipseva.app.features.payouts.EngineerPayoutMethodViewModel.Companion.accountNumberValid
import com.equipseva.app.features.payouts.EngineerPayoutMethodViewModel.Companion.ifscValid
import com.equipseva.app.features.payouts.EngineerPayoutMethodViewModel.Companion.vpaValid
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/**
 * Round 425. Mandatory second onboarding step for engineers — captures
 * BOTH a UPI VPA and a bank account so the auto-payout pipeline always
 * has a destination. Reached from [AppNavGraph]'s onboarding host when
 * Profile.hasEngineerPayoutComplete is false (computed server-side via
 * engineer_has_complete_payout_methods).
 *
 * No skip. The founder's stance is that an engineer without a bank
 * fallback is a payout-failure risk we want to discover at onboarding
 * instead of after their first ₹9.30 attempt bounces.
 *
 * Persistence is two RPC calls sequenced: setUpi first (cheaper, fails
 * faster on a malformed VPA), then setBank. Each call independently
 * UPSERTs by (user_id, kind) — re-entering the screen after a partial
 * failure resumes from where the engineer left off (the row that did
 * save stays). On all-saved success the screen emits Done; the session
 * VM re-fetches the profile, hasCompletedV2Onboarding flips true, the
 * AppNavGraph promotes the user to MAIN_HOST_ROUTE.
 */
@HiltViewModel
class EngineerPayoutOnboardingViewModel @Inject constructor(
    private val payoutRepository: EngineerPayoutRepository,
    // Round 435 fix #1 — escape hatch needs sign-out path.
    private val authRepository: AuthRepository,
) : ViewModel() {

    data class UiState(
        val loading: Boolean = true,
        val hasUpi: Boolean = false,
        val hasBank: Boolean = false,
        // UPI form.
        val vpa: String = "",
        val vpaHolder: String = "",
        val vpaError: String? = null,
        // Bank form.
        val bankAccountHolder: String = "",
        val bankIfsc: String = "",
        val bankAccountNumber: String = "",
        val bankAccountNumberConfirm: String = "",
        val bankName: String = "",
        val bankError: String? = null,
        val saving: Boolean = false,
        val errorMessage: String? = null,
        // Round 435 fix #1 — sign-out confirm dialog state.
        val signOutConfirmOpen: Boolean = false,
        val signingOut: Boolean = false,
        // Round 438 fix #11 — IFSC live lookup state.
        val ifscLookupInFlight: Boolean = false,
        val ifscResolved: ResolvedIfsc? = null,
        val ifscLookupFailed: Boolean = false,
        // Round 438 fix #10 — visible mismatch state on the re-type
        // field as soon as it diverges from the primary, not only
        // when the engineer taps Save.
        val accountNumberMismatch: Boolean = false,
    ) {
        val canSubmit: Boolean
            get() = !saving &&
                (hasUpi || vpaValid(vpa)) &&
                (hasBank || (
                    bankAccountHolder.isNotBlank() &&
                        ifscValid(bankIfsc) &&
                        accountNumberValid(bankAccountNumber) &&
                        bankAccountNumber == bankAccountNumberConfirm
                ))
    }

    /**
     * Round 438 fix #11 — IFSC lookup result from
     * https://ifsc.razorpay.com/<IFSC> (free, no-auth). Holds the
     * fields we render under the IFSC input: bank name + branch +
     * city. Other fields available from the API (district, state,
     * MICR, ISO3166, contact) are dropped — they'd just clutter the
     * compact confirmation line.
     */
    data class ResolvedIfsc(
        val bank: String,
        val branch: String,
        val city: String,
    )

    sealed interface Effect {
        data object Done : Effect
        data class ShowMessage(val text: String) : Effect
    }

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    private val _effects = MutableSharedFlow<Effect>(extraBufferCapacity = 4)
    val effects: kotlinx.coroutines.flow.Flow<Effect> = _effects

    init {
        load()
    }

    fun load() {
        _state.update { it.copy(loading = true, errorMessage = null) }
        viewModelScope.launch {
            payoutRepository.fetchAll()
                .onSuccess { methods ->
                    _state.update {
                        it.copy(
                            loading = false,
                            hasUpi = methods.any { m -> m.kind == PayoutMethodKind.Upi },
                            hasBank = methods.any { m -> m.kind == PayoutMethodKind.Bank },
                        )
                    }
                }
                .onFailure { e ->
                    _state.update { it.copy(loading = false, errorMessage = e.toUserMessage()) }
                }
        }
    }

    fun onVpaChange(v: String) =
        _state.update { it.copy(vpa = v.trim(), vpaError = null, errorMessage = null) }
    fun onVpaHolderChange(v: String) =
        _state.update { it.copy(vpaHolder = v, errorMessage = null) }
    fun onBankAccountHolderChange(v: String) =
        _state.update { it.copy(bankAccountHolder = v, bankError = null, errorMessage = null) }
    fun onBankIfscChange(v: String) {
        val clean = v.uppercase().take(11)
        _state.update {
            it.copy(
                bankIfsc = clean,
                bankError = null,
                errorMessage = null,
                // Reset lookup state whenever the engineer edits the
                // field. Avoids a stale "SBIN0001234 → State Bank of
                // India, Hyderabad" confirmation hanging around after
                // a backspace-and-edit.
                ifscResolved = null,
                ifscLookupFailed = false,
            )
        }
        // Round 438 fix #11 — fire lookup once we have a fully-formed
        // IFSC. The validator already enforces 4 letters + "0" + 6
        // alnum, so this triggers exactly once per stable input.
        if (ifscValid(clean)) {
            fetchIfscLookup(clean)
        }
    }

    fun onBankAccountNumberChange(v: String) {
        val clean = v.filter { it.isDigit() }
        _state.update {
            it.copy(
                bankAccountNumber = clean,
                bankError = null,
                errorMessage = null,
                accountNumberMismatch = recomputeAccountMismatch(clean, it.bankAccountNumberConfirm),
            )
        }
    }
    fun onBankAccountNumberConfirmChange(v: String) {
        val clean = v.filter { it.isDigit() }
        _state.update {
            it.copy(
                bankAccountNumberConfirm = clean,
                bankError = null,
                errorMessage = null,
                accountNumberMismatch = recomputeAccountMismatch(it.bankAccountNumber, clean),
            )
        }
    }

    /**
     * Round 438 fix #10 — return true when both numbers are non-blank,
     * the confirm field has reached at least the primary's length,
     * AND they diverge. Returns false while the confirm is still
     * shorter (user is mid-type) so we don't nag prematurely.
     */
    private fun recomputeAccountMismatch(primary: String, confirm: String): Boolean {
        if (primary.isBlank() || confirm.isBlank()) return false
        if (confirm.length < primary.length) return false
        return primary != confirm
    }

    /**
     * Round 438 fix #11 — public Razorpay IFSC API. Free, no auth,
     * stable for years. Best-effort: on network or 404 we leave the
     * field editable and the user proceeds; the server still
     * validates the 11-char shape via the round-422 RPC.
     */
    private fun fetchIfscLookup(ifsc: String) {
        _state.update { it.copy(ifscLookupInFlight = true, ifscLookupFailed = false) }
        viewModelScope.launch {
            val resolved = withContext(kotlinx.coroutines.Dispatchers.IO) {
                runCatching {
                    val url = java.net.URL("https://ifsc.razorpay.com/$ifsc")
                    val conn = url.openConnection() as java.net.HttpURLConnection
                    conn.connectTimeout = 4000
                    conn.readTimeout = 4000
                    conn.requestMethod = "GET"
                    if (conn.responseCode != 200) return@runCatching null
                    val text = conn.inputStream.bufferedReader().use { it.readText() }
                    val json = kotlinx.serialization.json.Json
                        .parseToJsonElement(text)
                        .jsonObject
                    ResolvedIfsc(
                        bank = json["BANK"]?.jsonPrimitive?.contentOrNull.orEmpty(),
                        branch = json["BRANCH"]?.jsonPrimitive?.contentOrNull.orEmpty(),
                        city = json["CITY"]?.jsonPrimitive?.contentOrNull.orEmpty(),
                    )
                }.getOrNull()
            }
            _state.update {
                if (resolved != null && resolved.bank.isNotBlank()) {
                    it.copy(
                        ifscLookupInFlight = false,
                        ifscResolved = resolved,
                        ifscLookupFailed = false,
                        // Auto-fill bank name so the engineer doesn't
                        // hand-type "State Bank of India" after the
                        // API just confirmed it.
                        bankName = if (it.bankName.isBlank()) resolved.bank else it.bankName,
                    )
                } else {
                    it.copy(
                        ifscLookupInFlight = false,
                        ifscResolved = null,
                        ifscLookupFailed = true,
                    )
                }
            }
        }
    }
    fun onBankNameChange(v: String) =
        _state.update { it.copy(bankName = v, errorMessage = null) }

    fun save() {
        val s = _state.value
        if (s.saving || s.loading) return
        if (!s.canSubmit) {
            _state.update {
                it.copy(
                    vpaError = if (!s.hasUpi && !vpaValid(s.vpa)) "Enter a valid UPI ID, like name@bank." else it.vpaError,
                    bankError = when {
                        s.hasBank -> it.bankError
                        s.bankAccountHolder.isBlank() -> "Account holder name is required."
                        !ifscValid(s.bankIfsc) -> "IFSC must be 11 characters (e.g. SBIN0001234)."
                        !accountNumberValid(s.bankAccountNumber) -> "Account number looks too short."
                        s.bankAccountNumber != s.bankAccountNumberConfirm -> "Re-typed account number doesn't match."
                        else -> it.bankError
                    },
                )
            }
            return
        }
        _state.update { it.copy(saving = true, errorMessage = null) }
        viewModelScope.launch {
            // Step 1: UPI (skip if already saved).
            if (!s.hasUpi) {
                val upiRes = payoutRepository.setUpi(s.vpa, s.vpaHolder.takeIf { it.isNotBlank() })
                if (upiRes.isFailure) {
                    _state.update {
                        it.copy(
                            saving = false,
                            errorMessage = "Couldn't save UPI: ${upiRes.exceptionOrNull()?.toUserMessage().orEmpty()}",
                        )
                    }
                    return@launch
                }
                _state.update { it.copy(hasUpi = true) }
            }
            // Step 2: Bank (skip if already saved).
            if (!_state.value.hasBank) {
                val bankRes = payoutRepository.setBank(
                    accountHolder = s.bankAccountHolder,
                    accountNumber = s.bankAccountNumber,
                    ifsc = s.bankIfsc,
                    bankName = s.bankName.takeIf { it.isNotBlank() },
                )
                if (bankRes.isFailure) {
                    _state.update {
                        it.copy(
                            saving = false,
                            errorMessage = "Couldn't save bank: ${bankRes.exceptionOrNull()?.toUserMessage().orEmpty()}",
                        )
                    }
                    return@launch
                }
                _state.update { it.copy(hasBank = true) }
            }
            _state.update { it.copy(saving = false) }
            _effects.emit(Effect.ShowMessage("Payout details saved"))
            _effects.emit(Effect.Done)
        }
    }

    /* --- round 435 fix #1: sign-out escape hatch --- */
    fun openSignOutConfirm() = _state.update { it.copy(signOutConfirmOpen = true) }
    fun dismissSignOutConfirm() = _state.update { it.copy(signOutConfirmOpen = false) }
    fun confirmSignOut() {
        if (_state.value.signingOut) return
        _state.update { it.copy(signingOut = true, signOutConfirmOpen = false) }
        viewModelScope.launch {
            authRepository.signOut()
                .onFailure { e ->
                    _state.update { it.copy(signingOut = false, errorMessage = e.toUserMessage()) }
                }
            // On success, SessionViewModel transitions to SignedOut +
            // root nav re-routes to AuthHostInline. No explicit
            // navigation needed here.
        }
    }
}

@Composable
fun EngineerPayoutOnboardingScreen(
    onDone: () -> Unit,
    onShowMessage: (String) -> Unit,
    viewModel: EngineerPayoutOnboardingViewModel = hiltViewModel(),
) {
    val s by viewModel.state.collectAsStateWithLifecycle()

    LaunchedEffect(viewModel) {
        viewModel.effects.collect { e ->
            when (e) {
                is EngineerPayoutOnboardingViewModel.Effect.ShowMessage -> onShowMessage(e.text)
                EngineerPayoutOnboardingViewModel.Effect.Done -> onDone()
            }
        }
    }

    // Round 435 fix #1 — sign-out confirm dialog. Mandatory != trapped.
    if (s.signOutConfirmOpen) {
        androidx.compose.material3.AlertDialog(
            onDismissRequest = viewModel::dismissSignOutConfirm,
            title = { Text(stringResource(R.string.engineer_payout_onboarding_sign_out_confirm_title)) },
            text = {
                Text(
                    stringResource(R.string.engineer_payout_onboarding_sign_out_confirm_body),
                )
            },
            confirmButton = {
                androidx.compose.material3.TextButton(
                    onClick = viewModel::confirmSignOut,
                    enabled = !s.signingOut,
                ) {
                    Text(if (s.signingOut) stringResource(R.string.profile_signout_in_progress_label) else stringResource(R.string.profile_signout_action_label))
                }
            },
            dismissButton = {
                androidx.compose.material3.TextButton(
                    onClick = viewModel::dismissSignOutConfirm,
                ) { Text(stringResource(R.string.engineer_payout_onboarding_stay_here)) }
            },
        )
    }

    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            // Round 435 fix #1 — top bar with back = sign-out path,
            // so an engineer who picked the wrong role or doesn't
            // have their bank passbook handy isn't trapped here.
            com.equipseva.app.designsystem.components.EsTopBar(
                title = "Add payout details",
                onBack = viewModel::openSignOutConfirm,
            )
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 20.dp, vertical = 24.dp),
                verticalArrangement = Arrangement.spacedBy(14.dp),
            ) {
            Text(
                stringResource(R.string.engineer_payout_onboarding_title),
                fontSize = 28.sp,
                fontWeight = FontWeight.Bold,
                color = SevaInk900,
            )
            Text(
                stringResource(R.string.engineer_payout_onboarding_description),
                fontSize = 14.sp,
                color = SevaInk500,
            )

            // Round 439 fix #9 — explicit partial-save banner when one
            // method already saved and the other isn't. Without this
            // the engineer sees the saved section silently switch to
            // green (round 425 SectionCard.done state) and the other
            // section in an error state — same visual ambiguity as
            // success. The banner names what just happened + what's
            // left.
            if (s.hasUpi && !s.hasBank) {
                PartialSaveBanner(
                    icon = Icons.Outlined.CheckCircle,
                    text = "UPI saved · finish saving your bank account below.",
                )
            } else if (!s.hasUpi && s.hasBank) {
                PartialSaveBanner(
                    icon = Icons.Outlined.CheckCircle,
                    text = "Bank saved · finish saving your UPI above.",
                )
            }

            Spacer(Modifier.height(4.dp))

            // ---- UPI section ----
            SectionCard(
                title = "UPI",
                icon = Icons.Outlined.AccountBalanceWallet,
                done = s.hasUpi,
                doneLabel = "UPI saved",
            ) {
                if (!s.hasUpi) {
                    EsField(
                        value = s.vpa,
                        onChange = viewModel::onVpaChange,
                        label = "UPI ID (VPA)",
                        placeholder = "name@oksbi",
                        hint = "Same as the UPI ID you'd put on a payment request.",
                        error = s.vpaError,
                        enabled = !s.saving,
                    )
                    Spacer(Modifier.height(10.dp))
                    EsField(
                        value = s.vpaHolder,
                        onChange = viewModel::onVpaHolderChange,
                        label = "Name on UPI (optional)",
                        placeholder = "Name as shown in your UPI app",
                        enabled = !s.saving,
                    )
                }
            }

            // ---- Bank section ----
            SectionCard(
                title = "Bank account",
                icon = Icons.Outlined.AccountBalance,
                done = s.hasBank,
                doneLabel = "Bank saved",
            ) {
                if (!s.hasBank) {
                    EsField(
                        value = s.bankAccountHolder,
                        onChange = viewModel::onBankAccountHolderChange,
                        label = "Account holder name",
                        placeholder = "Name on the bank account",
                        enabled = !s.saving,
                    )
                    Spacer(Modifier.height(10.dp))
                    EsField(
                        value = s.bankIfsc,
                        onChange = viewModel::onBankIfscChange,
                        label = "IFSC code",
                        placeholder = "SBIN0001234",
                        hint = "Front of your cheque book or net-banking dashboard.",
                        enabled = !s.saving,
                    )
                    // Round 438 fix #11 — IFSC live-lookup confirmation.
                    when {
                        s.ifscLookupInFlight -> {
                            Spacer(Modifier.height(4.dp))
                            Text(
                                stringResource(R.string.engineer_payout_onboarding_ifsc_looking_up),
                                fontSize = 12.sp,
                                color = SevaInk500,
                            )
                        }
                        s.ifscResolved != null -> {
                            Spacer(Modifier.height(4.dp))
                            Text(
                                stringResource(
                                    R.string.engineer_payout_onboarding_ifsc_resolved,
                                    s.ifscResolved!!.bank,
                                    s.ifscResolved!!.branch,
                                    s.ifscResolved!!.city,
                                ),
                                fontSize = 12.sp,
                                color = SevaGreen700,
                                fontWeight = FontWeight.Medium,
                            )
                        }
                        s.ifscLookupFailed -> {
                            Spacer(Modifier.height(4.dp))
                            Text(
                                stringResource(R.string.engineer_payout_onboarding_ifsc_unverified),
                                fontSize = 12.sp,
                                color = SevaInk500,
                            )
                        }
                    }
                    Spacer(Modifier.height(10.dp))
                    EsField(
                        value = s.bankAccountNumber,
                        onChange = viewModel::onBankAccountNumberChange,
                        label = "Account number",
                        placeholder = "9 to 18 digits",
                        type = EsFieldType.Number,
                        enabled = !s.saving,
                    )
                    Spacer(Modifier.height(10.dp))
                    EsField(
                        value = s.bankAccountNumberConfirm,
                        onChange = viewModel::onBankAccountNumberConfirmChange,
                        label = "Re-type account number",
                        type = EsFieldType.Number,
                        enabled = !s.saving,
                        // Round 438 fix #10 — inline error the moment the
                        // re-type diverges, not just on Save tap.
                        error = if (s.accountNumberMismatch) "Numbers don't match" else null,
                    )
                    Spacer(Modifier.height(10.dp))
                    EsField(
                        value = s.bankName,
                        onChange = viewModel::onBankNameChange,
                        label = "Bank name (optional)",
                        placeholder = "State Bank of India",
                        enabled = !s.saving,
                    )
                    if (s.bankError != null) {
                        Spacer(Modifier.height(6.dp))
                        Text(s.bankError.orEmpty(), fontSize = 13.sp, color = SevaDanger500)
                    }
                }
            }

            if (s.errorMessage != null) {
                Text(s.errorMessage.orEmpty(), fontSize = 13.sp, color = SevaDanger500)
            }

            Spacer(Modifier.height(12.dp))

            EsBtn(
                text = if (s.saving) "Saving…" else "Save and continue",
                onClick = viewModel::save,
                kind = EsBtnKind.Primary,
                size = EsBtnSize.Lg,
                full = true,
                disabled = !s.canSubmit,
            )
            }  // inner scroll Column
        }  // outer top-bar Column
    }  // Surface
}

@Composable
private fun PartialSaveBanner(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    text: String,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(SevaGreen50)
            .border(width = 1.dp, color = SevaGreen700, shape = RoundedCornerShape(10.dp))
            .padding(horizontal = 12.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = SevaGreen700,
            modifier = Modifier.size(18.dp),
        )
        Text(
            text = text,
            fontSize = 13.sp,
            color = SevaGreen700,
            fontWeight = FontWeight.Medium,
        )
    }
}

@Composable
private fun SectionCard(
    title: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    done: Boolean,
    doneLabel: String,
    body: @Composable () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(if (done) SevaGreen50 else PaperDefault)
            .border(width = 1.dp, color = BorderDefault, shape = RoundedCornerShape(12.dp))
            .padding(14.dp),
    ) {
        // Round 438 fix #12 — semantically merge the row into one
        // announcement so TalkBack reads e.g. "UPI section, completed"
        // rather than three separate icon-with-no-label hits. Section
        // title gets heading() semantics so a TalkBack user can hop
        // between sections via the heading-jump gesture.
        Row(
            modifier = Modifier
                .semantics(mergeDescendants = true) {
                    heading()
                    contentDescription = if (done) "$title section, completed" else "$title section, not yet completed"
                },
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Icon(
                imageVector = if (done) Icons.Outlined.CheckCircle else Icons.Outlined.RadioButtonUnchecked,
                contentDescription = null,
                tint = if (done) SevaGreen700 else SevaInk500,
                modifier = Modifier.size(20.dp),
            )
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = SevaInk500,
                modifier = Modifier.size(18.dp),
            )
            Text(
                title,
                fontSize = 16.sp,
                fontWeight = FontWeight.SemiBold,
                color = SevaInk900,
            )
        }
        if (done) {
            Spacer(Modifier.height(6.dp))
            Text(doneLabel, fontSize = 13.sp, color = SevaGreen700)
        } else {
            Spacer(Modifier.height(10.dp))
            body()
        }
    }
}
