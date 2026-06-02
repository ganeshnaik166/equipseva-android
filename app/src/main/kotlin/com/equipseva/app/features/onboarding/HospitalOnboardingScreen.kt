package com.equipseva.app.features.onboarding

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.location.IndiaLocations
import com.equipseva.app.core.data.profile.ProfileRepository
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.core.util.normalizeIndiaMobileInput
import com.equipseva.app.designsystem.components.EsBtn
import com.equipseva.app.designsystem.components.EsBtnKind
import com.equipseva.app.designsystem.components.EsBtnSize
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk900
import com.equipseva.app.features.profile.isPhoneE164Routable
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/**
 * v0.2.0 mandatory onboarding for hospital admins. Captures the three
 * fields the directory + matching can't operate without — phone (Exotel
 * call-masking), state, district — in one shot right after sign-up so
 * the user doesn't have to scavenge them out of Profile screens later.
 *
 * Soft-gated from HomeHub today: hospital users with
 * `Profile.hasCompletedV2Onboarding == false` are redirected here on
 * first arrival at HOME. A follow-up promotes the gate to the
 * SessionViewModel destination machine so they never see HOME flash.
 *
 * Persistence: a single `ProfileRepository.updateBasicInfo` call that
 * writes phone + state + district atomically. The server-side row CHECK
 * (round 419) caps state/district at 64 chars; we mirror that clamp at
 * the repo boundary so a stale UI state can never surface 23514.
 */
@HiltViewModel
class HospitalOnboardingViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val profileRepository: ProfileRepository,
) : ViewModel() {

    data class UiState(
        val phone: String = "+91",
        val state: String = "",
        val district: String = "",
        val districtOptions: List<String> = emptyList(),
        val saving: Boolean = false,
        val error: String? = null,
    ) {
        val canSubmit: Boolean
            get() = !saving &&
                isPhoneE164Routable(phone) &&
                state.isNotBlank() &&
                district.isNotBlank()
    }

    sealed interface Effect {
        data object Done : Effect
        data class ShowMessage(val text: String) : Effect
    }

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    private val _effects = MutableSharedFlow<Effect>(extraBufferCapacity = 4)
    val effects: kotlinx.coroutines.flow.Flow<Effect> = _effects

    fun onPhoneChange(value: String) {
        _state.update { it.copy(phone = normalizeIndiaMobileInput(value), error = null) }
    }

    fun onStateChange(value: String) {
        val districts = IndiaLocations.districtsFor(value)
        _state.update {
            it.copy(
                state = value,
                // Clear district whenever state changes — the previous
                // district may not exist in the new state's list, and
                // even if it happens to share a name (e.g. "Hyderabad"
                // exists nowhere else) re-picking is one tap.
                district = "",
                districtOptions = districts,
                error = null,
            )
        }
    }

    fun onDistrictChange(value: String) {
        _state.update { it.copy(district = value, error = null) }
    }

    fun onSubmit() {
        val s = _state.value
        if (!s.canSubmit) return
        _state.update { it.copy(saving = true, error = null) }
        viewModelScope.launch {
            val session = authRepository.sessionState.first { it !is AuthSession.Unknown }
            val userId = (session as? AuthSession.SignedIn)?.userId
            if (userId == null) {
                _state.update { it.copy(saving = false, error = "Sign in again to save.") }
                return@launch
            }
            profileRepository.updateBasicInfo(
                userId = userId,
                phone = s.phone.trim(),
                state = s.state.trim(),
                district = s.district.trim(),
            ).onSuccess {
                _state.update { it.copy(saving = false) }
                _effects.emit(Effect.ShowMessage("Saved"))
                _effects.emit(Effect.Done)
            }.onFailure { e ->
                _state.update { it.copy(saving = false, error = e.toUserMessage()) }
            }
        }
    }
}

@Composable
fun HospitalOnboardingScreen(
    onDone: () -> Unit,
    onShowMessage: (String) -> Unit,
    viewModel: HospitalOnboardingViewModel = hiltViewModel(),
) {
    val s by viewModel.state.collectAsStateWithLifecycle()

    LaunchedEffect(viewModel) {
        viewModel.effects.collect { e ->
            when (e) {
                is HospitalOnboardingViewModel.Effect.ShowMessage -> onShowMessage(e.text)
                HospitalOnboardingViewModel.Effect.Done -> onDone()
            }
        }
    }

    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp, vertical = 24.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Text(
                "Welcome to EquipSeva",
                fontSize = 28.sp,
                fontWeight = FontWeight.Bold,
                color = SevaInk900,
            )
            Text(
                "A few quick details so engineers can reach you and we can match jobs near you. " +
                    "You can change these anytime in Profile.",
                fontSize = 14.sp,
                color = SevaInk500,
            )
            Spacer(Modifier.height(4.dp))

            // Show the validation reason inline once the user has typed
            // enough that they're clearly past the +91 prefix — keeps the
            // "Continue" disabled state self-explanatory instead of an
            // unexplained grey button.
            val phoneInputError = s.phone.length >= 5 && !isPhoneE164Routable(s.phone)
            OutlinedTextField(
                value = s.phone,
                onValueChange = viewModel::onPhoneChange,
                label = { Text("Phone") },
                placeholder = { Text("+91 98765 43210") },
                supportingText = {
                    if (phoneInputError) {
                        Text(
                            "Enter a valid 10-digit Indian mobile number.",
                            color = androidx.compose.material3.MaterialTheme.colorScheme.error,
                        )
                    } else {
                        Text("We send job updates here. 10-digit Indian mobile.")
                    }
                },
                isError = phoneInputError,
                singleLine = true,
                enabled = !s.saving,
                keyboardOptions = KeyboardOptions(
                    keyboardType = KeyboardType.Phone,
                    imeAction = ImeAction.Next,
                ),
                modifier = Modifier.fillMaxWidth(),
            )

            OnboardingStateDropdown(
                value = s.state,
                enabled = !s.saving,
                onValueChange = viewModel::onStateChange,
            )

            OnboardingDistrictField(
                value = s.district,
                options = s.districtOptions,
                enabled = !s.saving && s.state.isNotBlank(),
                onValueChange = viewModel::onDistrictChange,
            )

            if (s.error != null) {
                Text(
                    s.error.orEmpty(),
                    color = androidx.compose.material3.MaterialTheme.colorScheme.error,
                    fontSize = 13.sp,
                )
            }

            Spacer(Modifier.height(12.dp))

            EsBtn(
                text = if (s.saving) "Saving…" else "Continue",
                onClick = viewModel::onSubmit,
                kind = EsBtnKind.Primary,
                size = EsBtnSize.Lg,
                full = true,
                disabled = !s.canSubmit,
            )
        }
    }
}

