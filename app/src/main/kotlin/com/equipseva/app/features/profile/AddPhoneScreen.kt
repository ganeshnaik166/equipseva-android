package com.equipseva.app.features.profile

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
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
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaDanger500
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaInk600
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

    val title = if (state.step == AddPhoneViewModel.Step.Request) "Add phone number" else "Verify"
    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Box(modifier = Modifier.fillMaxSize()) {
            Column(modifier = Modifier.fillMaxSize()) {
                EsTopBar(
                    title = title,
                    onBack = {
                        if (state.step == AddPhoneViewModel.Step.Verify) viewModel.onEditNumber() else onBack()
                    },
                )
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(16.dp)
                        .padding(bottom = 90.dp),
                ) {
                    when (state.step) {
                        AddPhoneViewModel.Step.Request -> RequestStep(
                            state = state,
                            onPhoneChange = viewModel::onPhoneChange,
                        )
                        AddPhoneViewModel.Step.Verify -> VerifyStep(
                            state = state,
                            onCodeChange = viewModel::onCodeChange,
                            onResend = viewModel::onResend,
                        )
                    }
                }
            }

            // Sticky-bottom CTA — primary action varies per step.
            Column(
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .fillMaxWidth()
                    .background(Color.White),
            ) {
                Box(modifier = Modifier.fillMaxWidth().height(1.dp).background(BorderDefault))
                Box(modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp)) {
                    when (state.step) {
                        AddPhoneViewModel.Step.Request -> EsBtn(
                            text = if (state.sending) "Sending…" else "Send code",
                            onClick = viewModel::onSendCode,
                            kind = EsBtnKind.Primary,
                            size = EsBtnSize.Lg,
                            full = true,
                            disabled = state.sending || state.phone.length < 10,
                        )
                        AddPhoneViewModel.Step.Verify -> EsBtn(
                            text = if (state.verifying) "Verifying…" else "Verify",
                            onClick = viewModel::onVerify,
                            kind = EsBtnKind.Primary,
                            size = EsBtnSize.Lg,
                            full = true,
                            disabled = state.verifying || state.code.length != 6,
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun RequestStep(
    state: AddPhoneViewModel.UiState,
    onPhoneChange: (String) -> Unit,
) {
    Text(
        "Used by hospitals to call or WhatsApp you about jobs.",
        fontSize = 13.sp,
        color = SevaInk600,
    )
    Spacer(Modifier.height(16.dp))
    OutlinedTextField(
        value = state.phone,
        onValueChange = onPhoneChange,
        label = { Text("Phone (e.g. +919999999999)") },
        singleLine = true,
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone),
        isError = state.error != null,
        supportingText = state.error?.let { { Text(it, color = SevaDanger500) } },
        enabled = !state.sending,
        shape = RoundedCornerShape(10.dp),
        colors = OutlinedTextFieldDefaults.colors(
            focusedBorderColor = SevaGreen700,
            errorBorderColor = SevaDanger500,
        ),
        modifier = Modifier.fillMaxWidth(),
    )
}

@Composable
private fun VerifyStep(
    state: AddPhoneViewModel.UiState,
    onCodeChange: (String) -> Unit,
    onResend: () -> Unit,
) {
    Text("Enter the 6-digit code sent to", fontSize = 13.sp, color = SevaInk600)
    Spacer(Modifier.height(4.dp))
    Text(state.phone, fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = SevaInk900)
    Spacer(Modifier.height(24.dp))
    OtpBoxes(value = state.code, onChange = onCodeChange, enabled = !state.verifying)
    if (state.error != null) {
        Spacer(Modifier.height(8.dp))
        Text(state.error, fontSize = 12.sp, color = SevaDanger500)
    }
    Spacer(Modifier.height(16.dp))
    // "Resend" link — green-700 12sp/600 per spec.
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(6.dp))
            .clickable(enabled = !state.resending, onClick = onResend)
            .padding(vertical = 4.dp),
    ) {
        Text(
            text = if (state.resending) "Resending…" else "Resend code",
            fontSize = 13.sp,
            fontWeight = FontWeight.SemiBold,
            color = SevaGreen700,
        )
    }
}

/**
 * 6 individual OTP boxes — 44×52 dp, 1.5dp border that flips green-700 when
 * filled. A single hidden BasicTextField underneath catches input + paste +
 * autofill so users don't have to focus each box separately.
 */
@Composable
private fun OtpBoxes(
    value: String,
    onChange: (String) -> Unit,
    enabled: Boolean,
) {
    Box(modifier = Modifier.fillMaxWidth()) {
        // Visible 6-box row.
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            repeat(6) { i ->
                val ch = value.getOrNull(i)?.toString().orEmpty()
                Box(
                    modifier = Modifier
                        .size(width = 44.dp, height = 52.dp)
                        .clip(RoundedCornerShape(10.dp))
                        .background(Color.White)
                        .border(
                            width = 1.5.dp,
                            color = if (ch.isNotEmpty()) SevaGreen700 else BorderDefault,
                            shape = RoundedCornerShape(10.dp),
                        ),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = ch,
                        fontSize = 20.sp,
                        fontWeight = FontWeight.Bold,
                        color = SevaInk900,
                        textAlign = TextAlign.Center,
                    )
                }
            }
        }
        // Transparent overlay BTF — captures keyboard input + paste / autofill.
        BasicTextField(
            value = value,
            onValueChange = { onChange(it.filter { c -> c.isDigit() }.take(6)) },
            enabled = enabled,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.NumberPassword),
            textStyle = TextStyle(color = Color.Transparent),
            cursorBrush = androidx.compose.ui.graphics.SolidColor(Color.Transparent),
            modifier = Modifier
                .matchParentSize(),
        )
    }
}
