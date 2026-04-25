package com.equipseva.app.features.auth.phone

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Button
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
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
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.designsystem.components.ESBackTopBar
import com.equipseva.app.designsystem.theme.Ink500
import com.equipseva.app.designsystem.theme.Ink900
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.navigation.Routes
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/* ----------------------- Request screen ----------------------- */

@HiltViewModel
class PhoneOtpRequestViewModel @Inject constructor(
    private val authRepository: AuthRepository,
) : ViewModel() {
    data class UiState(
        val phone: String = "+91",
        val sending: Boolean = false,
        val error: String? = null,
    )
    sealed interface Effect {
        data class NavigateToVerify(val phone: String) : Effect
    }
    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()
    private val _effects = Channel<Effect>(Channel.BUFFERED)
    val effects = _effects.receiveAsFlow()

    fun onPhoneChange(value: String) {
        // Allow + then digits up to 15 chars (E.164 max).
        val cleaned = value.filterIndexed { i, c -> (i == 0 && c == '+') || c.isDigit() }.take(16)
        _state.update { it.copy(phone = cleaned, error = null) }
    }

    fun onSend() {
        val phone = _state.value.phone.trim()
        if (!phone.startsWith("+") || phone.length < 10) {
            _state.update { it.copy(error = "Enter phone in international format (e.g. +919999999999)") }
            return
        }
        _state.update { it.copy(sending = true, error = null) }
        viewModelScope.launch {
            authRepository.sendPhoneOtp(phone)
                .onSuccess {
                    _state.update { it.copy(sending = false) }
                    _effects.send(Effect.NavigateToVerify(phone))
                }
                .onFailure { e ->
                    _state.update { it.copy(sending = false, error = e.toUserMessage()) }
                }
        }
    }
}

@Composable
fun PhoneOtpRequestScreen(
    onBack: () -> Unit,
    onNavigateToVerify: (phone: String) -> Unit,
    viewModel: PhoneOtpRequestViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsState()
    LaunchedEffect(viewModel) {
        viewModel.effects.collect { e ->
            when (e) {
                is PhoneOtpRequestViewModel.Effect.NavigateToVerify -> onNavigateToVerify(e.phone)
            }
        }
    }
    Scaffold(topBar = { ESBackTopBar(title = "Sign in with phone", onBack = onBack) }) { padding ->
        Box(modifier = Modifier.fillMaxSize().padding(padding)) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(Spacing.lg),
                verticalArrangement = Arrangement.spacedBy(Spacing.md),
            ) {
                Text(
                    "Enter your mobile number",
                    fontSize = 22.sp,
                    fontWeight = FontWeight.Bold,
                    color = Ink900,
                )
                Text(
                    "We'll send a 6-digit code by SMS. Country code (e.g. +91) is required.",
                    fontSize = 13.sp,
                    color = Ink500,
                )
                Spacer(Modifier.height(8.dp))
                OutlinedTextField(
                    value = state.phone,
                    onValueChange = viewModel::onPhoneChange,
                    label = { Text("Phone number") },
                    placeholder = { Text("+919999999999") },
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone),
                    isError = state.error != null,
                    supportingText = state.error?.let { { Text(it) } },
                    enabled = !state.sending,
                    modifier = Modifier.fillMaxWidth(),
                )
                Spacer(Modifier.height(8.dp))
                Button(
                    onClick = viewModel::onSend,
                    enabled = !state.sending && state.phone.length >= 10,
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text(if (state.sending) "Sending…" else "Send OTP")
                }
            }
        }
    }
}

/* ----------------------- Verify screen ----------------------- */

@HiltViewModel
class PhoneOtpVerifyViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val authRepository: AuthRepository,
) : ViewModel() {
    private val phone: String = java.net.URLDecoder.decode(
        requireNotNull(savedStateHandle[Routes.AUTH_PHONE_OTP_VERIFY_ARG_PHONE]) { "Missing phone arg" },
        Charsets.UTF_8.name(),
    )

    data class UiState(
        val phone: String,
        val code: String = "",
        val verifying: Boolean = false,
        val resending: Boolean = false,
        val error: String? = null,
        val success: Boolean = false,
    )
    private val _state = MutableStateFlow(UiState(phone = phone))
    val state: StateFlow<UiState> = _state.asStateFlow()

    fun onCodeChange(value: String) {
        val cleaned = value.filter { it.isDigit() }.take(6)
        _state.update { it.copy(code = cleaned, error = null) }
    }

    fun onVerify() {
        val code = _state.value.code
        if (code.length != 6) {
            _state.update { it.copy(error = "Enter the 6-digit code") }
            return
        }
        _state.update { it.copy(verifying = true, error = null) }
        viewModelScope.launch {
            authRepository.verifyPhoneOtp(phone, code)
                .onSuccess {
                    _state.update { it.copy(verifying = false, success = true) }
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
            authRepository.sendPhoneOtp(phone)
                .onFailure { e -> _state.update { it.copy(error = e.toUserMessage()) } }
            _state.update { it.copy(resending = false) }
        }
    }
}

@Composable
fun PhoneOtpVerifyScreen(
    onBack: () -> Unit,
    viewModel: PhoneOtpVerifyViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsState()
    Scaffold(topBar = { ESBackTopBar(title = "Verify code", onBack = onBack) }) { padding ->
        Box(modifier = Modifier.fillMaxSize().padding(padding)) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(Spacing.lg),
                verticalArrangement = Arrangement.spacedBy(Spacing.md),
            ) {
                Text(
                    "Enter the 6-digit code",
                    fontSize = 22.sp,
                    fontWeight = FontWeight.Bold,
                    color = Ink900,
                )
                Text(
                    "Sent to ${state.phone}",
                    fontSize = 13.sp,
                    color = Ink500,
                )
                Spacer(Modifier.height(8.dp))
                OutlinedTextField(
                    value = state.code,
                    onValueChange = viewModel::onCodeChange,
                    label = { Text("Code") },
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.NumberPassword),
                    isError = state.error != null,
                    supportingText = state.error?.let { { Text(it) } },
                    enabled = !state.verifying,
                    modifier = Modifier.fillMaxWidth(),
                )
                Spacer(Modifier.height(8.dp))
                Button(
                    onClick = viewModel::onVerify,
                    enabled = !state.verifying && state.code.length == 6,
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text(if (state.verifying) "Verifying…" else "Verify")
                }
                androidx.compose.material3.TextButton(
                    onClick = viewModel::onResend,
                    enabled = !state.resending,
                    modifier = Modifier.align(Alignment.CenterHorizontally),
                ) {
                    Text(if (state.resending) "Resending…" else "Resend code")
                }
            }
        }
    }
}
