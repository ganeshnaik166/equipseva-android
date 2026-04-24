package com.equipseva.app.features.kyc

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Badge
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.Error
import androidx.compose.material.icons.filled.HourglassTop
import androidx.compose.material.icons.filled.Verified
import androidx.compose.material.icons.filled.WorkspacePremium
import androidx.compose.material.icons.outlined.CloudUpload
import androidx.compose.material3.AssistChip
import androidx.compose.material3.AssistChipDefaults
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
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
import com.equipseva.app.designsystem.components.AppProgress
import com.equipseva.app.designsystem.components.GradientTile
import com.equipseva.app.designsystem.components.SecureScreen
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

    val aadhaarPicker = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.PickVisualMedia(),
    ) { uri: Uri? ->
        uri?.let { readAndUpload(context, it) { name, bytes, mime -> viewModel.uploadAadhaarDoc(name, bytes, mime) } }
    }

    val certPicker = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.OpenDocument(),
    ) { uri: Uri? ->
        uri?.let { readAndUpload(context, it) { name, bytes, mime -> viewModel.uploadCertificate(name, bytes, mime) } }
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
            KycBottomBar(
                status = state.verificationStatus,
                aadhaarUploaded = !state.aadhaarDocPath.isNullOrBlank(),
                certUploaded = state.certDocPaths.isNotEmpty(),
                saving = state.saving,
                onSave = viewModel::save,
            )
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
                else -> KycForm(
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
                    onPickAadhaar = {
                        aadhaarPicker.launch(
                            PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly),
                        )
                    },
                    onPickCertificate = {
                        certPicker.launch(arrayOf("application/pdf", "image/jpeg", "image/png", "image/webp"))
                    },
                )
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun KycForm(
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
    onPickAadhaar: () -> Unit,
    onPickCertificate: () -> Unit,
) {
    val aadhaarUploaded = !state.aadhaarDocPath.isNullOrBlank()
    val certUploaded = state.certDocPaths.isNotEmpty()
    // Required doc count: Aadhaar, Certificate (represents trade/qualification + profile verification).
    // Using a 2-doc required model reflecting what the KycViewModel actually tracks.
    val required = 2
    val uploadedCount = listOf(aadhaarUploaded, certUploaded).count { it }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(Spacing.lg),
        verticalArrangement = Arrangement.spacedBy(Spacing.lg),
    ) {
        StatusBanner(status = state.verificationStatus, aadhaarVerified = state.aadhaarVerified)

        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            AppProgress(value = uploadedCount, total = required)
            Text(
                text = "$uploadedCount of $required required documents",
                fontSize = 12.sp,
                color = Ink500,
            )
        }

        // Document upload list per design.
        Column(verticalArrangement = Arrangement.spacedBy(Spacing.sm)) {
            DocumentRow(
                title = "Aadhaar card",
                uploaded = aadhaarUploaded,
                uploading = state.uploadingAadhaar,
                icon = Icons.Filled.Badge,
                hue = 150,
                onClick = onPickAadhaar,
            )
            DocumentRow(
                title = "Trade / qualification certificate",
                uploaded = certUploaded,
                uploading = state.uploadingCert,
                icon = Icons.Filled.WorkspacePremium,
                hue = 280,
                subtitleOverride = if (certUploaded) {
                    "Uploaded (${state.certDocPaths.size})"
                } else null,
                onClick = onPickCertificate,
            )
        }

        // Keep existing form sections (identity / qualifications / specializations / service area).
        // These preserve the ViewModel contract while rendering in a cleaner card style.
        KycSectionCard(title = "Identity details") {
            OutlinedTextField(
                value = state.aadhaarNumber,
                onValueChange = onAadhaarNumberChange,
                label = { Text("Aadhaar number (12 digits)") },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.NumberPassword),
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
            )
        }

        KycSectionCard(title = "Qualifications & experience") {
            OutlinedTextField(
                value = state.experienceYears,
                onValueChange = onExperienceChange,
                label = { Text("Years of experience") },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
            )
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
                    Icon(Icons.Filled.Check, contentDescription = null)
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

        KycSectionCard(title = "Specializations") {
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
                        } else {
                            null
                        },
                    )
                }
            }
        }

        KycSectionCard(title = "Service area") {
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
            OutlinedTextField(
                value = state.serviceRadiusKm,
                onValueChange = onRadiusChange,
                label = { Text("Service radius (km)") },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
            )
        }

        Spacer(Modifier.height(Spacing.sm))
    }
}

@Composable
private fun StatusBanner(status: VerificationStatus, aadhaarVerified: Boolean) {
    // Map domain statuses to the design's banner palette.
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
                subtitle = "Typically takes 24 hours.",
                icon = Icons.Filled.HourglassTop,
            )
        } else {
            BannerStyle(
                bg = WarningBg,
                fg = Warning,
                label = "In progress",
                subtitle = "Upload required documents to continue.",
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
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = fg,
            modifier = Modifier.size(24.dp),
        )
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                text = label,
                fontSize = 14.sp,
                fontWeight = FontWeight.Bold,
                color = fg,
            )
            Text(
                text = subtitle,
                fontSize = 13.sp,
                color = Ink700,
            )
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
private fun DocumentRow(
    title: String,
    uploaded: Boolean,
    uploading: Boolean,
    icon: ImageVector,
    hue: Int,
    subtitleOverride: String? = null,
    onClick: (() -> Unit)?,
) {
    Card(
        colors = CardDefaults.cardColors(containerColor = Surface0),
        border = androidx.compose.foundation.BorderStroke(1.dp, Surface200),
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
                Text(
                    text = title,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Bold,
                    color = Ink900,
                )
                val subtitle = subtitleOverride ?: if (uploaded) "✓ Uploaded" else "Required"
                Text(
                    text = subtitle,
                    fontSize = 12.sp,
                    color = if (uploaded) Success else Ink500,
                )
            }
            if (onClick != null) {
                if (uploading) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(24.dp),
                        strokeWidth = 2.dp,
                    )
                } else if (uploaded) {
                    OutlinedButton(
                        onClick = onClick,
                        contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 12.dp, vertical = 6.dp),
                    ) {
                        Text("Replace", fontSize = 13.sp)
                    }
                } else {
                    Button(
                        onClick = onClick,
                        contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 12.dp, vertical = 6.dp),
                    ) {
                        Icon(
                            Icons.Outlined.CloudUpload,
                            contentDescription = null,
                            modifier = Modifier.size(16.dp),
                        )
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
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = Ink500,
            modifier = Modifier.size(24.dp),
        )
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
private fun KycBottomBar(
    status: VerificationStatus,
    aadhaarUploaded: Boolean,
    certUploaded: Boolean,
    saving: Boolean,
    onSave: () -> Unit,
) {
    val allUploaded = aadhaarUploaded && certUploaded
    val label = when {
        status == VerificationStatus.Verified -> "Verified"
        status == VerificationStatus.Pending && aadhaarUploaded && certUploaded -> "Submit for review"
        else -> "Submit for review"
    }
    val enabled = !saving && allUploaded && status != VerificationStatus.Verified
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .background(Surface0)
            .border(width = 1.dp, color = Surface200, shape = RoundedCornerShape(0.dp))
            .padding(Spacing.lg),
    ) {
        Button(
            onClick = onSave,
            enabled = enabled,
            modifier = Modifier
                .fillMaxWidth()
                .height(Spacing.MinTouchTarget),
            colors = ButtonDefaults.buttonColors(),
        ) {
            if (saving) {
                CircularProgressIndicator(
                    modifier = Modifier.size(18.dp),
                    strokeWidth = 2.dp,
                    color = Color.White,
                )
                Spacer(Modifier.size(Spacing.sm))
                Text("Saving…")
            } else {
                Text(label)
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
