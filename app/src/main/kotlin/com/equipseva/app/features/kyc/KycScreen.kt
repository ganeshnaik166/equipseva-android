package com.equipseva.app.features.kyc

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.selection.toggleable
import androidx.compose.ui.semantics.Role
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Badge
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.Error
import androidx.compose.material.icons.filled.HourglassTop
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Phone
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Verified
import androidx.compose.material.icons.filled.WorkspacePremium
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.core.data.engineers.VerificationStatus
import com.equipseva.app.core.util.MIME_JPEG
import com.equipseva.app.core.util.MIME_PDF
import com.equipseva.app.core.util.MIME_PNG
import com.equipseva.app.core.util.MIME_WEBP
import com.equipseva.app.designsystem.components.SecureScreen
import com.equipseva.app.designsystem.theme.BrandGreen
import com.equipseva.app.designsystem.theme.ErrorBg
import com.equipseva.app.designsystem.theme.ErrorRed
import com.equipseva.app.designsystem.theme.Info
import com.equipseva.app.designsystem.theme.InfoBg
import com.equipseva.app.designsystem.theme.Ink300
import com.equipseva.app.designsystem.theme.Ink500
import com.equipseva.app.designsystem.theme.Ink700
import com.equipseva.app.designsystem.theme.Ink900
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.designsystem.theme.Success
import com.equipseva.app.designsystem.theme.SuccessBg
import com.equipseva.app.designsystem.theme.SevaGreen50
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.Surface0
import com.equipseva.app.designsystem.theme.Surface50
import com.equipseva.app.designsystem.theme.Surface200
import com.equipseva.app.designsystem.theme.Warning
import com.equipseva.app.designsystem.theme.WarningBg
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.geometry.RoundRect
import androidx.compose.ui.graphics.Path

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun KycScreen(
    onBack: () -> Unit,
    onShowMessage: (String) -> Unit,
    onAddPhone: () -> Unit = {},
    onSubmitted: () -> Unit = {},
    viewModel: KycViewModel = hiltViewModel(),
) {
    SecureScreen()
    val state by viewModel.state.collectAsStateWithLifecycle()
    val context = LocalContext.current

    // Re-fetch profile on every ON_RESUME so changes made on Add Phone /
    // Change Email screens flow back into the KYC fields the moment the
    // user pops back. Without this the state stays at whatever was loaded
    // when KYC first composed.
    val lifecycleOwner = androidx.lifecycle.compose.LocalLifecycleOwner.current
    androidx.compose.runtime.DisposableEffect(lifecycleOwner) {
        val observer = androidx.lifecycle.LifecycleEventObserver { _, event ->
            if (event == androidx.lifecycle.Lifecycle.Event.ON_RESUME) {
                viewModel.refreshProfileFields()
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    LaunchedEffect(viewModel) {
        viewModel.effects.collect { effect ->
            when (effect) {
                is KycViewModel.Effect.ShowMessage -> onShowMessage(effect.text)
                KycViewModel.Effect.Submitted -> onSubmitted()
            }
        }
    }

    // OpenDocument (not PickVisualMedia) so e-Aadhaar PDFs from UIDAI work too.
    val aadhaarPicker = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.OpenDocument(),
    ) { uri: Uri? ->
        uri?.let {
            readAndUpload(
                context, it,
                send = { name, bytes, mime -> viewModel.uploadAadhaarDoc(name, bytes, mime) },
                onError = viewModel::reportUploadError,
            )
        }
    }

    val certPicker = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.OpenDocument(),
    ) { uri: Uri? ->
        uri?.let {
            readAndUpload(
                context, it,
                send = { name, bytes, mime -> viewModel.uploadCertificate(name, bytes, mime) },
                onError = viewModel::reportUploadError,
            )
        }
    }

    val panPicker = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.OpenDocument(),
    ) { uri: Uri? ->
        uri?.let {
            readAndUpload(
                context, it,
                send = { name, bytes, mime -> viewModel.uploadPan(name, bytes, mime) },
                onError = viewModel::reportUploadError,
            )
        }
    }

    Scaffold(
        topBar = {
            // Verified engineers see a "Verified" subtitle instead of the
            // wizard counter — the wizard isn't visible to them so showing
            // "Step 1 of 2" alongside a fully-checked status stepper read
            // as a contradiction.
            val subtitle = if (state.verificationStatus == VerificationStatus.Verified) {
                "Verified"
            } else {
                "Step ${state.currentStep.ordinal + 1} of ${com.equipseva.app.features.kyc.KycStep.entries.size}"
            }
            com.equipseva.app.designsystem.components.EsTopBar(
                title = "Verification (KYC)",
                subtitle = subtitle,
                onBack = onBack,
            )
        },
        bottomBar = {
            // Verified engineers don't need a footer — there's nothing to do.
            if (state.verificationStatus != VerificationStatus.Verified) {
                StepperBottomBar(
                    state = state,
                    onPrevious = viewModel::goToPreviousStep,
                    onNext = viewModel::goToNextStep,
                    onSubmit = viewModel::save,
                )
            }
        },
        containerColor = com.equipseva.app.designsystem.theme.PaperDefault,
    ) { inner ->
        Box(modifier = Modifier.fillMaxSize().padding(inner)) {
            when {
                state.loading -> {
                    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator()
                    }
                }
                state.errorMessage != null -> {
                    Column(
                        modifier = Modifier.fillMaxSize().padding(Spacing.lg),
                        verticalArrangement = Arrangement.spacedBy(Spacing.md, Alignment.CenterVertically),
                        horizontalAlignment = Alignment.CenterHorizontally,
                    ) {
                        Text(state.errorMessage!!, style = MaterialTheme.typography.bodyLarge)
                        Button(onClick = viewModel::retry) { Text("Retry") }
                    }
                }
                else -> KycStepperBody(
                    state = state,
                    onAadhaarNumberChange = viewModel::onAadhaarNumberChange,
                    onPanNumberChange = viewModel::onPanNumberChange,
                    onServiceAddressChange = viewModel::onServiceAddressChange,
                    onServiceStateChange = viewModel::onServiceStateChange,
                    onServiceDistrictChange = viewModel::onServiceDistrictChange,
                    onAttestationChange = viewModel::onAttestationChange,
                    onPickAadhaar = {
                        aadhaarPicker.launch(
                            arrayOf(MIME_PDF, MIME_JPEG, MIME_PNG, MIME_WEBP),
                        )
                    },
                    onPickPan = {
                        panPicker.launch(
                            arrayOf(MIME_PDF, MIME_JPEG, MIME_PNG, MIME_WEBP),
                        )
                    },
                    onPickCertificate = {
                        certPicker.launch(arrayOf(MIME_PDF, MIME_JPEG, MIME_PNG, MIME_WEBP))
                    },
                    onStartReupload = viewModel::startReupload,
                    onEmailDraftChange = viewModel::onEmailDraftChange,
                    onSaveEmail = viewModel::saveEmailDraft,
                    onAddPhone = onAddPhone,
                    onVerifyEmail = viewModel::startEmailVerification,
                )
            }
        }
    }

    if (state.emailVerifySheetOpen) {
        EmailVerifySheet(
            email = state.email.orEmpty(),
            code = state.emailOtpCode,
            sending = state.sendingEmailOtp,
            verifying = state.verifyingEmailOtp,
            onCodeChange = viewModel::onEmailOtpChange,
            onSubmit = viewModel::submitEmailOtp,
            onDismiss = viewModel::closeEmailVerifySheet,
            onResend = viewModel::startEmailVerification,
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun EmailVerifySheet(
    email: String,
    code: String,
    sending: Boolean,
    verifying: Boolean,
    onCodeChange: (String) -> Unit,
    onSubmit: () -> Unit,
    onDismiss: () -> Unit,
    onResend: () -> Unit,
) {
    val sheetState = androidx.compose.material3.rememberModalBottomSheetState(skipPartiallyExpanded = true)
    androidx.compose.material3.ModalBottomSheet(
        onDismissRequest = { if (!verifying) onDismiss() },
        sheetState = sheetState,
    ) {
        // Round 454 — imePadding lifts the OTP field above the IME so
        // the user can see what they're typing. ModalBottomSheet handles
        // safe-content (nav-bar) insets but does not push above the
        // soft keyboard on its own.
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .imePadding()
                .padding(horizontal = Spacing.lg, vertical = Spacing.md),
            verticalArrangement = Arrangement.spacedBy(Spacing.md),
        ) {
            Text("Verify your email", fontWeight = FontWeight.Bold, fontSize = 18.sp, color = Ink900)
            Text("Code sent to $email", fontSize = 13.sp, color = Ink500)
            OutlinedTextField(
                value = code,
                onValueChange = onCodeChange,
                label = { Text("6-digit code") },
                singleLine = true,
                keyboardOptions = KeyboardOptions(
                    keyboardType = KeyboardType.NumberPassword,
                    // Round 464 — Done lets the user submit the 6-digit
                    // OTP from the keyboard once it's complete, instead
                    // of having to dismiss the keyboard first and then
                    // reach for the Verify button.
                    imeAction = ImeAction.Done,
                ),
                keyboardActions = KeyboardActions(
                    onDone = { if (!verifying && code.length == 6) onSubmit() },
                ),
                enabled = !verifying,
                supportingText = if (sending) {
                    { Text("Sending code…", fontSize = 12.sp, color = Ink500) }
                } else null,
                modifier = Modifier.fillMaxWidth(),
            )
            Row(horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
                OutlinedButton(
                    onClick = onResend,
                    enabled = !sending && !verifying,
                    modifier = Modifier.weight(1f),
                ) { Text(if (sending) "Resending…" else "Resend code") }
                Button(
                    onClick = onSubmit,
                    enabled = !verifying && code.length == 6,
                    modifier = Modifier.weight(1.4f),
                ) {
                    if (verifying) {
                        CircularProgressIndicator(
                            modifier = Modifier.size(18.dp),
                            strokeWidth = 2.dp,
                            color = MaterialTheme.colorScheme.onPrimary,
                        )
                        Spacer(Modifier.size(Spacing.sm))
                        Text("Verifying…")
                    } else {
                        Text("Verify")
                    }
                }
            }
            Spacer(Modifier.height(Spacing.sm))
        }
    }
}

@Composable
private fun KycStepperBody(
    state: KycViewModel.UiState,
    onAadhaarNumberChange: (String) -> Unit,
    onPanNumberChange: (String) -> Unit,
    onServiceAddressChange: (String) -> Unit,
    onServiceStateChange: (String) -> Unit,
    onServiceDistrictChange: (String) -> Unit,
    onAttestationChange: (Boolean) -> Unit,
    onPickAadhaar: () -> Unit,
    onPickPan: () -> Unit,
    onPickCertificate: () -> Unit,
    onStartReupload: () -> Unit,
    onEmailDraftChange: (String) -> Unit,
    onSaveEmail: () -> Unit,
    onAddPhone: () -> Unit,
    onVerifyEmail: () -> Unit,
) {
    val verified = state.verificationStatus == VerificationStatus.Verified
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(Spacing.lg),
        verticalArrangement = Arrangement.spacedBy(Spacing.lg),
    ) {
        // Reuse the existing 3-step compact timeline (submitted → review →
        // verified) as a high-level status header above the wizard.
        KycStatusTimeline(
            status = state.verificationStatus,
            submitted = state.kycSubmitted,
        )

        StatusBanner(status = state.verificationStatus, submitted = state.kycSubmitted)

        if (verified) {
            // Verified engineers see a celebratory summary instead of the wizard.
            VerifiedSummaryCard(state = state)
            return@Column
        }

        if (state.verificationStatus == VerificationStatus.Rejected) {
            ReuploadCta(
                notes = state.verificationNotes,
                rejectedDocTypes = state.rejectedDocTypes,
                onClick = onStartReupload,
            )
        }

        // Step intro: matches design — short title ("Personal" / "Documents")
        // + small caption. The numeric "Step X of Y" lives in the top bar.
        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                text = state.currentStep.title,
                fontSize = 18.sp,
                color = Ink900,
                fontWeight = FontWeight.Bold,
            )
            Text(
                text = when (state.currentStep) {
                    KycStep.Personal -> "How hospitals reach you and where you operate."
                    KycStep.Documents -> "Upload identity and qualification proof."
                },
                fontSize = 12.sp,
                color = Ink500,
            )
        }

        // Per-step body. Each step renders only what's relevant to that step
        // so the form feels short — best-practice gig-app onboarding caps each
        // step at ~30 seconds of input.
        when (state.currentStep) {
            KycStep.Personal -> PersonalStep(
                state = state,
                onServiceAddressChange = onServiceAddressChange,
                onServiceStateChange = onServiceStateChange,
                onServiceDistrictChange = onServiceDistrictChange,
                onEmailDraftChange = onEmailDraftChange,
                onSaveEmail = onSaveEmail,
                onAddPhone = onAddPhone,
                onVerifyEmail = onVerifyEmail,
            )
            KycStep.Documents -> DocumentsStep(
                state = state,
                onAadhaarNumberChange = onAadhaarNumberChange,
                onPanNumberChange = onPanNumberChange,
                onPickAadhaar = onPickAadhaar,
                onPickPan = onPickPan,
                onPickCertificate = onPickCertificate,
                onAttestationChange = onAttestationChange,
            )
        }

        // Inline error chip that mirrors the disabled-Next reason. Lets the
        // user know exactly what's missing without staring at a dead button.
        state.stepError()?.let { msg ->
            InlineError(text = msg)
        }

        Spacer(Modifier.height(Spacing.sm))
    }
}

@Composable
private fun PersonalStep(
    state: KycViewModel.UiState,
    onServiceAddressChange: (String) -> Unit,
    onServiceStateChange: (String) -> Unit,
    onServiceDistrictChange: (String) -> Unit,
    onEmailDraftChange: (String) -> Unit,
    onSaveEmail: () -> Unit,
    onAddPhone: () -> Unit,
    onVerifyEmail: () -> Unit,
) {
    KycSectionCard(title = "How hospitals reach you") {
        // Full name — label above, read-only field with the user's saved name.
        // Use disabled colors that keep the value ink-black per design.
        val readOnlyColors = androidx.compose.material3.OutlinedTextFieldDefaults.colors(
            disabledTextColor = Ink900,
            disabledBorderColor = Surface200,
            disabledContainerColor = Color.White,
            disabledPlaceholderColor = Ink500,
        )
        FieldLabel("Full name")
        OutlinedTextField(
            value = state.fullName ?: "",
            onValueChange = {},
            enabled = false,
            singleLine = true,
            colors = readOnlyColors,
            modifier = Modifier.fillMaxWidth(),
        )

        // Email — inline edit. Trailing "Verified" pill once it matches the
        // saved address; "Save" text-button while the draft diverges. No OTP
        // step in v1 since the user signed in with this address.
        FieldLabel("Email")
        val emailChanged = state.emailDraft.isNotBlank() &&
            !state.emailDraft.equals(state.email, ignoreCase = true)
        OutlinedTextField(
            value = state.emailDraft,
            onValueChange = onEmailDraftChange,
            singleLine = true,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email),
            enabled = !state.savingEmail,
            trailingIcon = {
                if (emailChanged) {
                    androidx.compose.material3.TextButton(
                        onClick = onSaveEmail,
                        enabled = !state.savingEmail,
                        modifier = Modifier.padding(end = 6.dp),
                    ) {
                        Text(
                            text = if (state.savingEmail) "Saving…" else "Save",
                            color = SevaGreen700,
                            fontSize = 13.sp,
                            fontWeight = FontWeight.SemiBold,
                        )
                    }
                } else if (!state.email.isNullOrBlank() && state.emailVerified) {
                    // Pill must mirror the actual emailVerified flag, not
                    // just "email field has a value". Earlier code painted
                    // every saved email as "Verified" before the user
                    // tapped the OTP link.
                    Box(
                        modifier = Modifier
                            .padding(end = 8.dp)
                            .clip(RoundedCornerShape(999.dp))
                            .background(SevaGreen50)
                            .padding(horizontal = 10.dp, vertical = 4.dp),
                    ) {
                        Text(
                            text = "Verified",
                            color = SevaGreen700,
                            fontSize = 11.sp,
                            fontWeight = FontWeight.SemiBold,
                        )
                    }
                } else if (!state.email.isNullOrBlank()) {
                    androidx.compose.material3.TextButton(
                        onClick = onVerifyEmail,
                        enabled = !state.sendingEmailOtp,
                        modifier = Modifier.padding(end = 6.dp),
                    ) {
                        Text(
                            text = if (state.sendingEmailOtp) "Sending…" else "Verify",
                            color = SevaGreen700,
                            fontSize = 13.sp,
                            fontWeight = FontWeight.SemiBold,
                        )
                    }
                }
            },
            modifier = Modifier.fillMaxWidth(),
        )

        // Phone — direct save flow, no OTP. Add when blank, "Saved" pill
        // when set (was "Verified" but we don't actually run an OTP
        // round-trip — calling it Verified would lie). Hint copy below
        // from screens-kyc.jsx.
        FieldLabel("Phone (for hospital contact)")
        // readOnly (not enabled=false) so the trailing TextButton stays
        // clickable. Material 3 treats `enabled=false` as "everything inside
        // this field is non-interactive", which would have eaten the Add tap.
        val phoneReadOnlyColors = androidx.compose.material3.OutlinedTextFieldDefaults.colors(
            unfocusedTextColor = Ink900,
            focusedTextColor = Ink900,
            unfocusedBorderColor = Surface200,
            focusedBorderColor = Surface200,
            unfocusedContainerColor = Color.White,
            focusedContainerColor = Color.White,
        )
        OutlinedTextField(
            value = state.phone ?: "",
            onValueChange = {},
            readOnly = true,
            singleLine = true,
            colors = phoneReadOnlyColors,
            placeholder = { Text("+91 98765 43210", color = Ink500) },
            trailingIcon = {
                if (state.phone.isNullOrBlank()) {
                    androidx.compose.material3.TextButton(
                        onClick = onAddPhone,
                        modifier = Modifier.padding(end = 6.dp),
                    ) {
                        Text(
                            text = "Add",
                            color = SevaGreen700,
                            fontSize = 13.sp,
                            fontWeight = FontWeight.SemiBold,
                        )
                    }
                } else {
                    Box(
                        modifier = Modifier
                            .padding(end = 8.dp)
                            .clip(RoundedCornerShape(999.dp))
                            .background(SevaGreen50)
                            .padding(horizontal = 10.dp, vertical = 4.dp),
                    ) {
                        Text(
                            // Phone is saved via direct write — no OTP
                            // round-trip — so don't paint it "Verified".
                            // Email above DOES go through Supabase email
                            // OTP and keeps the Verified pill.
                            text = "Saved",
                            color = SevaGreen700,
                            fontSize = 11.sp,
                            fontWeight = FontWeight.SemiBold,
                        )
                    }
                }
            },
            modifier = Modifier.fillMaxWidth(),
        )
        Text(
            // "WhatsApp" was misleading — there's no in-app WhatsApp
            // bridge, and calling out a third-party app implies hospitals
            // will message you direct (anti-leak hole). Calls go through
            // EquipSeva's masked-line bridge; chat lives in the app.
            text = "Used to coordinate active jobs. Not for login.",
            fontSize = 11.sp,
            color = Ink500,
        )
    }
    KycSectionCard(title = "Where you operate") {
        // State + district only. v1 simplified the service-area capture to
        // just two dropdowns — the free-form address text field + draggable
        // map pin were dropped because most engineers were leaving them
        // blank and hospitals only ever filtered by district anyway.
        val districts = remember(state.serviceState) {
            com.equipseva.app.core.data.location.IndiaLocations.districtsFor(state.serviceState)
        }
        FieldLabel("State")
        com.equipseva.app.designsystem.components.EsDropdown(
            value = state.serviceState,
            onValueChange = onServiceStateChange,
            options = com.equipseva.app.core.data.location.IndiaLocations.STATES,
            placeholder = "Select state",
            modifier = Modifier.fillMaxWidth(),
        )
        FieldLabel("District")
        com.equipseva.app.designsystem.components.EsDropdown(
            value = state.serviceDistrict,
            onValueChange = onServiceDistrictChange,
            options = districts,
            placeholder = if (state.serviceState.isNullOrBlank()) "Pick state first" else "Select district",
            enabled = !state.serviceState.isNullOrBlank() && districts.isNotEmpty(),
            modifier = Modifier.fillMaxWidth(),
        )
    }
}

/**
 * Step 2 — Aadhaar (number + doc), PAN (number + doc), trade certificate
 * (PDF/photo), and the attestation checkbox. Submit fires from the bottom
 * bar once all step-error guards pass. Selfie was dropped in v2.
 */
@Composable
private fun DocumentsStep(
    state: KycViewModel.UiState,
    onAadhaarNumberChange: (String) -> Unit,
    onPanNumberChange: (String) -> Unit,
    onPickAadhaar: () -> Unit,
    onPickPan: () -> Unit,
    onPickCertificate: () -> Unit,
    onAttestationChange: (Boolean) -> Unit,
) {
    AadhaarSection(state = state, onAadhaarNumberChange = onAadhaarNumberChange, onPickAadhaar = onPickAadhaar)
    PanSection(state = state, onPanNumberChange = onPanNumberChange, onPickPan = onPickPan)
    CertificateSection(state = state, onPickCertificate = onPickCertificate)
    AttestationSection(state = state, onAttestationChange = onAttestationChange)
}

@Composable
private fun AadhaarSection(
    state: KycViewModel.UiState,
    onAadhaarNumberChange: (String) -> Unit,
    onPickAadhaar: () -> Unit,
) {
    val aadhaarUploaded = !state.aadhaarDocPath.isNullOrBlank()
    val digits = state.aadhaarNumber
    val checksumOk = digits.length == 12 && AadhaarValidator.isValid(digits)
    val hint = aadhaarNumberHint(digits, checksumOk)
    val hintColor = when {
        digits.isEmpty() -> Ink500
        checksumOk -> Success
        digits.length < 12 -> Ink500
        else -> ErrorRed
    }
    KycSectionCard(title = "Aadhaar") {
        OutlinedTextField(
            value = digits,
            onValueChange = onAadhaarNumberChange,
            label = { Text("12-digit Aadhaar") },
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.NumberPassword),
            singleLine = true,
            isError = digits.length == 12 && !checksumOk,
            supportingText = { Text(hint, color = hintColor, fontSize = 12.sp) },
            modifier = Modifier.fillMaxWidth(),
        )
        DocumentRow(
            title = "Aadhaar card",
            uploaded = aadhaarUploaded,
            uploading = state.uploadingAadhaar,
            failed = state.aadhaarFailed,
            icon = Icons.Filled.Badge,
            hue = 150,
            subtitleOverride = if (!aadhaarUploaded && !state.aadhaarFailed) "PDF or photo" else null,
            onClick = onPickAadhaar,
        )
    }
}

@Composable
private fun PanSection(
    state: KycViewModel.UiState,
    onPanNumberChange: (String) -> Unit,
    onPickPan: () -> Unit,
) {
    val panUploaded = !state.panDocPath.isNullOrBlank()
    val pan = state.panNumber
    val panOk = pan.length == 10 && PanValidator.isValid(pan)
    val panHint = panNumberHint(pan, panOk)
    val panHintColor = when {
        pan.isEmpty() -> Ink500
        panOk -> Success
        pan.length < 10 -> Ink500
        else -> ErrorRed
    }
    KycSectionCard(title = "PAN card") {
        OutlinedTextField(
            value = pan,
            onValueChange = onPanNumberChange,
            label = { Text("PAN number") },
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Text),
            singleLine = true,
            isError = pan.length == 10 && !panOk,
            supportingText = { Text(panHint, color = panHintColor, fontSize = 12.sp) },
            modifier = Modifier.fillMaxWidth(),
        )
        DocumentRow(
            title = "PAN card",
            uploaded = panUploaded,
            uploading = state.uploadingPan,
            failed = state.panFailed,
            icon = Icons.Filled.Description,
            hue = 220,
            subtitleOverride = if (!panUploaded && !state.panFailed) "PDF or photo" else null,
            onClick = onPickPan,
        )
    }
}

@Composable
private fun CertificateSection(state: KycViewModel.UiState, onPickCertificate: () -> Unit) {
    val certUploaded = state.certDocPaths.isNotEmpty()
    KycSectionCard(title = "Trade or qualification certificate") {
        DocumentRow(
            title = "Certificate",
            uploaded = certUploaded,
            uploading = state.uploadingCert,
            failed = state.certFailed,
            icon = Icons.Filled.WorkspacePremium,
            hue = 280,
            subtitleOverride = if (certUploaded) "Uploaded (${state.certDocPaths.size})" else null,
            onClick = onPickCertificate,
        )
        Text(
            text = "Upload your degree, diploma or trade certificate. You can add more after submitting.",
            fontSize = 11.sp,
            color = Ink500,
        )
    }
}

@Composable
private fun AttestationSection(state: KycViewModel.UiState, onAttestationChange: (Boolean) -> Unit) {
    val checked = state.attestationAccepted
    Row(
        // Round 411 — toggleable instead of clickable gives the row
        // Role.Checkbox + onValueChange semantics so TalkBack announces
        // "Checkbox, checked/unchecked" instead of "Button" — which
        // matters because this attestation is the gate for a high-stakes
        // submission (KYC + bank details).
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(Surface0)
            .border(1.dp, Surface200, RoundedCornerShape(10.dp))
            .toggleable(
                value = checked,
                onValueChange = onAttestationChange,
                role = Role.Checkbox,
            )
            .padding(12.dp),
        horizontalArrangement = Arrangement.spacedBy(10.dp),
        verticalAlignment = Alignment.Top,
    ) {
        Box(
            modifier = Modifier
                .size(22.dp)
                .clip(RoundedCornerShape(6.dp))
                .background(if (checked) SevaGreen700 else Color.White)
                .border(
                    width = 2.dp,
                    color = if (checked) SevaGreen700 else Ink300,
                    shape = RoundedCornerShape(6.dp),
                ),
            contentAlignment = Alignment.Center,
        ) {
            if (checked) {
                Icon(
                    Icons.Filled.Check,
                    contentDescription = null,
                    tint = Color.White,
                    modifier = Modifier.size(14.dp),
                )
            }
        }
        Text(
            text = "I confirm the above information is accurate and the documents are mine. False info may lead to permanent ban.",
            fontSize = 12.sp,
            color = Ink700,
            lineHeight = 17.sp,
            modifier = Modifier.weight(1f),
        )
    }
    Spacer(Modifier.height(6.dp))
    Text(
        text = "After submit: typically reviewed within 4–24 hours. We'll push-notify you with the outcome.",
        fontSize = 11.sp,
        color = Info,
    )
}


@Composable
private fun FieldLabel(text: String) {
    Text(
        text = text,
        fontSize = 14.sp,
        fontWeight = FontWeight.Bold,
        color = Ink900,
    )
}

@Composable
private fun ReadOnlyContactRow(
    icon: ImageVector,
    label: String,
    value: String,
    warn: Boolean = false,
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = if (warn) Warning else BrandGreen,
            modifier = Modifier.size(18.dp),
        )
        Column(modifier = Modifier.weight(1f)) {
            Text(label, fontSize = 11.sp, color = Ink500, fontWeight = FontWeight.SemiBold)
            Text(
                text = value,
                fontSize = 13.sp,
                color = if (warn) Warning else Ink900,
                fontWeight = if (warn) FontWeight.Normal else FontWeight.SemiBold,
            )
        }
    }
}

@Composable
private fun InlineError(text: String) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(WarningBg)
            .padding(10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Icon(Icons.Filled.Info, contentDescription = null, tint = Warning, modifier = Modifier.size(16.dp))
        Text(text, fontSize = 12.sp, color = Ink700)
    }
}

@Composable
private fun VerifiedSummaryCard(state: KycViewModel.UiState) {
    KycSectionCard(title = "You're verified") {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Icon(Icons.Filled.CheckCircle, contentDescription = null, tint = Success, modifier = Modifier.size(20.dp))
            Text(
                text = "Hospitals can now find you in the directory and send job requests.",
                fontSize = 13.sp,
                color = Ink700,
            )
        }
        ReadOnlyContactRow(icon = Icons.Filled.Phone, label = "Phone", value = state.phone ?: "—")
        ReadOnlyContactRow(icon = Icons.Filled.Email, label = "Email", value = state.email ?: "—")
        ReadOnlyContactRow(icon = Icons.Filled.Badge, label = "Aadhaar", value = if (state.aadhaarNumber.length == 12) "•••• •••• ${state.aadhaarNumber.takeLast(4)}" else "—")
        ReadOnlyContactRow(icon = Icons.Filled.WorkspacePremium, label = "Certificates", value = "${state.certDocPaths.size} uploaded")
    }
}

@Composable
private fun StatusBanner(status: VerificationStatus, submitted: Boolean) {
    val copy = kycStatusBannerCopy(status, submitted)
    val (bg, fg, icon) = when (status) {
        VerificationStatus.Verified -> Triple(SuccessBg, Success, Icons.Filled.Verified)
        VerificationStatus.Rejected -> Triple(ErrorBg, ErrorRed, Icons.Filled.Error)
        VerificationStatus.Pending -> if (submitted) {
            Triple(InfoBg, Info, Icons.Filled.HourglassTop)
        } else {
            Triple(WarningBg, Warning, Icons.Filled.HourglassTop)
        }
    }
    val label = copy.label
    val subtitle = copy.subtitle

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(8.dp))
            .background(bg)
            .padding(horizontal = 10.dp, vertical = 8.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(imageVector = icon, contentDescription = null, tint = fg, modifier = Modifier.size(14.dp))
        Text(
            text = "$label · $subtitle",
            fontSize = 11.sp,
            fontWeight = FontWeight.SemiBold,
            color = fg,
            modifier = Modifier.weight(1f),
        )
    }
}

private data class BannerStyle(
    val bg: Color,
    val fg: Color,
    val label: String,
    val subtitle: String,
    val icon: ImageVector,
)

/**
 * Pure label/subtitle copy for the KYC status banner. Verified /
 * Rejected map 1:1 to a fixed pair; Pending splits on whether the
 * engineer has uploaded the three required docs (submitted) vs is
 * still mid-flight on Step 2.
 *
 * Extracted so the copy → status mapping can be tested without the
 * Compose runtime, since the screen-side composable wires icon + bg
 * + fg colours which all need Material runtime.
 */
internal data class KycStatusBannerCopy(val label: String, val subtitle: String)

internal fun kycStatusBannerCopy(
    status: VerificationStatus,
    submitted: Boolean,
): KycStatusBannerCopy = when (status) {
    VerificationStatus.Verified -> KycStatusBannerCopy(
        label = "Verified",
        subtitle = "You can accept jobs.",
    )
    VerificationStatus.Rejected -> KycStatusBannerCopy(
        label = "Rejected",
        subtitle = "Re-upload the flagged documents.",
    )
    VerificationStatus.Pending -> if (submitted) {
        KycStatusBannerCopy(
            label = "Submitted for review",
            subtitle = "Typically reviewed within 4–24 hours.",
        )
    } else {
        KycStatusBannerCopy(
            label = "In progress",
            subtitle = "Complete every step to submit for review.",
        )
    }
}

@Composable
private fun ReuploadCta(
    notes: String?,
    rejectedDocTypes: List<String>,
    onClick: () -> Unit,
) {
    val flaggedLabel = flaggedDocsLabel(rejectedDocTypes)
    Card(
        colors = CardDefaults.cardColors(containerColor = ErrorBg),
        shape = RoundedCornerShape(14.dp),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(
            modifier = Modifier.fillMaxWidth().padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Text(
                text = if (flaggedLabel != null)
                    "Re-upload required: $flaggedLabel"
                else
                    "Your documents were rejected",
                fontSize = 15.sp,
                fontWeight = FontWeight.Bold,
                color = ErrorRed,
            )
            if (!notes.isNullOrBlank()) {
                // Admin's free-text reason — prefixed with "Why:" so the
                // engineer can see at a glance what went wrong.
                Text(
                    text = "Why: $notes",
                    fontSize = 13.sp,
                    color = Ink700,
                    fontWeight = FontWeight.Medium,
                )
            }
            Text(
                text = if (flaggedLabel != null)
                    "Tap below to clear the flagged doc(s) and re-pick them. Your other approved docs stay as-is."
                else
                    "Please re-upload your Aadhaar and qualification certificate. Your submission will go back into review once saved.",
                fontSize = 13.sp,
                color = Ink700,
            )
            Button(
                onClick = onClick,
                modifier = Modifier.fillMaxWidth(),
                colors = ButtonDefaults.buttonColors(
                    containerColor = MaterialTheme.colorScheme.error,
                    contentColor = MaterialTheme.colorScheme.onError,
                ),
            ) {
                Icon(Icons.Filled.Refresh, contentDescription = null, modifier = Modifier.size(18.dp))
                Spacer(Modifier.size(Spacing.sm))
                Text(if (flaggedLabel != null) "Re-upload flagged docs" else "Re-upload documents")
            }
        }
    }
}

@Composable
private fun DocumentRow(
    title: String,
    uploaded: Boolean,
    uploading: Boolean,
    icon: ImageVector,
    hue: Int,
    subtitleOverride: String? = null,
    failed: Boolean = false,
    onClick: (() -> Unit)?,
) {
    val errorState = failed && !uploaded && !uploading
    val borderColor = when {
        errorState -> ErrorRed
        uploaded -> SevaGreen700
        else -> Surface200
    }
    val bgColor = if (uploaded) SevaGreen50 else Surface0
    val tileBg = if (uploaded) SevaGreen700 else Surface50

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(bgColor)
            .let { m -> if (onClick != null && !uploading) m.clickable(onClick = onClick) else m }
            .drawBehind {
                val stroke = Stroke(
                    width = 1.5.dp.toPx(),
                    pathEffect = PathEffect.dashPathEffect(floatArrayOf(8.dp.toPx(), 4.dp.toPx()), 0f),
                )
                val path = Path().apply {
                    addRoundRect(
                        RoundRect(
                            rect = androidx.compose.ui.geometry.Rect(
                                offset = androidx.compose.ui.geometry.Offset.Zero,
                                size = Size(size.width, size.height),
                            ),
                            cornerRadius = CornerRadius(10.dp.toPx()),
                        ),
                    )
                }
                drawPath(path = path, color = borderColor, style = stroke)
            }
            .padding(14.dp),
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            modifier = Modifier.fillMaxWidth(),
        ) {
            Box(
                modifier = Modifier
                    .size(36.dp)
                    .clip(RoundedCornerShape(8.dp))
                    .background(tileBg),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector = if (uploaded) Icons.Filled.Check else icon,
                    contentDescription = null,
                    tint = if (uploaded) Color.White else Ink500,
                    modifier = Modifier.size(18.dp),
                )
            }
            Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(title, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = Ink900)
                val subtitle = when {
                    errorState -> "Upload failed — tap to retry"
                    subtitleOverride != null -> subtitleOverride
                    uploaded -> "Uploaded · tap to replace"
                    else -> "JPG, PNG, or PDF · up to 15 MB"
                }
                Text(
                    text = subtitle,
                    fontSize = 11.sp,
                    color = when {
                        errorState -> ErrorRed
                        uploaded -> SevaGreen700
                        else -> Ink500
                    },
                )
            }
            if (uploading) {
                CircularProgressIndicator(modifier = Modifier.size(20.dp), strokeWidth = 2.dp)
            }
        }
    }
}

@Composable
private fun KycSectionCard(title: String, content: @Composable () -> Unit) {
    Card(
        colors = CardDefaults.cardColors(containerColor = Surface0),
        border = androidx.compose.foundation.BorderStroke(1.dp, Surface200),
        shape = RoundedCornerShape(12.dp),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(
            modifier = Modifier.padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Text(
                text = title.uppercase(),
                fontSize = 11.sp,
                fontWeight = FontWeight.SemiBold,
                color = Ink500,
                letterSpacing = 0.6.sp,
            )
            content()
        }
    }
}

@Composable
private fun StepperBottomBar(
    state: KycViewModel.UiState,
    onPrevious: () -> Unit,
    onNext: () -> Unit,
    onSubmit: () -> Unit,
) {
    val isLast = state.currentStep.isLast
    val isFirst = state.currentStep.isFirst
    val canSubmit = isLast && state.canAdvance && !state.saving
    val canNext = !isLast && state.canAdvance
    val rejected = state.verificationStatus == VerificationStatus.Rejected
    val nextLabel = when {
        isLast && rejected -> "Re-submit for review"
        isLast -> "Submit for review"
        else -> "Next"
    }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(Surface0)
            .border(width = 1.dp, color = Surface200, shape = RoundedCornerShape(0.dp))
            .padding(Spacing.lg),
        horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
    ) {
        if (!isFirst) {
            OutlinedButton(
                onClick = onPrevious,
                enabled = !state.saving,
                modifier = Modifier
                    .weight(1f)
                    .height(Spacing.MinTouchTarget),
            ) { Text("Back") }
        }
        Button(
            onClick = if (isLast) onSubmit else onNext,
            enabled = if (isLast) canSubmit else canNext,
            modifier = Modifier
                .weight(if (isFirst) 1f else 1.4f)
                .height(Spacing.MinTouchTarget),
        ) {
            if (state.saving && isLast) {
                CircularProgressIndicator(
                    modifier = Modifier.size(18.dp),
                    strokeWidth = 2.dp,
                    color = MaterialTheme.colorScheme.onPrimary,
                )
                Spacer(Modifier.size(Spacing.sm))
                Text("Saving…")
            } else {
                Text(nextLabel)
            }
        }
    }
}

private inline fun readAndUpload(
    context: android.content.Context,
    uri: Uri,
    send: (fileName: String, bytes: ByteArray, mime: String?) -> Unit,
    onError: (message: String) -> Unit,
) {
    val resolver = context.contentResolver
    val mime = resolver.getType(uri)
    val name = queryDisplayName(context, uri) ?: uri.lastPathSegment ?: "upload"
    val bytes = try {
        resolver.openInputStream(uri)?.use { it.readBytes() }
    } catch (t: Throwable) {
        onError("Couldn't read the selected file. Pick again.")
        return
    }
    if (bytes == null) {
        // openInputStream returns null when the provider has been revoked,
        // the URI was permission-pruned by SAF, or the file was deleted
        // between pick and use. Without surfacing, the upload callback
        // never fires and the engineer sees an indefinite spinner.
        onError("Couldn't read the selected file. Pick again.")
        return
    }
    send(name, bytes, mime)
}

private fun queryDisplayName(context: android.content.Context, uri: Uri): String? {
    return context.contentResolver.query(
        uri,
        arrayOf(android.provider.OpenableColumns.DISPLAY_NAME),
        null, null, null,
    )?.use { cursor ->
        if (cursor.moveToFirst()) cursor.getString(0) else null
    }
}

/**
 * Inline hint copy under the Aadhaar input field, driven by the
 * sanitized digit count and the [AadhaarValidator] checksum result.
 * Four states:
 *   empty            -> "12 digits, no spaces"
 *   short            -> "N/12 digits"
 *   12 + bad checksum -> "Number doesn't pass the standard Aadhaar checksum"
 *   12 + good checksum -> "Looks valid ✓"
 */
internal fun aadhaarNumberHint(digits: String, checksumOk: Boolean): String = when {
    digits.isEmpty() -> "12 digits, no spaces"
    digits.length < 12 -> "${digits.length}/12 digits"
    !checksumOk -> "Number doesn't pass the standard Aadhaar checksum"
    else -> "Looks valid ✓"
}

/**
 * Inline hint copy under the PAN input field. Mirrors the
 * Aadhaar helper's four-state shape with PAN-specific copy.
 */
internal fun panNumberHint(pan: String, panOk: Boolean): String = when {
    pan.isEmpty() -> "10 chars: 5 letters, 4 digits, 1 letter (e.g. ABCDE1234F)"
    pan.length < 10 -> "${pan.length}/10 chars"
    !panOk -> "Format must be ABCDE1234F"
    else -> "Looks valid ✓"
}

/**
 * User-facing comma-joined list of flagged doc types for the re-upload
 * CTA. Returns null when the admin used a global rejection (the
 * server emits an empty list) so the caller can pick a different
 * "all docs" copy variant.
 *
 *   * `aadhaar` → "Aadhaar"
 *   * `pan` → "PAN"
 *   * `cert` → "certificate" (lowercase — slots into a sentence)
 *   * unknown → raw key (forward-compat for a future doc type)
 */
internal fun flaggedDocsLabel(rejectedDocTypes: List<String>): String? =
    rejectedDocTypes
        .joinToString { type ->
            when (type) {
                "aadhaar" -> "Aadhaar"
                "pan" -> "PAN"
                "cert" -> "certificate"
                else -> type
            }
        }
        .ifBlank { null }
