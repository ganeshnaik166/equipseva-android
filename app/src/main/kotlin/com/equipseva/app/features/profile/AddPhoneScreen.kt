package com.equipseva.app.features.profile

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.designsystem.components.EsBtn
import com.equipseva.app.designsystem.components.EsBtnKind
import com.equipseva.app.designsystem.components.EsBtnSize
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk900
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/**
 * Single-screen flow for an *already signed-in* user to attach (or change)
 * their phone number. Two states sharing one screen:
 *
 *  1. Request — enter +91… → tap Send code → Supabase fires SMS via
 *     [AuthRepository.requestPhoneAdd], we flip `step = Verify`.
 *  2. Verify  — paste 6-digit code → tap Verify → [AuthRepository.verifyPhoneAdd]
 *     confirms, we send [Effect.Done] and the screen pops.
 *
 * Used from KYC Step 1 (engineer Contact card) and from the Profile screen's
 * "Add phone" banner. Both call back the same nav route.
 */
@HiltViewModel
class AddPhoneViewModel @Inject constructor(
    private val authRepository: AuthRepository,
) : ViewModel() {

    enum class Step { Request, Verify }

    data class UiState(
        val step: Step = Step.Request,
        val phone: String = "+91",
        val code: String = "",
        val sending: Boolean = false,
        val verifying: Boolean = false,
        val resending: Boolean = false,
        val error: String? = null,
    )

    sealed interface Effect {
        data object Done : Effect
        data class ShowMessage(val text: String) : Effect
    }

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    private val _effects = Channel<Effect>(Channel.BUFFERED)
    val effects = _effects.receiveAsFlow()

    fun onPhoneChange(value: String) {
        // Allow leading + then digits, max 16 chars (E.164 + a little buffer).
        val cleaned = value.filterIndexed { i, c -> (i == 0 && c == '+') || c.isDigit() }.take(16)
        _state.update { it.copy(phone = cleaned, error = null) }
    }

    fun onCodeChange(value: String) {
        val cleaned = value.filter { it.isDigit() }.take(6)
        _state.update { it.copy(code = cleaned, error = null) }
    }

    fun onSendCode() {
        val phone = _state.value.phone.trim()
        if (!phone.startsWith("+") || phone.length < 10) {
            _state.update { it.copy(error = "Enter the number in international format, e.g. +919999999999") }
            return
        }
        _state.update { it.copy(sending = true, error = null) }
        viewModelScope.launch {
            authRepository.requestPhoneAdd(phone)
                .onSuccess {
                    _state.update { it.copy(sending = false, step = Step.Verify) }
                    _effects.send(Effect.ShowMessage("Code sent to $phone"))
                }
                .onFailure { e ->
                    _state.update { it.copy(sending = false, error = e.toUserMessage()) }
                }
        }
    }

    fun onVerify() {
        val phone = _state.value.phone.trim()
        val code = _state.value.code
        if (code.length != 6) {
            _state.update { it.copy(error = "Enter the 6-digit code") }
            return
        }
        _state.update { it.copy(verifying = true, error = null) }
        viewModelScope.launch {
            authRepository.verifyPhoneAdd(phone, code)
                .onSuccess {
                    _state.update { it.copy(verifying = false) }
                    _effects.send(Effect.ShowMessage("Phone added"))
                    _effects.send(Effect.Done)
                }
                .onFailure { e ->
                    _state.update { it.copy(verifying = false, error = e.toUserMessage()) }
                }
        }
    }

    fun onResend() {
        if (_state.value.resending) return
        _state.update { it.copy(resending = true, error = null) }
        viewModelScope.launch {
            authRepository.requestPhoneAdd(_state.value.phone)
                .onFailure { e -> _state.update { it.copy(error = e.toUserMessage()) } }
            _state.update { it.copy(resending = false) }
        }
    }

    fun onEditNumber() {
        _state.update { it.copy(step = Step.Request, code = "", error = null) }
    }
}

@Composable
fun AddPhoneScreen(
    onBack: () -> Unit,
    onShowMessage: (String) -> Unit,
    viewModel: AddPhoneViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsState()

    LaunchedEffect(viewModel) {
        viewModel.effects.collect { e ->
            when (e) {
                is AddPhoneViewModel.Effect.ShowMessage -> onShowMessage(e.text)
                AddPhoneViewModel.Effect.Done -> onBack()
            }
        }
    }

    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(title = "Add phone number", onBack = onBack)
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                when (state.step) {
                    AddPhoneViewModel.Step.Request -> RequestStep(
                        state = state,
                        onPhoneChange = viewModel::onPhoneChange,
                        onSend = viewModel::onSendCode,
                    )
                    AddPhoneViewModel.Step.Verify -> VerifyStep(
                        state = state,
                        onCodeChange = viewModel::onCodeChange,
                        onVerify = viewModel::onVerify,
                        onResend = viewModel::onResend,
                        onEditNumber = viewModel::onEditNumber,
                    )
                }
            }
        }
    }
}

@Composable
private fun RequestStep(
    state: AddPhoneViewModel.UiState,
    onPhoneChange: (String) -> Unit,
    onSend: () -> Unit,
) {
    Text("Enter your mobile number", fontSize = 22.sp, fontWeight = FontWeight.Bold, color = SevaInk900)
    Text(
        "Hospitals will Call and WhatsApp you on this number once you're verified. We'll send a 6-digit code to confirm it's yours.",
        fontSize = 13.sp,
        color = SevaInk500,
    )
    OutlinedTextField(
        value = state.phone,
        onValueChange = onPhoneChange,
        label = { Text("Phone (e.g. +919999999999)") },
        singleLine = true,
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone),
        isError = state.error != null,
        supportingText = state.error?.let { { Text(it) } },
        enabled = !state.sending,
        modifier = Modifier.fillMaxWidth(),
    )
    Spacer(Modifier.height(8.dp))
    EsBtn(
        text = if (state.sending) "Sending…" else "Send code",
        onClick = onSend,
        kind = EsBtnKind.Primary,
        size = EsBtnSize.Lg,
        full = true,
        disabled = state.sending || state.phone.length < 10,
    )
}

@Composable
private fun VerifyStep(
    state: AddPhoneViewModel.UiState,
    onCodeChange: (String) -> Unit,
    onVerify: () -> Unit,
    onResend: () -> Unit,
    onEditNumber: () -> Unit,
) {
    Text("Enter the 6-digit code", fontSize = 22.sp, fontWeight = FontWeight.Bold, color = SevaInk900)
    Text("Sent to ${state.phone}", fontSize = 13.sp, color = SevaInk500)
    Spacer(Modifier.height(8.dp))
    OutlinedTextField(
        value = state.code,
        onValueChange = onCodeChange,
        label = { Text("Code") },
        singleLine = true,
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.NumberPassword),
        isError = state.error != null,
        supportingText = state.error?.let { { Text(it) } },
        enabled = !state.verifying,
        modifier = Modifier.fillMaxWidth(),
    )
    Spacer(Modifier.height(8.dp))
    EsBtn(
        text = if (state.verifying) "Verifying…" else "Verify",
        onClick = onVerify,
        kind = EsBtnKind.Primary,
        size = EsBtnSize.Lg,
        full = true,
        disabled = state.verifying || state.code.length != 6,
    )
    androidx.compose.foundation.layout.Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        TextButton(onClick = onEditNumber, enabled = !state.verifying && !state.resending) {
            Text("Edit number", color = SevaGreen700)
        }
        TextButton(onClick = onResend, enabled = !state.resending) {
            Text(if (state.resending) "Resending…" else "Resend code", color = SevaGreen700)
        }
    }
}
