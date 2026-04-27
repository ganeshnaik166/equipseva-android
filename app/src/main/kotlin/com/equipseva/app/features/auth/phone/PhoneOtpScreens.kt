package com.equipseva.app.features.auth.phone

import androidx.compose.foundation.background
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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.PhoneAndroid
import androidx.compose.material.icons.outlined.Sms
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.data.prefs.UserPrefs
import com.equipseva.app.core.data.profile.ProfileRepository
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.designsystem.components.ESBackTopBar
import com.equipseva.app.designsystem.components.PrimaryButton
import com.equipseva.app.designsystem.theme.AccentLimeSoft
import com.equipseva.app.designsystem.theme.BrandGreen
import com.equipseva.app.designsystem.theme.BrandGreen50
import com.equipseva.app.designsystem.theme.BrandGreenDark
import com.equipseva.app.designsystem.theme.BrandGreenDeep
import com.equipseva.app.designsystem.theme.Ink500
import com.equipseva.app.designsystem.theme.Ink700
import com.equipseva.app.designsystem.theme.Ink900
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.designsystem.theme.Surface0
import com.equipseva.app.designsystem.theme.Surface200
import com.equipseva.app.navigation.Routes
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.firstOrNull
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/* ----------------------- Request screen ----------------------- */

@HiltViewModel
class PhoneOtpRequestViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val userPrefs: UserPrefs,
) : ViewModel() {
    data class UiState(
        val fullName: String = "",
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

    fun onFullNameChange(value: String) {
        _state.update { it.copy(fullName = value, error = null) }
    }

    fun onPhoneChange(value: String) {
        // Allow + then digits up to 15 chars (E.164 max).
        val cleaned = value.filterIndexed { i, c -> (i == 0 && c == '+') || c.isDigit() }.take(16)
        _state.update { it.copy(phone = cleaned, error = null) }
    }

    fun onSend() {
        val name = _state.value.fullName.trim()
        val phone = _state.value.phone.trim()
        if (name.length < 2) {
            _state.update { it.copy(error = "Enter your full name first.") }
            return
        }
        if (!phone.startsWith("+") || phone.length < 10) {
            _state.update { it.copy(error = "Enter phone in international format (e.g. +919999999999)") }
            return
        }
        _state.update { it.copy(sending = true, error = null) }
        viewModelScope.launch {
            // Stash the name so the Verify screen can write it to profiles
            // once the OTP succeeds. Doing this BEFORE sendPhoneOtp protects
            // us from process death between Send and Verify.
            userPrefs.setPendingFullName(name)
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
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .background(Surface0),
        ) {
            // Top accent strip — brand anchor.
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(6.dp)
                    .background(
                        Brush.horizontalGradient(
                            listOf(BrandGreenDeep, BrandGreen, BrandGreenDark),
                        ),
                    ),
            )

            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(horizontal = Spacing.xl, vertical = Spacing.xl),
                verticalArrangement = Arrangement.spacedBy(Spacing.md),
            ) {
                EyebrowRow(eyebrow = "PHONE OTP")

                Text(
                    "Enter your mobile number",
                    fontSize = 26.sp,
                    lineHeight = 32.sp,
                    fontWeight = FontWeight.Bold,
                    color = Ink900,
                    letterSpacing = (-0.4).sp,
                    modifier = Modifier.semantics { heading() },
                )
                Text(
                    "We'll send a 6-digit OTP by SMS to verify it's you.",
                    fontSize = 14.sp,
                    color = Ink700,
                )

                Spacer(Modifier.height(Spacing.xs))

                // Full name first — phone-OTP signup is the only path now,
                // and the profile row's full_name comes from this field. KYC
                // Step 1 hard-blocks on full_name being non-blank.
                OutlinedTextField(
                    value = state.fullName,
                    onValueChange = viewModel::onFullNameChange,
                    label = { Text("Full name") },
                    placeholder = { Text("As it should appear on your profile") },
                    singleLine = true,
                    enabled = !state.sending,
                    keyboardOptions = KeyboardOptions(
                        capitalization = androidx.compose.ui.text.input.KeyboardCapitalization.Words,
                        imeAction = ImeAction.Next,
                    ),
                    modifier = Modifier.fillMaxWidth(),
                )

                Spacer(Modifier.height(Spacing.xs))

                // Phone input — +91 prefix box + number field.
                PhoneInputRow(
                    phone = state.phone,
                    onChange = viewModel::onPhoneChange,
                    enabled = !state.sending,
                    isError = state.error != null,
                    errorText = state.error,
                    onDone = viewModel::onSend,
                )

                Spacer(Modifier.height(Spacing.sm))

                PrimaryButton(
                    label = if (state.sending) "Sending…" else "Send OTP",
                    onClick = viewModel::onSend,
                    enabled = !state.sending && state.phone.length >= 10 && state.fullName.trim().length >= 2,
                    loading = state.sending,
                )

                Spacer(Modifier.height(Spacing.md))

                WhyWeNeedThis()
            }
        }
    }
}

@Composable
private fun EyebrowRow(eyebrow: String) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
    ) {
        Box(
            modifier = Modifier
                .size(8.dp)
                .clip(CircleShape)
                .background(BrandGreen),
        )
        Text(
            text = eyebrow,
            fontSize = 11.sp,
            fontWeight = FontWeight.Black,
            letterSpacing = 1.2.sp,
            color = Ink500,
        )
    }
}

@Composable
private fun PhoneInputRow(
    phone: String,
    onChange: (String) -> Unit,
    enabled: Boolean,
    isError: Boolean,
    errorText: String?,
    onDone: () -> Unit,
) {
    // Strip leading "+91" for display in the input — keep the prefix as a static badge.
    val nationalPart = phone.removePrefix("+91").removePrefix("+").let {
        // If user typed a different country code, fall back to raw value.
        if (phone.startsWith("+91")) it else phone
    }
    Column(verticalArrangement = Arrangement.spacedBy(Spacing.xs)) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
        ) {
            // +91 prefix pill.
            Box(
                modifier = Modifier
                    .height(56.dp)
                    .clip(RoundedCornerShape(14.dp))
                    .background(BrandGreen50)
                    .padding(horizontal = Spacing.md),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = "+91",
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Bold,
                    color = BrandGreenDark,
                    letterSpacing = 0.5.sp,
                )
            }
            OutlinedTextField(
                value = nationalPart,
                onValueChange = { raw ->
                    val digits = raw.filter { it.isDigit() }.take(10)
                    onChange("+91$digits")
                },
                modifier = Modifier
                    .weight(1f)
                    .height(56.dp),
                label = { Text("Mobile number") },
                placeholder = { Text("9876543210") },
                singleLine = true,
                keyboardOptions = KeyboardOptions(
                    keyboardType = KeyboardType.Phone,
                    imeAction = ImeAction.Done,
                ),
                keyboardActions = KeyboardActions(onDone = { onDone() }),
                isError = isError,
                enabled = enabled,
                textStyle = TextStyle(fontSize = 18.sp, letterSpacing = 1.sp),
            )
        }
        if (isError && !errorText.isNullOrBlank()) {
            Text(
                text = errorText,
                fontSize = 12.sp,
                color = androidx.compose.material3.MaterialTheme.colorScheme.error,
            )
        }
    }
}

@Composable
private fun WhyWeNeedThis() {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(AccentLimeSoft)
            .padding(Spacing.md),
        verticalArrangement = Arrangement.spacedBy(Spacing.sm),
    ) {
        Text(
            text = "WHY WE NEED THIS",
            fontSize = 10.sp,
            fontWeight = FontWeight.Black,
            letterSpacing = 0.8.sp,
            color = BrandGreenDeep,
        )
        Text(
            text = "So hospitals can call + WhatsApp you to coordinate visits and confirm fixes.",
            fontSize = 13.sp,
            fontWeight = FontWeight.Medium,
            color = BrandGreenDeep,
            lineHeight = 18.sp,
        )
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(Spacing.md),
        ) {
            BadgeWith(icon = Icons.Outlined.Sms, label = "SMS OTP")
            BadgeWith(icon = Icons.Outlined.PhoneAndroid, label = "WhatsApp ready")
        }
    }
}

@Composable
private fun BadgeWith(icon: androidx.compose.ui.graphics.vector.ImageVector, label: String) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = BrandGreenDeep,
            modifier = Modifier.size(14.dp),
        )
        Text(
            text = label,
            fontSize = 11.sp,
            fontWeight = FontWeight.SemiBold,
            color = BrandGreenDeep,
        )
    }
}

/* ----------------------- Verify screen ----------------------- */

@HiltViewModel
class PhoneOtpVerifyViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val authRepository: AuthRepository,
    private val profileRepository: ProfileRepository,
    private val userPrefs: UserPrefs,
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
                    persistPendingName(phone)
                    _state.update { it.copy(verifying = false, success = true) }
                }
                .onFailure { e ->
                    _state.update { it.copy(verifying = false, error = e.toUserMessage()) }
                }
        }
    }

    /**
     * Reads the name typed on the Request screen out of UserPrefs and writes
     * it into `profiles.full_name`. Best-effort: failure here doesn't block
     * the success path — the user can still edit their name from Profile
     * later. We always clear the prefs key so a stale name can't leak into a
     * subsequent signup.
     */
    private suspend fun persistPendingName(phone: String) {
        val pending = userPrefs.getPendingFullName()?.trim().orEmpty()
        userPrefs.clearPendingFullName()
        if (pending.length < 2) return
        // Wait briefly for the auth session to surface the new userId before
        // calling profile-update. The session flow flips on the same coroutine
        // thread the verify call returned on, so the next tick is enough.
        val session = authRepository.sessionState
        val signedIn = session
            .firstOrNull { it is com.equipseva.app.core.auth.AuthSession.SignedIn }
                as? com.equipseva.app.core.auth.AuthSession.SignedIn
            ?: return
        profileRepository.updateBasicInfo(signedIn.userId, pending, phone)
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
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .background(Surface0),
        ) {
            // Top accent strip — brand anchor.
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(6.dp)
                    .background(
                        Brush.horizontalGradient(
                            listOf(BrandGreenDeep, BrandGreen, BrandGreenDark),
                        ),
                    ),
            )

            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(horizontal = Spacing.xl, vertical = Spacing.xl),
                verticalArrangement = Arrangement.spacedBy(Spacing.md),
            ) {
                EyebrowRow(eyebrow = "VERIFY OTP")

                Text(
                    "Enter the 6-digit code",
                    fontSize = 26.sp,
                    lineHeight = 32.sp,
                    fontWeight = FontWeight.Bold,
                    color = Ink900,
                    letterSpacing = (-0.4).sp,
                    modifier = Modifier.semantics { heading() },
                )

                // "Sent to <phone>" pill — large and friendly.
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(16.dp))
                        .background(BrandGreen50)
                        .padding(horizontal = Spacing.md, vertical = Spacing.md),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
                ) {
                    Icon(
                        imageVector = Icons.Outlined.Sms,
                        contentDescription = null,
                        tint = BrandGreen,
                        modifier = Modifier.size(20.dp),
                    )
                    Text(
                        text = "Sent to ${state.phone}",
                        fontSize = 14.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = BrandGreenDeep,
                        modifier = Modifier.weight(1f),
                    )
                }

                Spacer(Modifier.height(Spacing.xs))

                // Big spaced numeric input.
                OutlinedTextField(
                    value = state.code,
                    onValueChange = viewModel::onCodeChange,
                    label = { Text("6-digit code") },
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(
                        keyboardType = KeyboardType.NumberPassword,
                        imeAction = ImeAction.Done,
                    ),
                    keyboardActions = KeyboardActions(onDone = { viewModel.onVerify() }),
                    isError = state.error != null,
                    supportingText = state.error?.let { { Text(it) } },
                    enabled = !state.verifying,
                    textStyle = TextStyle(
                        fontSize = 24.sp,
                        textAlign = TextAlign.Center,
                        letterSpacing = 8.sp,
                        fontWeight = FontWeight.Bold,
                    ),
                    modifier = Modifier.fillMaxWidth(),
                )

                Spacer(Modifier.height(Spacing.sm))

                PrimaryButton(
                    label = if (state.verifying) "Verifying…" else "Verify",
                    onClick = viewModel::onVerify,
                    enabled = !state.verifying && state.code.length == 6,
                    loading = state.verifying,
                )

                Box(
                    modifier = Modifier.fillMaxWidth(),
                    contentAlignment = Alignment.Center,
                ) {
                    TextButton(
                        onClick = viewModel::onResend,
                        enabled = !state.resending,
                    ) {
                        Text(
                            text = if (state.resending) "Resending…" else "Resend code",
                            fontSize = 13.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = if (state.resending) Ink500 else BrandGreen,
                        )
                    }
                }

                Text(
                    text = "Didn't get it? Check signal, then tap Resend.",
                    fontSize = 12.sp,
                    color = Ink700,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        }
    }
}

// Keep these imports used to avoid lint complaints across both screens.
@Suppress("unused")
private val ReservedSurface = Surface200
