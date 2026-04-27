package com.equipseva.app.features.kyc

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.FileProvider
import coil3.compose.AsyncImage
import java.io.File
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
import androidx.compose.material.icons.filled.CameraAlt
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.Error
import androidx.compose.material.icons.filled.Face
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
import androidx.compose.ui.layout.ContentScale
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
    viewModel: KycViewModel = hiltViewModel(),
) {
    SecureScreen()
    val state by viewModel.state.collectAsStateWithLifecycle()
    val context = LocalContext.current

    LaunchedEffect(viewModel) {
        viewModel.effects.collect { effect ->
            when (effect) {
                is KycViewModel.Effect.ShowMessage -> onShowMessage(effect.text)
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

    // Selfie / face capture flow. We hand the camera a FileProvider URI it
    // can write a JPEG into, then read those bytes back + push to the same
    // KYC docs storage as Aadhaar. Local URI is held in screen state so the
    // composable can show a circle preview after capture without waiting on
    // a signed-URL fetch.
    var selfiePendingUri by remember { mutableStateOf<Uri?>(null) }
    var selfiePreviewUri by remember { mutableStateOf<Uri?>(null) }
    val selfieLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.TakePicture(),
    ) { success ->
        val uri = selfiePendingUri
        if (success && uri != null) {
            val resolver = context.contentResolver
            val mime = resolver.getType(uri) ?: "image/jpeg"
            val bytes = runCatching { resolver.openInputStream(uri)?.use { it.readBytes() } }.getOrNull()
            if (bytes != null) {
                selfiePreviewUri = uri
                viewModel.uploadSelfie(uri.lastPathSegment ?: "selfie.jpg", bytes, mime)
            }
        }
        selfiePendingUri = null
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Verification (KYC)") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.primary,
                    titleContentColor = MaterialTheme.colorScheme.onPrimary,
                    navigationIconContentColor = MaterialTheme.colorScheme.onPrimary,
                ),
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
        containerColor = Surface50,
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
                    onCityChange = viewModel::onCityChange,
                    onStateChange = viewModel::onStateChange,
                    onExperienceChange = viewModel::onExperienceYearsChange,
                    onRadiusChange = viewModel::onServiceRadiusChange,
                    onQualificationDraftChange = viewModel::onQualificationDraftChange,
                    onAddQualification = viewModel::addQualification,
                    onRemoveQualification = viewModel::removeQualification,
                    onToggleSpecialization = viewModel::toggleSpecialization,
                    onAttestationChange = viewModel::onAttestationChange,
                    onPickAadhaar = {
                        aadhaarPicker.launch(
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
                    selfiePreviewUri = selfiePreviewUri,
                    onCaptureSelfie = {
                        // Lay a temp JPEG in cache/kyc-temp/, hand its
                        // FileProvider URI to the camera, remember it so the
                        // result callback can read it back + clean up.
                        val dir = File(context.cacheDir, "kyc-temp").apply { mkdirs() }
                        val target = File(dir, "selfie-${System.currentTimeMillis()}.jpg")
                        val uri = FileProvider.getUriForFile(
                            context,
                            "${context.packageName}.fileprovider",
                            target,
                        )
                        selfiePendingUri = uri
                        selfieLauncher.launch(uri)
                    },
                )
            }
        }
    }
}

@Composable
private fun KycStepperBody(
    state: KycViewModel.UiState,
    onAadhaarNumberChange: (String) -> Unit,
    onCityChange: (String) -> Unit,
    onStateChange: (String) -> Unit,
    onExperienceChange: (String) -> Unit,
    onRadiusChange: (String) -> Unit,
    onQualificationDraftChange: (String) -> Unit,
    onAddQualification: () -> Unit,
    onRemoveQualification: (String) -> Unit,
    onToggleSpecialization: (RepairEquipmentCategory) -> Unit,
    onAttestationChange: (Boolean) -> Unit,
    onPickAadhaar: () -> Unit,
    onPickCertificate: () -> Unit,
    onStartReupload: () -> Unit,
    onJumpToStep: (KycStep) -> Unit,
    onEmailDraftChange: (String) -> Unit,
    onSaveEmail: () -> Unit,
    onAddPhone: () -> Unit,
    selfiePreviewUri: Uri?,
    onCaptureSelfie: () -> Unit,
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
            submitted = state.aadhaarVerified,
        )

        StatusBanner(status = state.verificationStatus, aadhaarVerified = state.aadhaarVerified)

        if (verified) {
            // Verified engineers see a celebratory summary instead of the wizard.
            VerifiedSummaryCard(state = state)
            return@Column
        }

        if (state.verificationStatus == VerificationStatus.Rejected) {
            ReuploadCta(onClick = onStartReupload)
        }

        StepHeader(current = state.currentStep, onJump = onJumpToStep)

        // Per-step body. Each step renders only what's relevant to that step
        // so the form feels short — best-practice gig-app onboarding caps each
        // step at ~30 seconds of input.
        when (state.currentStep) {
            KycStep.Identity -> IdentityStep(
                state = state,
                onCityChange = onCityChange,
                onStateChange = onStateChange,
                onEmailDraftChange = onEmailDraftChange,
                onSaveEmail = onSaveEmail,
                onAddPhone = onAddPhone,
            )
            KycStep.Aadhaar -> AadhaarStep(
                state = state,
                onAadhaarNumberChange = onAadhaarNumberChange,
                onPickAadhaar = onPickAadhaar,
            )
            KycStep.Selfie -> SelfieStep(
                state = state,
                previewUri = selfiePreviewUri,
                onCaptureSelfie = onCaptureSelfie,
            )
            KycStep.Skills -> SkillsStep(
                state = state,
                onExperienceChange = onExperienceChange,
                onRadiusChange = onRadiusChange,
                onToggleSpecialization = onToggleSpecialization,
                onQualificationDraftChange = onQualificationDraftChange,
                onAddQualification = onAddQualification,
                onRemoveQualification = onRemoveQualification,
            )
            KycStep.Credentials -> CredentialsStep(
                state = state,
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
private fun IdentityStep(
    state: KycViewModel.UiState,
    onCityChange: (String) -> Unit,
    onStateChange: (String) -> Unit,
    onEmailDraftChange: (String) -> Unit,
    onSaveEmail: () -> Unit,
    onAddPhone: () -> Unit,
) {
    KycSectionCard(title = "How hospitals reach you") {
        ReadOnlyContactRow(icon = Icons.Filled.Badge, label = "Name", value = state.fullName ?: "—")

        // Phone — read-only display + Add/Change button. Tapping fires the
        // OTP-add flow (covers Google-auth users who never went through phone
        // OTP at signup). Phone changes always require OTP.
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
            modifier = Modifier.fillMaxWidth(),
        ) {
            Icon(
                imageVector = Icons.Filled.Phone,
                contentDescription = null,
                tint = if (state.phone.isNullOrBlank()) Warning else BrandGreen,
                modifier = Modifier.size(18.dp),
            )
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    "Phone${if (!state.phone.isNullOrBlank()) " (verified)" else ""}",
                    fontSize = 11.sp,
                    color = Ink500,
                    fontWeight = FontWeight.SemiBold,
                )
                Text(
                    text = state.phone ?: "Not added yet",
                    fontSize = 13.sp,
                    color = if (state.phone.isNullOrBlank()) Warning else Ink900,
                    fontWeight = FontWeight.SemiBold,
                )
            }
            OutlinedButton(
                onClick = onAddPhone,
                contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 12.dp, vertical = 6.dp),
            ) {
                Text(if (state.phone.isNullOrBlank()) "Add" else "Change", fontSize = 12.sp)
            }
        }

        // Email — inline editable. Supabase fires a confirmation link to the
        // new address; the row stays as-is until the user clicks the link.
        OutlinedTextField(
            value = state.emailDraft,
            onValueChange = onEmailDraftChange,
            label = { Text("Email") },
            singleLine = true,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email),
            enabled = !state.savingEmail,
            supportingText = {
                Text(
                    text = if (state.email.isNullOrBlank())
                        "Add the email hospitals can reach you at."
                    else
                        "Editing sends a confirmation link to the new address.",
                    fontSize = 11.sp,
                )
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
            text = "Once you're verified, hospitals can Call / WhatsApp / Email you straight from your profile.",
            fontSize = 12.sp,
            color = Ink500,
        )
    }
    KycSectionCard(title = "Where you operate") {
        OutlinedTextField(
            value = state.city,
            onValueChange = onCityChange,
            label = { Text("City") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
        )
        OutlinedTextField(
            value = state.state,
            onValueChange = onStateChange,
            label = { Text("State") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
        )
    }
}

@Composable
private fun AadhaarStep(
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

    KycSectionCard(title = "Aadhaar number") {
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
    }

    KycSectionCard(title = "Aadhaar document") {
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
        Text(
            text = "We accept e-Aadhaar PDFs or a clear photo of the printed card (JPEG/PNG/WebP).",
            fontSize = 11.sp,
            color = Ink500,
        )
    }
}

@Composable
private fun SelfieStep(
    state: KycViewModel.UiState,
    previewUri: Uri?,
    onCaptureSelfie: () -> Unit,
) {
    val uploaded = !state.selfieDocPath.isNullOrBlank()
    val uploading = state.uploadingSelfie
    val failed = state.selfieFailed && !uploaded && !uploading
    KycSectionCard(title = "Take a selfie") {
        // Big circle preview. Three states: nothing yet (camera icon
        // placeholder on AccentLimeSoft), uploaded with a local URI we can
        // render via Coil, uploaded but no local URI (returning user) →
        // green check confirmation.
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = Spacing.sm),
            contentAlignment = Alignment.Center,
        ) {
            Box(
                modifier = Modifier
                    .size(168.dp)
                    .clip(CircleShape)
                    .background(if (uploaded) Surface0 else Surface50)
                    .border(
                        width = 2.dp,
                        color = when {
                            failed -> ErrorRed
                            uploaded -> Success
                            else -> Surface200
                        },
                        shape = CircleShape,
                    ),
                contentAlignment = Alignment.Center,
            ) {
                when {
                    previewUri != null -> AsyncImage(
                        model = previewUri,
                        contentDescription = "Your selfie",
                        modifier = Modifier
                            .size(164.dp)
                            .clip(CircleShape),
                        contentScale = ContentScale.Crop,
                    )
                    uploaded -> Icon(
                        imageVector = Icons.Filled.CheckCircle,
                        contentDescription = "Selfie uploaded",
                        tint = Success,
                        modifier = Modifier.size(56.dp),
                    )
                    uploading -> CircularProgressIndicator(
                        modifier = Modifier.size(40.dp),
                        strokeWidth = 3.dp,
                    )
                    else -> Icon(
                        imageVector = Icons.Filled.Face,
                        contentDescription = null,
                        tint = Ink500,
                        modifier = Modifier.size(80.dp),
                    )
                }
            }
        }

        val (label, color) = when {
            failed -> "Upload failed — try again" to ErrorRed
            uploaded -> "✓ Looks good" to Success
            uploading -> "Uploading…" to Ink500
            else -> "We'll share this only with our admin team for KYC review." to Ink500
        }
        Text(
            text = label,
            fontSize = 13.sp,
            color = color,
            fontWeight = if (uploaded || failed) FontWeight.SemiBold else FontWeight.Normal,
        )

        Button(
            onClick = onCaptureSelfie,
            enabled = !uploading,
            modifier = Modifier.fillMaxWidth(),
        ) {
            Icon(
                imageVector = Icons.Filled.CameraAlt,
                contentDescription = null,
                modifier = Modifier.size(18.dp),
            )
            Spacer(Modifier.size(Spacing.sm))
            Text(
                text = when {
                    uploading -> "Uploading…"
                    uploaded -> "Retake selfie"
                    else -> "Take selfie"
                },
            )
        }
    }
    KycSectionCard(title = "How to get a clean shot") {
        SelfieTipRow(text = "Face the camera straight, no angles.")
        SelfieTipRow(text = "Good light — face the window, not your back.")
        SelfieTipRow(text = "No mask, hat, or sunglasses.")
        SelfieTipRow(text = "Match the photo on your Aadhaar — admin compares both.")
    }
}

@Composable
private fun SelfieTipRow(text: String) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Icon(Icons.Filled.Check, contentDescription = null, tint = BrandGreen, modifier = Modifier.size(14.dp))
        Text(text, fontSize = 13.sp, color = Ink700)
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun SkillsStep(
    state: KycViewModel.UiState,
    onExperienceChange: (String) -> Unit,
    onRadiusChange: (String) -> Unit,
    onToggleSpecialization: (RepairEquipmentCategory) -> Unit,
    onQualificationDraftChange: (String) -> Unit,
    onAddQualification: () -> Unit,
    onRemoveQualification: (String) -> Unit,
) {
    KycSectionCard(title = "What you fix") {
        FlowRow(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
        ) {
            RepairEquipmentCategory.entries.forEach { category ->
                val selected = category in state.selectedSpecializations
                FilterChip(
                    selected = selected,
                    onClick = { onToggleSpecialization(category) },
                    label = { Text(category.displayName) },
                    leadingIcon = if (selected) {
                        { Icon(Icons.Filled.Check, contentDescription = null) }
                    } else null,
                )
            }
        }
        Text(
            text = "Pick every category you'd accept jobs for. Hospitals filter the directory by these.",
            fontSize = 11.sp,
            color = Ink500,
        )
    }

    KycSectionCard(title = "Experience & coverage") {
        OutlinedTextField(
            value = state.experienceYears,
            onValueChange = onExperienceChange,
            label = { Text("Years of experience (0–50)") },
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
        )
        OutlinedTextField(
            value = state.serviceRadiusKm,
            onValueChange = onRadiusChange,
            label = { Text("Service radius (km, 1–500)") },
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
            singleLine = true,
            supportingText = { Text("How far you'll travel for a job from your city.", fontSize = 12.sp) },
            modifier = Modifier.fillMaxWidth(),
        )
    }

    KycSectionCard(title = "Qualifications (optional)") {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
            modifier = Modifier.fillMaxWidth(),
        ) {
            OutlinedTextField(
                value = state.qualificationDraft,
                onValueChange = onQualificationDraftChange,
                label = { Text("Add qualification (e.g. BE Biomedical)") },
                singleLine = true,
                modifier = Modifier.weight(1f),
            )
            OutlinedButton(onClick = onAddQualification) {
                Icon(Icons.Filled.Check, contentDescription = "Add")
            }
        }
        if (state.qualifications.isNotEmpty()) {
            FlowRow(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
            ) {
                state.qualifications.forEach { q ->
                    AssistChip(
                        onClick = { onRemoveQualification(q) },
                        label = { Text(q) },
                        colors = AssistChipDefaults.assistChipColors(
                            containerColor = MaterialTheme.colorScheme.secondaryContainer,
                            labelColor = MaterialTheme.colorScheme.onSecondaryContainer,
                        ),
                    )
                }
            }
        }
    }
}

@Composable
private fun CredentialsStep(
    state: KycViewModel.UiState,
    onPickCertificate: () -> Unit,
    onAttestationChange: (Boolean) -> Unit,
) {
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
            Checkbox(
                checked = state.attestationAccepted,
                onCheckedChange = onAttestationChange,
            )
            Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(
                    text = "I confirm that the documents and details above are mine.",
                    fontSize = 13.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = Ink900,
                )
                Text(
                    text = "Submitting fake or borrowed documents will get your account permanently banned and reported.",
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
private fun StatusBanner(status: VerificationStatus, aadhaarVerified: Boolean) {
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
        VerificationStatus.Pending -> if (aadhaarVerified) {
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
private fun ReuploadCta(onClick: () -> Unit) {
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
                text = "Your documents were rejected",
                fontSize = 15.sp,
                fontWeight = FontWeight.Bold,
                color = ErrorRed,
            )
            Text(
                text = "Please re-upload your Aadhaar and qualification certificate. Your submission will go back into review once saved.",
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
                Text("Re-upload documents")
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
