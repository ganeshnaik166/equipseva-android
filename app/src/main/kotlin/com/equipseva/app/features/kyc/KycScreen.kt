package com.equipseva.app.features.kyc

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.outlined.FileUpload
import androidx.compose.material.icons.outlined.LocationOn
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
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
import androidx.compose.runtime.rememberCoroutineScope
import kotlinx.coroutines.launch
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.RoundRect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.core.data.engineers.VerificationStatus
import com.equipseva.app.designsystem.components.EsBtn
import com.equipseva.app.designsystem.components.EsBtnKind
import com.equipseva.app.designsystem.components.EsBtnSize
import com.equipseva.app.designsystem.components.EsField
import com.equipseva.app.designsystem.components.EsFieldType
import com.equipseva.app.designsystem.components.Pill
import com.equipseva.app.designsystem.components.PillKind
import com.equipseva.app.designsystem.components.SecureScreen
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.BorderStrong
import com.equipseva.app.designsystem.theme.Paper2
import com.equipseva.app.designsystem.theme.Paper3
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaDanger50
import com.equipseva.app.designsystem.theme.SevaDanger500
import com.equipseva.app.designsystem.theme.SevaGreen50
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaInfo50
import com.equipseva.app.designsystem.theme.SevaInfo500
import com.equipseva.app.designsystem.theme.SevaInk400
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk700
import com.equipseva.app.designsystem.theme.SevaInk900
import com.equipseva.app.designsystem.theme.SevaWarning50
import com.equipseva.app.designsystem.theme.SevaWarning500
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.features.repair.components.LocationPickerMap
import com.google.android.gms.maps.model.LatLng
import androidx.compose.foundation.text.KeyboardOptions

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

    val deepLinkHost: com.equipseva.app.navigation.DeepLinkHost = hiltViewModel()
    LaunchedEffect(viewModel) {
        viewModel.effects.collect { effect ->
            when (effect) {
                is KycViewModel.Effect.ShowMessage -> onShowMessage(effect.text)
                KycViewModel.Effect.Submitted -> {
                    viewModel.markExited()
                    // Refresh the cached engineer status so the bottom-nav
                    // Jobs gate flips to Pending immediately.
                    deepLinkHost.refreshEngineerStatus()
                    onSubmitted()
                }
            }
        }
    }

    // Pin KYC as the last screen while the user is here so a process death
    // during the SAF document picker restores them on the next cold start.
    // CRITICALLY: do NOT clear the pin on Compose disposal — that fires
    // when MainActivity is destroyed for activity recreation (e.g. low-mem
    // reclaim during the picker), which would wipe the pin BEFORE we get
    // a chance to restore from it. The pin is cleared on explicit user
    // exits (Back below + Submitted above) and on sign-out (ProfileVM).
    androidx.compose.runtime.LaunchedEffect(viewModel) {
        viewModel.markEntered()
    }

    val pickerScope = rememberCoroutineScope()

    val aadhaarPicker = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.OpenDocument(),
    ) { uri: Uri? ->
        uri?.let {
            pickerScope.launch(kotlinx.coroutines.Dispatchers.IO) {
                readAndUpload(context, it) { name, bytes, mime ->
                    viewModel.uploadAadhaarDoc(name, bytes, mime)
                }
            }
        }
    }

    val certPicker = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.OpenDocument(),
    ) { uri: Uri? ->
        uri?.let {
            pickerScope.launch(kotlinx.coroutines.Dispatchers.IO) {
                readAndUpload(context, it) { name, bytes, mime ->
                    viewModel.uploadCertificate(name, bytes, mime)
                }
            }
        }
    }

    val panPicker = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.OpenDocument(),
    ) { uri: Uri? ->
        uri?.let {
            pickerScope.launch(kotlinx.coroutines.Dispatchers.IO) {
                readAndUpload(context, it) { name, bytes, mime ->
                    viewModel.uploadPan(name, bytes, mime)
                }
            }
        }
    }

    Scaffold(
        topBar = {
            com.equipseva.app.designsystem.components.EsTopBar(
                title = "Verification (KYC)",
                subtitle = "Step ${state.currentStep.ordinal + 1} of ${KycStep.entries.size}",
                onBack = {
                    viewModel.markExited()
                    onBack()
                },
            )
        },
        bottomBar = {
            // Verified engineers don't need a footer.
            if (state.verificationStatus != VerificationStatus.Verified) {
                BottomActionBar(
                    state = state,
                    onPrevious = viewModel::goToPreviousStep,
                    onNext = viewModel::goToNextStep,
                    onSubmit = viewModel::save,
                )
            }
        },
        containerColor = PaperDefault,
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
                else -> KycBody(
                    state = state,
                    onAadhaarNumberChange = viewModel::onAadhaarNumberChange,
                    onPanNumberChange = viewModel::onPanNumberChange,
                    onServiceAddressChange = viewModel::onServiceAddressChange,
                    onServiceCoordsChange = viewModel::onServiceCoordsChange,
                    onServiceStateChange = viewModel::onServiceStateChange,
                    onServiceDistrictChange = viewModel::onServiceDistrictChange,
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
            Text("Verify your email", fontWeight = FontWeight.Bold, fontSize = 18.sp, color = SevaInk900)
            Text("Code sent to $email", fontSize = 13.sp, color = SevaInk500)
            OutlinedTextField(
                value = code,
                onValueChange = onCodeChange,
                label = { Text("6-digit code") },
                singleLine = true,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.NumberPassword),
                enabled = !verifying,
                supportingText = if (sending) {
                    { Text("Sending code…", fontSize = 12.sp, color = SevaInk500) }
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
private fun KycBody(
    state: KycViewModel.UiState,
    onAadhaarNumberChange: (String) -> Unit,
    onPanNumberChange: (String) -> Unit,
    onServiceAddressChange: (String) -> Unit,
    onServiceCoordsChange: (Double?, Double?) -> Unit,
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
    Column(modifier = Modifier.fillMaxSize()) {
        // Sticky status timeline header (sits below the top bar).
        StatusTimelineHeader(
            status = state.verificationStatus,
            submitted = state.kycSubmitted,
        )

        Column(
            modifier = Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
        ) {
            if (state.verificationStatus == VerificationStatus.Rejected) {
                ReuploadCta(
                    notes = state.verificationNotes,
                    rejectedDocTypes = state.rejectedDocTypes,
                    onClick = onStartReupload,
                )
                Spacer(Modifier.height(14.dp))
            }

            when (state.currentStep) {
                KycStep.Personal -> PersonalStep(
                    state = state,
                    onServiceAddressChange = onServiceAddressChange,
                    onServiceCoordsChange = onServiceCoordsChange,
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

            // Inline error chip mirrors the disabled-Submit reason.
            state.stepError()?.let { msg ->
                Spacer(Modifier.height(12.dp))
                InlineError(text = msg)
            }

            Spacer(Modifier.height(16.dp))
        }
    }
}

// ---------- Status timeline ----------

@Composable
private fun StatusTimelineHeader(
    status: VerificationStatus,
    submitted: Boolean,
) {
    // 0 = Submitted, 1 = Under review, 2 = Verified.
    val statusIdx = when (status) {
        VerificationStatus.Verified -> 2
        VerificationStatus.Pending -> if (submitted) 1 else 0
        VerificationStatus.Rejected -> 1
    }
    val labels = listOf("Submitted", "Under review", "Verified")

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(Color.White)
            .border(width = 1.dp, color = BorderDefault, shape = RoundedCornerShape(0.dp))
            .padding(horizontal = 16.dp, vertical = 14.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.Top,
            horizontalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            labels.forEachIndexed { i, label ->
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Box(
                        modifier = Modifier
                            .size(22.dp)
                            .clip(CircleShape)
                            .background(if (i <= statusIdx) SevaGreen700 else Paper2)
                            .let {
                                if (i == statusIdx) it.border(2.dp, SevaGreen700, CircleShape) else it
                            },
                        contentAlignment = Alignment.Center,
                    ) {
                        when {
                            i < statusIdx -> Icon(
                                imageVector = Icons.Filled.Check,
                                contentDescription = null,
                                tint = Color.White,
                                modifier = Modifier.size(12.dp),
                            )
                            i == statusIdx -> Box(
                                modifier = Modifier
                                    .size(6.dp)
                                    .clip(CircleShape)
                                    .background(Color.White),
                            )
                            else -> Text(
                                text = (i + 1).toString(),
                                fontSize = 10.sp,
                                fontWeight = FontWeight.Bold,
                                color = SevaInk400,
                            )
                        }
                    }
                    Text(
                        text = label,
                        fontSize = 9.sp,
                        color = if (i <= statusIdx) SevaInk900 else SevaInk400,
                        fontWeight = if (i <= statusIdx) FontWeight.SemiBold else FontWeight.Medium,
                        modifier = Modifier.padding(top = 4.dp),
                    )
                }
                if (i < labels.size - 1) {
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .height(2.dp)
                            .padding(top = 0.dp)
                            .background(if (i < statusIdx) SevaGreen700 else BorderDefault),
                    ) {}
                }
            }
        }
        // Status banner row appears below the timeline whenever we have any
        // signal — pending, verified, rejected, or "draft" (in-progress).
        StatusBannerRow(status = status, submitted = submitted)
    }
}

@Composable
private fun StatusBannerRow(status: VerificationStatus, submitted: Boolean) {
    val (bg, fg, copy) = when (status) {
        VerificationStatus.Verified -> Triple(SevaGreen50, SevaGreen700, "Verified · you can bid on jobs")
        VerificationStatus.Rejected -> Triple(SevaDanger50, SevaDanger500, "Rejected · please resubmit")
        VerificationStatus.Pending -> if (submitted) {
            Triple(SevaInfo50, SevaInfo500, "Submitted · usually 24h")
        } else {
            // Draft = pending + nothing uploaded yet.
            Triple(SevaWarning50, SevaWarning500, "Draft · finish to submit")
        }
    }
    Spacer(Modifier.height(10.dp))
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(8.dp))
            .background(bg)
            .padding(8.dp),
    ) {
        Text(
            text = copy,
            fontSize = 11.sp,
            fontWeight = FontWeight.SemiBold,
            color = fg,
        )
    }
}

// ---------- Step 0: Personal ----------

@Composable
private fun PersonalStep(
    state: KycViewModel.UiState,
    onServiceAddressChange: (String) -> Unit,
    onServiceCoordsChange: (Double?, Double?) -> Unit,
    onServiceStateChange: (String) -> Unit,
    onServiceDistrictChange: (String) -> Unit,
    onEmailDraftChange: (String) -> Unit,
    onSaveEmail: () -> Unit,
    onAddPhone: () -> Unit,
    onVerifyEmail: () -> Unit,
) {
    Text(
        text = "Personal",
        fontSize = 18.sp,
        fontWeight = FontWeight.Bold,
        color = SevaInk900,
    )
    Spacer(Modifier.height(4.dp))
    Text(
        text = "How hospitals reach you and where you operate.",
        fontSize = 12.sp,
        color = SevaInk500,
    )
    Spacer(Modifier.height(16.dp))

    // Card 1 — How hospitals reach you.
    SectionCard {
        SubSectionLabel("HOW HOSPITALS REACH YOU")
        Spacer(Modifier.height(10.dp))

        EsField(
            value = state.fullName.orEmpty(),
            onChange = {},
            label = "Full name",
            enabled = false,
        )

        Spacer(Modifier.height(10.dp))

        // Email — verified pill, or draft Save / Verify CTA when changed.
        val emailDraftDiffers = state.emailDraft.isNotBlank() &&
            !state.emailDraft.equals(state.email, ignoreCase = true)
        EsField(
            value = state.emailDraft,
            onChange = onEmailDraftChange,
            label = "Email",
            placeholder = "you@example.com",
            type = EsFieldType.Email,
            trailing = {
                when {
                    emailDraftDiffers -> Text(
                        text = if (state.savingEmail) "Saving…" else "Save",
                        fontSize = 12.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = SevaGreen700,
                        modifier = Modifier
                            .clickable(enabled = !state.savingEmail) { onSaveEmail() }
                            .padding(horizontal = 6.dp, vertical = 4.dp),
                    )
                    state.emailVerified -> Pill(text = "Verified", kind = PillKind.Success)
                    !state.email.isNullOrBlank() -> Text(
                        text = "Verify",
                        fontSize = 12.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = SevaGreen700,
                        modifier = Modifier
                            .clickable { onVerifyEmail() }
                            .padding(horizontal = 6.dp, vertical = 4.dp),
                    )
                }
            },
        )

        Spacer(Modifier.height(10.dp))

        // Phone — Add/Verify trailing.
        EsField(
            value = state.phone.orEmpty(),
            onChange = {},
            label = "Phone (for hospital contact)",
            placeholder = "+91 98765 43210",
            hint = "Used by hospitals to call/WhatsApp. Not for login.",
            enabled = false,
            trailing = {
                if (state.phoneVerified) {
                    Pill(text = "Verified", kind = PillKind.Success)
                } else {
                    Text(
                        text = if (state.phone.isNullOrBlank()) "Add" else "Verify",
                        fontSize = 12.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = SevaGreen700,
                        modifier = Modifier
                            .clickable { onAddPhone() }
                            .padding(horizontal = 6.dp, vertical = 4.dp),
                    )
                }
            },
        )
    }

    Spacer(Modifier.height(14.dp))

    // Card 2 — Where you operate (cascading State → District picker).
    SectionCard {
        SubSectionLabel("WHERE YOU OPERATE")
        Spacer(Modifier.height(10.dp))

        // Country is fixed to India for v1.
        com.equipseva.app.designsystem.components.EsField(
            value = com.equipseva.app.core.data.location.IndiaLocations.COUNTRY,
            onChange = {},
            label = "Country",
            enabled = false,
        )
        Spacer(Modifier.height(10.dp))

        com.equipseva.app.designsystem.components.EsDropdown(
            value = state.serviceState,
            onValueChange = onServiceStateChange,
            options = com.equipseva.app.core.data.location.IndiaLocations.STATES,
            label = "State",
            placeholder = "Select your state",
        )
        Spacer(Modifier.height(10.dp))

        val districtOptions = com.equipseva.app.core.data.location.IndiaLocations
            .districtsFor(state.serviceState)
        com.equipseva.app.designsystem.components.EsDropdown(
            value = state.serviceDistrict,
            onValueChange = onServiceDistrictChange,
            options = districtOptions,
            label = "District",
            placeholder = if (state.serviceState.isNullOrBlank())
                "Pick a state first" else "Select your district",
            enabled = !state.serviceState.isNullOrBlank() && districtOptions.isNotEmpty(),
            hint = if (!state.serviceState.isNullOrBlank() && districtOptions.isEmpty())
                "District list coming soon for this state." else null,
        )

        // Optional pin-on-map fallback so engineers who want exact coords
        // (proximity sort uses lat/lng) can still drop a pin. The map is
        // a passive surface — we only fetch when the user taps the button
        // below.
        Spacer(Modifier.height(12.dp))
        val pinned = state.serviceLatitude?.let { lat ->
            state.serviceLongitude?.let { lng -> LatLng(lat, lng) }
        }
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(12.dp)),
        ) {
            LocationPickerMap(
                selected = pinned,
                onLocationPicked = { latLng ->
                    onServiceCoordsChange(latLng.latitude, latLng.longitude)
                },
            )
        }
        Spacer(Modifier.height(10.dp))
        com.equipseva.app.features.repair.components.MyLocationButton(
            onLocationPicked = { latLng ->
                onServiceCoordsChange(latLng.latitude, latLng.longitude)
            },
        )
    }
}

// ---------- Step 1: Documents ----------

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
    Text(
        text = "Documents",
        fontSize = 18.sp,
        fontWeight = FontWeight.Bold,
        color = SevaInk900,
    )
    Spacer(Modifier.height(4.dp))
    Text(
        text = "Upload identity and qualification proof.",
        fontSize = 12.sp,
        color = SevaInk500,
    )
    Spacer(Modifier.height(16.dp))

    EsField(
        value = state.aadhaarNumber,
        onChange = onAadhaarNumberChange,
        label = "Aadhaar number",
        placeholder = "12-digit number",
        hint = "As on Aadhaar card",
        type = EsFieldType.Number,
    )
    UploadRow(
        label = "Aadhaar document",
        done = !state.aadhaarDocPath.isNullOrBlank(),
        uploading = state.uploadingAadhaar,
        failed = state.aadhaarFailed,
        onClick = onPickAadhaar,
    )

    Spacer(Modifier.height(12.dp))
    EsField(
        value = state.panNumber,
        onChange = onPanNumberChange,
        label = "PAN number",
        placeholder = "ABCDE1234F",
    )
    UploadRow(
        label = "PAN document",
        done = !state.panDocPath.isNullOrBlank(),
        uploading = state.uploadingPan,
        failed = state.panFailed,
        onClick = onPickPan,
    )

    Spacer(Modifier.height(12.dp))
    UploadRow(
        label = "Trade / qualification certificate",
        done = state.certDocPaths.isNotEmpty(),
        uploading = state.uploadingCert,
        failed = state.certFailed,
        onClick = onPickCertificate,
    )

    Spacer(Modifier.height(14.dp))
    AttestationRow(
        checked = state.attestationAccepted,
        onChange = onAttestationChange,
    )
}

// ---------- UploadRow ----------

@Composable
private fun UploadRow(
    label: String,
    done: Boolean,
    uploading: Boolean,
    failed: Boolean,
    onClick: () -> Unit,
) {
    val borderColor = when {
        failed && !done -> SevaDanger500
        done -> SevaGreen700
        else -> BorderDefault
    }
    val bg = if (done) SevaGreen50 else Color.White
    val shape = RoundedCornerShape(10.dp)

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 8.dp)
            .clip(shape)
            .background(bg)
            .drawBehind {
                val stroke = Stroke(
                    width = 1.5.dp.toPx(),
                    pathEffect = PathEffect.dashPathEffect(
                        floatArrayOf(6.dp.toPx(), 4.dp.toPx()),
                        0f,
                    ),
                )
                val path = Path().apply {
                    addRoundRect(
                        RoundRect(
                            rect = Rect(offset = Offset.Zero, size = Size(size.width, size.height)),
                            cornerRadius = CornerRadius(10.dp.toPx()),
                        ),
                    )
                }
                drawPath(path = path, color = borderColor, style = stroke)
            }
            .clickable(enabled = !uploading) { onClick() }
            .padding(14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Box(
            modifier = Modifier
                .size(36.dp)
                .clip(RoundedCornerShape(8.dp))
                .background(if (done) SevaGreen700 else Paper2),
            contentAlignment = Alignment.Center,
        ) {
            when {
                uploading -> CircularProgressIndicator(
                    modifier = Modifier.size(20.dp),
                    strokeWidth = 2.dp,
                )
                done -> Icon(
                    imageVector = Icons.Filled.Check,
                    contentDescription = null,
                    tint = Color.White,
                    modifier = Modifier.size(18.dp),
                )
                failed -> Icon(
                    imageVector = Icons.Filled.Refresh,
                    contentDescription = null,
                    tint = SevaDanger500,
                    modifier = Modifier.size(18.dp),
                )
                else -> Icon(
                    imageVector = Icons.Outlined.FileUpload,
                    contentDescription = null,
                    tint = SevaInk500,
                    modifier = Modifier.size(18.dp),
                )
            }
        }
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = label,
                fontSize = 13.sp,
                fontWeight = FontWeight.SemiBold,
                color = SevaInk900,
            )
            Spacer(Modifier.height(2.dp))
            val sub = when {
                failed && !done -> "Upload failed · tap to retry"
                done -> "Uploaded · tap to replace"
                else -> "JPG, PNG, or PDF · up to 5 MB"
            }
            Text(
                text = sub,
                fontSize = 11.sp,
                color = when {
                    failed && !done -> SevaDanger500
                    done -> SevaGreen700
                    else -> SevaInk500
                },
            )
        }
    }
}

// ---------- Attestation ----------

@Composable
private fun AttestationRow(
    checked: Boolean,
    onChange: (Boolean) -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(10.dp))
            .clickable { onChange(!checked) }
            .padding(14.dp),
        verticalAlignment = Alignment.Top,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Box(
            modifier = Modifier
                .size(22.dp)
                .clip(RoundedCornerShape(6.dp))
                .background(if (checked) SevaGreen700 else Color.White)
                .border(
                    width = 2.dp,
                    color = if (checked) SevaGreen700 else BorderStrong,
                    shape = RoundedCornerShape(6.dp),
                ),
            contentAlignment = Alignment.Center,
        ) {
            if (checked) {
                Icon(
                    imageVector = Icons.Filled.Check,
                    contentDescription = null,
                    tint = Color.White,
                    modifier = Modifier.size(14.dp),
                )
            }
        }
        Text(
            text = "I confirm the above information is accurate and the documents are mine. False info may lead to permanent ban.",
            fontSize = 12.sp,
            color = SevaInk700,
            lineHeight = 17.sp,
        )
    }
}

// ---------- Section card / labels ----------

@Composable
private fun SectionCard(content: @Composable () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(12.dp))
            .padding(14.dp),
    ) {
        content()
    }
}

@Composable
private fun SubSectionLabel(text: String) {
    Text(
        text = text,
        fontSize = 11.sp,
        fontWeight = FontWeight.SemiBold,
        color = SevaInk500,
        letterSpacing = 0.5.sp,
    )
}

// ---------- Inline error ----------

@Composable
private fun InlineError(text: String) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(SevaWarning50)
            .padding(10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Icon(
            imageVector = Icons.Filled.CheckCircle,
            contentDescription = null,
            tint = SevaWarning500,
            modifier = Modifier.size(16.dp),
        )
        Text(text, fontSize = 12.sp, color = SevaInk700)
    }
}

// ---------- Reupload CTA ----------

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
                "pan" -> "PAN"
                "cert" -> "certificate"
                else -> type
            }
        }
        .ifBlank { null }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(SevaDanger50)
            .padding(16.dp),
    ) {
        Text(
            text = if (flaggedLabel != null) "Re-upload required: $flaggedLabel" else "Your documents were rejected",
            fontSize = 15.sp,
            fontWeight = FontWeight.Bold,
            color = SevaDanger500,
        )
        if (!notes.isNullOrBlank()) {
            Spacer(Modifier.height(6.dp))
            Text(
                text = "Why: $notes",
                fontSize = 13.sp,
                color = SevaInk700,
                fontWeight = FontWeight.Medium,
            )
        }
        Spacer(Modifier.height(8.dp))
        Text(
            text = if (flaggedLabel != null)
                "Tap below to clear flagged docs and re-pick. Approved docs stay as-is."
            else
                "Please re-upload your documents. Your submission will go back into review once saved.",
            fontSize = 13.sp,
            color = SevaInk700,
        )
        Spacer(Modifier.height(10.dp))
        EsBtn(
            text = if (flaggedLabel != null) "Re-upload flagged docs" else "Re-upload documents",
            onClick = onClick,
            kind = EsBtnKind.Danger,
            full = true,
            leading = {
                Icon(
                    imageVector = Icons.Filled.Refresh,
                    contentDescription = null,
                    tint = Color.White,
                    modifier = Modifier.size(16.dp),
                )
            },
        )
    }
}

// ---------- Bottom action bar ----------

@Composable
private fun BottomActionBar(
    state: KycViewModel.UiState,
    onPrevious: () -> Unit,
    onNext: () -> Unit,
    onSubmit: () -> Unit,
) {
    val isLast = state.currentStep.isLast
    val isFirst = state.currentStep.isFirst
    val uploading = state.uploadingAadhaar || state.uploadingCert || state.uploadingPan
    val rejected = state.verificationStatus == VerificationStatus.Rejected
    val submitLabel = if (rejected) "Re-submit for review" else "Submit for review"

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(Color.White)
            .border(width = 1.dp, color = BorderDefault, shape = RoundedCornerShape(0.dp))
            .padding(horizontal = 16.dp, vertical = 12.dp),
        horizontalArrangement = Arrangement.spacedBy(10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (!isFirst) {
            EsBtn(
                text = "Back",
                onClick = onPrevious,
                kind = EsBtnKind.Secondary,
                size = EsBtnSize.Lg,
                disabled = state.saving,
            )
        }
        if (isLast) {
            // Always tappable when not saving / uploading. onSubmit re-runs
            // validation and surfaces the failing reason via a toast.
            EsBtn(
                text = if (state.saving) "Saving…" else submitLabel,
                onClick = onSubmit,
                kind = EsBtnKind.Primary,
                size = EsBtnSize.Lg,
                full = true,
                disabled = state.saving || uploading,
                modifier = Modifier.weight(1f),
            )
        } else {
            // Continue is always tappable so the user can see the validation
            // reason inline (`goToNextStep` toasts the first failure).
            EsBtn(
                text = "Continue",
                onClick = onNext,
                kind = EsBtnKind.Primary,
                size = EsBtnSize.Lg,
                full = true,
                disabled = uploading,
                modifier = Modifier.weight(1f),
            )
        }
    }
}

// ---------- File-picker plumbing (preserved verbatim) ----------

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
