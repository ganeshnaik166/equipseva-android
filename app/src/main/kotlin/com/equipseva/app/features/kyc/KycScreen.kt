package com.equipseva.app.features.kyc

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
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
import androidx.compose.material.icons.outlined.CloudUpload
import androidx.compose.material3.AssistChip
import androidx.compose.material3.AssistChipDefaults
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Checkbox
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.foundation.shape.CircleShape
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
import com.equipseva.app.core.data.repair.RepairEquipmentCategory
import com.equipseva.app.designsystem.components.GradientTile
import com.equipseva.app.designsystem.components.SecureScreen
import com.equipseva.app.features.repair.components.LocationPickerMap
import com.google.android.gms.maps.model.LatLng
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
import com.equipseva.app.designsystem.theme.Surface0
import com.equipseva.app.designsystem.theme.Surface50
import com.equipseva.app.designsystem.theme.Surface200
import com.equipseva.app.designsystem.theme.Warning
import com.equipseva.app.designsystem.theme.WarningBg
import androidx.compose.foundation.text.KeyboardOptions
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
        uri?.let { readAndUpload(context, it) { name, bytes, mime -> viewModel.uploadAadhaarDoc(name, bytes, mime) } }
    }

    val certPicker = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.OpenDocument(),
    ) { uri: Uri? ->
        uri?.let { readAndUpload(context, it) { name, bytes, mime -> viewModel.uploadCertificate(name, bytes, mime) } }
    }

    val panPicker = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.OpenDocument(),
    ) { uri: Uri? ->
        uri?.let { readAndUpload(context, it) { name, bytes, mime -> viewModel.uploadPan(name, bytes, mime) } }
    }

    Scaffold(
        topBar = {
            com.equipseva.app.designsystem.components.EsTopBar(
                title = "Verification (KYC)",
                subtitle = "Step ${state.currentStep.ordinal + 1} of ${com.equipseva.app.features.kyc.KycStep.entries.size}",
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
                    onServiceCoordsChange = viewModel::onServiceCoordsChange,
                    onAttestationChange = viewModel::onAttestationChange,
                    onPickAadhaar = {
                        aadhaarPicker.launch(
                            arrayOf("application/pdf", "image/jpeg", "image/png", "image/webp"),
                        )
                    },
                    onPickPan = {
                        panPicker.launch(
                            arrayOf("application/pdf", "image/jpeg", "image/png", "image/webp"),
                        )
                    },
                    onPickCertificate = {
                        certPicker.launch(arrayOf("application/pdf", "image/jpeg", "image/png", "image/webp"))
                    },
                    onStartReupload = viewModel::startReupload,
                    onJumpToStep = viewModel::jumpToStep,
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
        Column(
            modifier = Modifier.fillMaxWidth().padding(horizontal = Spacing.lg, vertical = Spacing.md),
            verticalArrangement = Arrangement.spacedBy(Spacing.md),
        ) {
            Text("Verify your email", fontWeight = FontWeight.Bold, fontSize = 18.sp, color = Ink900)
            Text("Code sent to $email", fontSize = 13.sp, color = Ink500)
            OutlinedTextField(
                value = code,
                onValueChange = onCodeChange,
                label = { Text("6-digit code") },
                singleLine = true,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.NumberPassword),
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
    onServiceCoordsChange: (Double?, Double?) -> Unit,
    onAttestationChange: (Boolean) -> Unit,
    onPickAadhaar: () -> Unit,
    onPickPan: () -> Unit,
    onPickCertificate: () -> Unit,
    onStartReupload: () -> Unit,
    onJumpToStep: (KycStep) -> Unit,
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

        StepHeader(current = state.currentStep, onJump = onJumpToStep)

        // Per-step body. Each step renders only what's relevant to that step
        // so the form feels short — best-practice gig-app onboarding caps each
        // step at ~30 seconds of input.
        when (state.currentStep) {
            KycStep.Personal -> PersonalStep(
                state = state,
                onServiceAddressChange = onServiceAddressChange,
                onServiceCoordsChange = onServiceCoordsChange,
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
private fun StepHeader(current: KycStep, onJump: (KycStep) -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        KycStep.entries.forEach { step ->
            val active = step == current
            val done = step.ordinal < current.ordinal
            Row(
                modifier = Modifier.weight(1f),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.Start,
            ) {
                Box(
                    modifier = Modifier
                        .size(28.dp)
                        .clip(CircleShape)
                        .background(
                            when {
                                done -> Success
                                active -> BrandGreen
                                else -> Surface200
                            },
                        ),
                    contentAlignment = Alignment.Center,
                ) {
                    if (done) {
                        Icon(Icons.Filled.Check, contentDescription = null, tint = Color.White, modifier = Modifier.size(16.dp))
                    } else {
                        Text(
                            text = step.number.toString(),
                            color = if (active) Color.White else Ink500,
                            fontWeight = FontWeight.Bold,
                            fontSize = 13.sp,
                        )
                    }
                }
                if (step != KycStep.entries.last()) {
                    Box(
                        modifier = Modifier
                            .padding(horizontal = 6.dp)
                            .height(2.dp)
                            .weight(1f)
                            .background(if (done) Success else Surface200),
                    )
                }
            }
        }
    }
    Spacer(Modifier.height(6.dp))
    Text(
        text = "Step ${current.number} of ${KycStep.total} · ${current.title}",
        fontSize = 12.sp,
        color = Ink500,
        fontWeight = FontWeight.SemiBold,
    )
    Text(
        text = current.subtitle,
        fontSize = 18.sp,
        color = Ink900,
        fontWeight = FontWeight.Bold,
    )
}

@Composable
private fun PersonalStep(
    state: KycViewModel.UiState,
    onServiceAddressChange: (String) -> Unit,
    onServiceCoordsChange: (Double?, Double?) -> Unit,
    onEmailDraftChange: (String) -> Unit,
    onSaveEmail: () -> Unit,
    onAddPhone: () -> Unit,
    onVerifyEmail: () -> Unit,
) {
    KycSectionCard(title = "How hospitals reach you") {
        ReadOnlyContactRow(icon = Icons.Filled.Badge, label = "Name", value = state.fullName ?: "—")

        // Phone — direct save flow, no OTP. Add when blank, Change when set.
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
            modifier = Modifier.fillMaxWidth(),
        ) {
            Icon(
                imageVector = Icons.Filled.Phone,
                contentDescription = null,
                tint = Ink500,
                modifier = Modifier.size(18.dp),
            )
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = "Phone",
                    fontSize = 11.sp,
                    color = Ink500,
                    fontWeight = FontWeight.SemiBold,
                )
                Text(
                    text = state.phone ?: "Add so hospitals can call you",
                    fontSize = 13.sp,
                    color = if (state.phone.isNullOrBlank()) Ink500 else Ink900,
                    fontWeight = FontWeight.SemiBold,
                )
            }
            OutlinedButton(
                onClick = onAddPhone,
                contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 12.dp, vertical = 6.dp),
            ) {
                Text(
                    text = if (state.phone.isNullOrBlank()) "Add" else "Change",
                    fontSize = 12.sp,
                )
            }
        }

        // Email — inline edit. Save trailing appears only when the draft
        // diverges from the saved value. No verification step in v1; the
        // user signed in with this address so it is already trusted.
        OutlinedTextField(
            value = state.emailDraft,
            onValueChange = onEmailDraftChange,
            label = { Text("Email") },
            singleLine = true,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email),
            enabled = !state.savingEmail,
            supportingText = {
                if (state.email.isNullOrBlank()) {
                    Text(
                        text = "Add the email hospitals can reach you at.",
                        fontSize = 11.sp,
                        color = Ink500,
                    )
                }
            },
            trailingIcon = {
                val changed = state.emailDraft.isNotBlank() &&
                    !state.emailDraft.equals(state.email, ignoreCase = true)
                if (changed) {
                    androidx.compose.material3.TextButton(
                        onClick = onSaveEmail,
                        enabled = !state.savingEmail,
                    ) {
                        Text(if (state.savingEmail) "Saving…" else "Save")
                    }
                }
            },
            modifier = Modifier.fillMaxWidth(),
        )

        Text(
            text = "Hospitals can Call / WhatsApp / Email you straight from your profile.",
            fontSize = 12.sp,
            color = Ink500,
        )
    }
    KycSectionCard(title = "Where you operate") {
        OutlinedTextField(
            value = state.serviceAddress,
            onValueChange = onServiceAddressChange,
            label = { Text("Service address") },
            placeholder = { Text("House #, area, city — landmark for our records") },
            minLines = 2,
            maxLines = 4,
            modifier = Modifier.fillMaxWidth(),
        )
        Text(
            text = "Pin the area you serve so hospitals nearby see you first.",
            fontSize = 12.sp,
            color = Ink500,
        )
        val pinned = state.serviceLatitude?.let { lat ->
            state.serviceLongitude?.let { lng -> LatLng(lat, lng) }
        }
        LocationPickerMap(
            selected = pinned,
            onLocationPicked = { latLng ->
                onServiceCoordsChange(latLng.latitude, latLng.longitude)
            },
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
    val hint = when {
        digits.isEmpty() -> "12 digits, no spaces"
        digits.length < 12 -> "${digits.length}/12 digits"
        !checksumOk -> "Number doesn't pass the standard Aadhaar checksum"
        else -> "Looks valid ✓"
    }
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
    val panHint = when {
        pan.isEmpty() -> "10 chars: 5 letters, 4 digits, 1 letter (e.g. ABCDE1234F)"
        pan.length < 10 -> "${pan.length}/10 chars"
        !panOk -> "Format must be ABCDE1234F"
        else -> "Looks valid ✓"
    }
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
    KycSectionCard(title = "Attestation") {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(10.dp))
                .background(InfoBg)
                .padding(12.dp),
            verticalAlignment = Alignment.Top,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Checkbox(checked = state.attestationAccepted, onCheckedChange = onAttestationChange)
            Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(
                    text = "I confirm that the documents and details above are mine.",
                    fontSize = 13.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = Ink900,
                )
                Text(
                    text = "Submitting fake or borrowed documents will get your account permanently banned.",
                    fontSize = 11.sp,
                    color = Ink500,
                )
            }
        }
        Text(
            text = "After submit: typically reviewed within 4–24 hours. We'll push-notify you with the outcome.",
            fontSize = 11.sp,
            color = Info,
        )
    }
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
                text = "Hospitals can now find you in the directory and request jobs.",
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
    val (bg, fg, label, subtitle, icon) = when (status) {
        VerificationStatus.Verified -> BannerStyle(
            bg = SuccessBg,
            fg = Success,
            label = "Verified",
            subtitle = "You can accept jobs.",
            icon = Icons.Filled.Verified,
        )
        VerificationStatus.Rejected -> BannerStyle(
            bg = ErrorBg,
            fg = ErrorRed,
            label = "Rejected",
            subtitle = "Re-upload the flagged documents.",
            icon = Icons.Filled.Error,
        )
        VerificationStatus.Pending -> if (submitted) {
            BannerStyle(
                bg = InfoBg,
                fg = Info,
                label = "Submitted for review",
                subtitle = "Typically reviewed within 4–24 hours.",
                icon = Icons.Filled.HourglassTop,
            )
        } else {
            BannerStyle(
                bg = WarningBg,
                fg = Warning,
                label = "In progress",
                subtitle = "Complete every step to submit for review.",
                icon = Icons.Filled.HourglassTop,
            )
        }
    }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(bg)
            .padding(14.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.Top,
    ) {
        Icon(imageVector = icon, contentDescription = null, tint = fg, modifier = Modifier.size(24.dp))
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(label, fontSize = 14.sp, fontWeight = FontWeight.Bold, color = fg)
            Text(subtitle, fontSize = 13.sp, color = Ink700)
        }
    }
}

private data class BannerStyle(
    val bg: Color,
    val fg: Color,
    val label: String,
    val subtitle: String,
    val icon: ImageVector,
)

@Composable
private fun ReuploadCta(
    notes: String?,
    rejectedDocTypes: List<String>,
    onClick: () -> Unit,
) {
    val flaggedLabel = rejectedDocTypes
        .joinToString { type ->
            when (type) {
                "aadhaar" -> "Aadhaar"
                "selfie" -> "selfie"
                "cert" -> "certificate"
                else -> type
            }
        }
        .ifBlank { null }
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
    Card(
        colors = CardDefaults.cardColors(containerColor = Surface0),
        border = androidx.compose.foundation.BorderStroke(
            1.dp,
            if (errorState) ErrorRed else Surface200,
        ),
        shape = RoundedCornerShape(5.dp),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Row(
            modifier = Modifier.padding(12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            if (uploaded) {
                GradientTile(icon = icon, hue = hue, size = 56.dp)
            } else {
                DashedPlaceholderTile(icon = icon)
            }
            Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(title, fontSize = 14.sp, fontWeight = FontWeight.Bold, color = Ink900)
                val subtitle = when {
                    errorState -> "Upload failed — tap retry"
                    subtitleOverride != null -> subtitleOverride
                    uploaded -> "✓ Uploaded"
                    else -> "Required"
                }
                Text(
                    text = subtitle,
                    fontSize = 12.sp,
                    color = when {
                        errorState -> ErrorRed
                        uploaded -> Success
                        else -> Ink500
                    },
                )
            }
            if (onClick != null) {
                if (uploading) {
                    CircularProgressIndicator(modifier = Modifier.size(24.dp), strokeWidth = 2.dp)
                } else if (uploaded) {
                    OutlinedButton(
                        onClick = onClick,
                        contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 12.dp, vertical = 6.dp),
                    ) { Text("Replace", fontSize = 13.sp) }
                } else if (errorState) {
                    Button(
                        onClick = onClick,
                        colors = ButtonDefaults.buttonColors(containerColor = ErrorRed),
                        contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 12.dp, vertical = 6.dp),
                    ) {
                        Icon(Icons.Filled.Refresh, contentDescription = null, modifier = Modifier.size(16.dp))
                        Spacer(Modifier.size(6.dp))
                        Text("Retry", fontSize = 13.sp)
                    }
                } else {
                    Button(
                        onClick = onClick,
                        contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 12.dp, vertical = 6.dp),
                    ) {
                        Icon(Icons.Outlined.CloudUpload, contentDescription = null, modifier = Modifier.size(16.dp))
                        Spacer(Modifier.size(6.dp))
                        Text("Upload", fontSize = 13.sp)
                    }
                }
            }
        }
    }
}

@Composable
private fun DashedPlaceholderTile(icon: ImageVector) {
    val dashColor = Ink300
    Box(
        modifier = Modifier
            .size(56.dp)
            .clip(RoundedCornerShape(10.dp))
            .background(Surface50)
            .drawBehind {
                val stroke = Stroke(
                    width = 1.5.dp.toPx(),
                    pathEffect = PathEffect.dashPathEffect(floatArrayOf(6.dp.toPx(), 4.dp.toPx()), 0f),
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
                drawPath(path = path, color = dashColor, style = stroke)
            },
        contentAlignment = Alignment.Center,
    ) {
        Icon(imageVector = icon, contentDescription = null, tint = Ink500, modifier = Modifier.size(24.dp))
    }
}

@Composable
private fun KycSectionCard(title: String, content: @Composable () -> Unit) {
    Card(
        colors = CardDefaults.cardColors(containerColor = Surface0),
        border = androidx.compose.foundation.BorderStroke(1.dp, Surface200),
        shape = RoundedCornerShape(5.dp),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(
            modifier = Modifier.padding(Spacing.lg),
            verticalArrangement = Arrangement.spacedBy(Spacing.md),
        ) {
            Text(
                text = title.uppercase(),
                fontSize = 13.sp,
                fontWeight = FontWeight.Bold,
                color = Ink700,
                letterSpacing = 0.3.sp,
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
        } else {
            Spacer(Modifier.width(0.dp))
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
) {
    val resolver = context.contentResolver
    val mime = resolver.getType(uri)
    val name = queryDisplayName(context, uri) ?: uri.lastPathSegment ?: "upload"
    val bytes = resolver.openInputStream(uri)?.use { it.readBytes() } ?: return
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
