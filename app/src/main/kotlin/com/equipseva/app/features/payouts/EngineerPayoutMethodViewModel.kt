package com.equipseva.app.features.payouts

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.data.payouts.EngineerPayoutMethod
import com.equipseva.app.core.data.payouts.EngineerPayoutRepository
import com.equipseva.app.core.data.payouts.PayoutMethodKind
import com.equipseva.app.core.network.toUserMessage
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/**
 * UPI-first capture screen so engineer's auto-payout has a destination.
 *
 * Two modes via a segmented control:
 *  - UPI: just the VPA (e.g. ganesh@oksbi) — fastest path, lands as IMPS
 *    in seconds via RazorpayX Payouts (mode=UPI).
 *  - Bank: account holder + IFSC + account number, posted as IMPS too
 *    when the UPI rail is unavailable for the engineer.
 *
 * Saves via `set_engineer_payout_method` RPC, which UPSERTs and atomically
 * flips `is_default` so the trigger from round 422 picks up the new row
 * for any future escrow release. Existing queued payouts (the 3 backfill
 * rows from RPR-00021/-00033/-00034) won't auto-attach to the new method
 * — round 424's worker will re-resolve `payout_method_id` at pickup time
 * when it's currently NULL.
 */
@HiltViewModel
class EngineerPayoutMethodViewModel @Inject constructor(
    private val repo: EngineerPayoutRepository,
) : ViewModel() {

    data class UiState(
        val loading: Boolean = true,
        val current: EngineerPayoutMethod? = null,
        val mode: PayoutMethodKind = PayoutMethodKind.Upi,
        // UPI form.
        val vpa: String = "",
        val vpaHolderName: String = "",
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
        val canSubmitUpi: Boolean
            get() = !saving && vpaValid(vpa)
        val canSubmitBank: Boolean
            get() = !saving &&
                bankAccountHolder.isNotBlank() &&
                ifscValid(bankIfsc) &&
                accountNumberValid(bankAccountNumber) &&
                bankAccountNumber == bankAccountNumberConfirm
    }

    sealed interface Effect {
        data class ShowMessage(val text: String) : Effect
        data object Saved : Effect
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
            repo.fetchCurrent()
                .onSuccess { existing ->
                    _state.update {
                        it.copy(
                            loading = false,
                            current = existing,
                            mode = existing?.kind ?: PayoutMethodKind.Upi,
                            vpa = existing?.vpa.orEmpty(),
                            vpaHolderName = existing?.vpaHolderName.orEmpty(),
                            bankAccountHolder = existing?.bankAccountHolder.orEmpty(),
                            bankIfsc = existing?.ifsc.orEmpty(),
                            bankName = existing?.bankName.orEmpty(),
                            // Never repopulate account number — we don't
                            // hold plaintext client-side after save, and
                            // showing the masked last4 here would mislead
                            // the engineer into thinking they typed it.
                            bankAccountNumber = "",
                            bankAccountNumberConfirm = "",
                        )
                    }
                }
                .onFailure { e ->
                    _state.update {
                        it.copy(loading = false, errorMessage = e.toUserMessage())
                    }
                }
        }
    }

    fun onModeChange(kind: PayoutMethodKind) {
        _state.update { it.copy(mode = kind, errorMessage = null) }
    }

    fun onVpaChange(v: String) {
        _state.update { it.copy(vpa = v.trim(), vpaError = null, errorMessage = null) }
    }
    fun onVpaHolderChange(v: String) {
        _state.update { it.copy(vpaHolderName = v, errorMessage = null) }
    }
    fun onBankAccountHolderChange(v: String) {
        _state.update { it.copy(bankAccountHolder = v, bankError = null, errorMessage = null) }
    }
    fun onBankIfscChange(v: String) {
        _state.update { it.copy(bankIfsc = v.uppercase(), bankError = null, errorMessage = null) }
    }
    fun onBankAccountNumberChange(v: String) {
        _state.update { it.copy(bankAccountNumber = v.filter { it.isDigit() }, bankError = null, errorMessage = null) }
    }
    fun onBankAccountNumberConfirmChange(v: String) {
        _state.update { it.copy(bankAccountNumberConfirm = v.filter { it.isDigit() }, bankError = null, errorMessage = null) }
    }
    fun onBankNameChange(v: String) {
        _state.update { it.copy(bankName = v, errorMessage = null) }
    }

    fun save() {
        val s = _state.value
        if (s.saving) return
        when (s.mode) {
            PayoutMethodKind.Upi -> {
                if (!vpaValid(s.vpa)) {
                    _state.update { it.copy(vpaError = "Enter a valid UPI ID, like name@bank.") }
                    return
                }
                _state.update { it.copy(saving = true, errorMessage = null) }
                viewModelScope.launch {
                    repo.setUpi(s.vpa, s.vpaHolderName.takeIf { it.isNotBlank() })
                        .onSuccess { onSaved() }
                        .onFailure { e ->
                            _state.update { it.copy(saving = false, errorMessage = e.toUserMessage()) }
                        }
                }
            }
            PayoutMethodKind.Bank -> {
                if (!s.canSubmitBank) {
                    val err = when {
                        s.bankAccountHolder.isBlank() -> "Account holder name is required."
                        !ifscValid(s.bankIfsc) -> "IFSC must be 11 characters (e.g. SBIN0001234)."
                        !accountNumberValid(s.bankAccountNumber) -> "Account number looks too short."
                        s.bankAccountNumber != s.bankAccountNumberConfirm -> "Re-typed account number doesn't match."
                        else -> "Check the fields and try again."
                    }
                    _state.update { it.copy(bankError = err) }
                    return
                }
                _state.update { it.copy(saving = true, errorMessage = null) }
                viewModelScope.launch {
                    repo.setBank(
                        accountHolder = s.bankAccountHolder,
                        accountNumber = s.bankAccountNumber,
                        ifsc = s.bankIfsc,
                        bankName = s.bankName.takeIf { it.isNotBlank() },
                    )
                        .onSuccess { onSaved() }
                        .onFailure { e ->
                            _state.update { it.copy(saving = false, errorMessage = e.toUserMessage()) }
                        }
                }
            }
        }
    }

    private fun onSaved() {
        _state.update { it.copy(saving = false) }
        viewModelScope.launch {
            _effects.emit(Effect.ShowMessage("Saved"))
            _effects.emit(Effect.Saved)
        }
        load()
    }

    companion object {
        // Loose VPA shape — matches Razorpay's accepted set (alnum + . _ -
        // before @, alpha-only handle). Server-side RPC re-validates with
        // the same regex; Razorpay rejects bad VPAs at the payouts call.
        private val VPA_REGEX = Regex("^[a-zA-Z0-9._-]+@[a-zA-Z]+$")
        // IFSC: 4-letter bank + "0" + 6 alnum, total 11.
        private val IFSC_REGEX = Regex("^[A-Z]{4}0[A-Z0-9]{6}$")

        fun vpaValid(v: String): Boolean = VPA_REGEX.matches(v.trim())
        fun ifscValid(v: String): Boolean = IFSC_REGEX.matches(v.trim().uppercase())
        fun accountNumberValid(v: String): Boolean = v.length in 9..18 && v.all { it.isDigit() }
    }
}
