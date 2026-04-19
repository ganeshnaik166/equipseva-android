package com.equipseva.app.features.kyc

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
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
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.CloudUpload
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.PhotoCamera
import androidx.compose.material3.AssistChip
import androidx.compose.material3.AssistChipDefaults
import androidx.compose.material3.Button
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
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.core.data.engineers.VerificationStatus
import com.equipseva.app.core.data.repair.RepairEquipmentCategory
import com.equipseva.app.designsystem.theme.Spacing
import androidx.compose.foundation.text.KeyboardOptions

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun KycScreen(
    onBack: () -> Unit,
    onShowMessage: (String) -> Unit,
    viewModel: KycViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val context = LocalContext.current

    LaunchedEffect(viewModel) {
        viewModel.effects.collect { effect ->
            when (effect) {
                is KycViewModel.Effect.ShowMessage -> onShowMessage(effect.text)
                KycViewModel.Effect.Saved -> Unit
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
                title = { Text("Verification") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
            )
        },
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
                    onSave = viewModel::save,
                )
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
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
    onSave: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(Spacing.lg),
        verticalArrangement = Arrangement.spacedBy(Spacing.lg),
    ) {
        VerificationStatusChip(
            status = state.verificationStatus,
            aadhaarVerified = state.aadhaarVerified,
        )

        SectionCard(title = "Identity") {
            OutlinedTextField(
                value = state.aadhaarNumber,
                onValueChange = onAadhaarNumberChange,
                label = { Text("Aadhaar number (12 digits)") },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.NumberPassword),
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
            )
            UploadRow(
                label = if (state.aadhaarDocPath != null) "Aadhaar photo uploaded" else "Upload aadhaar photo",
                uploaded = state.aadhaarDocPath != null,
                loading = state.uploadingAadhaar,
                icon = Icons.Filled.PhotoCamera,
                onClick = onPickAadhaar,
            )
        }

        SectionCard(title = "Qualifications & experience") {
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
            UploadRow(
                label = if (state.certDocPaths.isNotEmpty()) {
                    "Certificates uploaded (${state.certDocPaths.size})"
                } else {
                    "Upload certificate (PDF/image)"
                },
                uploaded = state.certDocPaths.isNotEmpty(),
                loading = state.uploadingCert,
                icon = Icons.Filled.Description,
                onClick = onPickCertificate,
            )
        }

        SectionCard(title = "Specializations") {
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

        SectionCard(title = "Service area") {
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

        Button(
            onClick = onSave,
            enabled = !state.saving,
            modifier = Modifier.fillMaxWidth(),
        ) {
            if (state.saving) {
                CircularProgressIndicator(
                    modifier = Modifier.size(18.dp),
                    strokeWidth = 2.dp,
                )
                Spacer(Modifier.size(Spacing.sm))
                Text("Saving…")
            } else {
                Text("Save verification details")
            }
        }

        Spacer(Modifier.height(Spacing.md))
    }
}

@Composable
private fun VerificationStatusChip(status: VerificationStatus, aadhaarVerified: Boolean) {
    val (container, content) = when (status) {
        VerificationStatus.Verified -> MaterialTheme.colorScheme.primaryContainer to
            MaterialTheme.colorScheme.onPrimaryContainer
        VerificationStatus.Rejected -> MaterialTheme.colorScheme.errorContainer to
            MaterialTheme.colorScheme.onErrorContainer
        VerificationStatus.Pending -> MaterialTheme.colorScheme.tertiaryContainer to
            MaterialTheme.colorScheme.onTertiaryContainer
    }
    Card(
        colors = CardDefaults.cardColors(containerColor = container),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(
            modifier = Modifier.padding(Spacing.lg),
            verticalArrangement = Arrangement.spacedBy(Spacing.xxs),
        ) {
            Text(
                "Verification status",
                style = MaterialTheme.typography.labelMedium,
                color = content,
            )
            Text(
                status.displayName,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
                color = content,
            )
            Text(
                if (aadhaarVerified) "Aadhaar verified" else "Aadhaar not yet verified",
                style = MaterialTheme.typography.bodySmall,
                color = content,
            )
        }
    }
}

@Composable
private fun SectionCard(title: String, content: @Composable () -> Unit) {
    Card(
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(
            modifier = Modifier.padding(Spacing.lg),
            verticalArrangement = Arrangement.spacedBy(Spacing.md),
        ) {
            Text(
                title,
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            content()
        }
    }
}

@Composable
private fun UploadRow(
    label: String,
    uploaded: Boolean,
    loading: Boolean,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    onClick: () -> Unit,
) {
    OutlinedButton(
        onClick = onClick,
        enabled = !loading,
        modifier = Modifier.fillMaxWidth(),
    ) {
        if (loading) {
            CircularProgressIndicator(
                modifier = Modifier.size(18.dp),
                strokeWidth = 2.dp,
            )
        } else {
            Icon(if (uploaded) Icons.Filled.Check else icon, contentDescription = null)
        }
        Spacer(Modifier.size(Spacing.sm))
        Text(label)
        Spacer(Modifier.weight(1f))
        if (!loading && !uploaded) {
            Icon(Icons.Filled.CloudUpload, contentDescription = null)
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
