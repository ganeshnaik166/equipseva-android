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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
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
    fun onBankIfscChange(v: String) =
        _state.update { it.copy(bankIfsc = v.uppercase(), bankError = null, errorMessage = null) }
    fun onBankAccountNumberChange(v: String) =
        _state.update { it.copy(bankAccountNumber = v.filter { it.isDigit() }, bankError = null, errorMessage = null) }
    fun onBankAccountNumberConfirmChange(v: String) =
        _state.update { it.copy(bankAccountNumberConfirm = v.filter { it.isDigit() }, bankError = null, errorMessage = null) }
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

    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp, vertical = 24.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Text(
                "Add payout details",
                fontSize = 28.sp,
                fontWeight = FontWeight.Bold,
                color = SevaInk900,
            )
            Text(
                "We need both UPI and a bank account on file before you can start " +
                    "accepting jobs. When a hospital confirms a job, we auto-transfer " +
                    "your share — UPI in seconds, bank as the backup if UPI ever fails.",
                fontSize = 14.sp,
                color = SevaInk500,
            )

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
        }
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
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
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
