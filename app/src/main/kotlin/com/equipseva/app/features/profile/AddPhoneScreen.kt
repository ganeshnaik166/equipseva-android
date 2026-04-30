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
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.profile.ProfileRepository
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.designsystem.components.EsBtn
import com.equipseva.app.designsystem.components.EsBtnKind
import com.equipseva.app.designsystem.components.EsBtnSize
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk900
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/**
 * Single-screen flow for an *already signed-in* user to attach (or change)
 * their phone number. v1 stores the number directly on `profiles.phone`
 * via [ProfileRepository.updateBasicInfo] — no SMS, no OTP, no
 * `auth.users.phone` involvement. Hospitals can still call/WhatsApp on
 * the saved number; verification was dropped because it added friction
 * for biomedical engineers in low-signal areas without buying us
 * meaningful trust signal in v1.
 *
 * Used from KYC Step 1 (engineer Contact card) and from the Profile
 * screen's "Add phone" banner.
 */
@HiltViewModel
class AddPhoneViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val profileRepository: ProfileRepository,
) : ViewModel() {

    data class UiState(
        val phone: String = "+91",
        val saving: Boolean = false,
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

    fun onSave() {
        val phone = _state.value.phone.trim()
        if (!phone.startsWith("+") || phone.length < 10) {
            _state.update { it.copy(error = "Enter the number in international format, e.g. +919999999999") }
            return
        }
        _state.update { it.copy(saving = true, error = null) }
        viewModelScope.launch {
            val session = authRepository.sessionState.first { it !is AuthSession.Unknown }
            val userId = (session as? AuthSession.SignedIn)?.userId
            if (userId == null) {
                _state.update { it.copy(saving = false, error = "Sign in again to save your phone.") }
                return@launch
            }
            profileRepository.updateBasicInfo(userId = userId, fullName = null, phone = phone)
                .onSuccess {
                    _state.update { it.copy(saving = false) }
                    _effects.send(Effect.ShowMessage("Phone saved"))
                    _effects.send(Effect.Done)
                }
                .onFailure { e ->
                    _state.update { it.copy(saving = false, error = e.toUserMessage()) }
                }
        }
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
                Text(
                    "Enter your mobile number",
                    fontSize = 22.sp,
                    fontWeight = FontWeight.Bold,
                    color = SevaInk900,
                )
                Text(
                    "Hospitals will Call and WhatsApp you on this number once you're listed in their directory.",
                    fontSize = 13.sp,
                    color = SevaInk500,
                )
                OutlinedTextField(
                    value = state.phone,
                    onValueChange = viewModel::onPhoneChange,
                    label = { Text("Phone (e.g. +919999999999)") },
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone),
                    isError = state.error != null,
                    supportingText = state.error?.let { { Text(it) } },
                    enabled = !state.saving,
                    modifier = Modifier.fillMaxWidth(),
                )
                Spacer(Modifier.height(8.dp))
                EsBtn(
                    text = if (state.saving) "Saving…" else "Save",
                    onClick = viewModel::onSave,
                    kind = EsBtnKind.Primary,
                    size = EsBtnSize.Lg,
                    full = true,
                    disabled = state.saving || state.phone.length < 10,
                )
            }
        }
    }
}
