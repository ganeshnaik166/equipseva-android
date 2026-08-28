package com.equipseva.app.features.hospital

import android.Manifest
import android.content.pm.PackageManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat
import android.graphics.Bitmap
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.PhotoCamera
import androidx.compose.material.icons.filled.PhotoLibrary
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.outlined.Flag
import androidx.compose.material.icons.outlined.PriorityHigh
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.R
import com.equipseva.app.core.data.repair.RepairEquipmentCategory
import com.equipseva.app.core.data.repair.RepairJobUrgency
import com.equipseva.app.core.util.MIME_JPEG
import com.equipseva.app.designsystem.components.Avatar
import com.equipseva.app.designsystem.components.ESBackTopBar
import com.equipseva.app.designsystem.components.ErrorBanner
import com.equipseva.app.designsystem.components.EsBtn
import com.equipseva.app.designsystem.components.EsBtnKind
import com.equipseva.app.designsystem.components.EsBtnSize
import com.equipseva.app.designsystem.theme.BrandGreen
import com.equipseva.app.designsystem.theme.BrandGreen50
import com.equipseva.app.designsystem.theme.BrandGreenDark
import com.equipseva.app.designsystem.theme.ErrorRed
import com.equipseva.app.designsystem.theme.Ink700
import com.equipseva.app.designsystem.theme.Ink900
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.designsystem.theme.Success
import com.equipseva.app.designsystem.theme.Surface200
import com.equipseva.app.designsystem.theme.Warning
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RequestServiceScreen(
    onBack: () -> Unit,
    onSubmitted: (jobId: String?, jobNumber: String?) -> Unit,
    onShowMessage: (String) -> Unit,
    viewModel: RequestServiceViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    // v0.2.0 booking flow: single form, no wizard. The user lands here
    // from the engineer card on the directory and submits the full
    // request in one shot. `selectedSlot` is the only remaining
    // multi-step legacy — kept because the When section uses tiles
    // (one of 4 presets, or Custom + DatePicker) rather than free text.
    var selectedSlot by rememberSaveable { mutableIntStateOf(-1) }

    val context = androidx.compose.ui.platform.LocalContext.current
    val scope = androidx.compose.runtime.rememberCoroutineScope()

    // Camera capture (preview-resolution thumbnail). Encoded to JPEG bytes
    // before handing to the VM so the upload payload is consistent.
    //
    // CAMERA is declared in AndroidManifest, so the system camera intent
    // backing TakePicturePreview returns a null bitmap when the runtime
    // grant is missing. Gate the launch on a permission request and only
    // open the picker after the user grants the permission.
    val cameraLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.TakePicturePreview(),
    ) { bitmap: Bitmap? ->
        if (bitmap != null) {
            val bytes = java.io.ByteArrayOutputStream().use { stream ->
                bitmap.compress(Bitmap.CompressFormat.JPEG, 90, stream)
                stream.toByteArray()
            }
            viewModel.onPhotoPicked(
                fileName = "camera-${System.currentTimeMillis()}.jpg",
                bytes = bytes,
                contentType = MIME_JPEG,
            )
        }
    }
    val cameraPermissionLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestPermission(),
    ) { granted ->
        if (granted) {
            cameraLauncher.launch(null)
        } else {
            onShowMessage("Camera permission denied")
        }
    }
    val onRequestCamera: () -> Unit = {
        val granted = ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.CAMERA,
        ) == PackageManager.PERMISSION_GRANTED
        if (granted) {
            cameraLauncher.launch(null)
        } else {
            cameraPermissionLauncher.launch(Manifest.permission.CAMERA)
        }
    }

    // Gallery pick (image/* only).
    val galleryLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.PickVisualMedia(),
    ) { uri: android.net.Uri? ->
        if (uri != null) {
            // Round 340 — launcher callbacks run on Main. Reading a multi-MB
            // gallery image with readBytes() on Main is ANR-prone on low-end
            // devices. Push the read off to IO.
            scope.launch(kotlinx.coroutines.Dispatchers.IO) {
                val cr = context.contentResolver
                val mime = cr.getType(uri) ?: MIME_JPEG
                val bytes = cr.openInputStream(uri)?.use { it.readBytes() }
                val fileName = uri.lastPathSegment ?: "gallery-${System.currentTimeMillis()}"
                if (bytes != null) {
                    viewModel.onPhotoPicked(fileName, bytes, mime)
                }
            }
        }
    }

    LaunchedEffect(viewModel) {
        viewModel.effects.collect { effect ->
            when (effect) {
                is RequestServiceViewModel.Effect.Submitted -> {
                    onSubmitted(effect.jobId, effect.jobNumber)
                }
                is RequestServiceViewModel.Effect.ShowMessage -> {
                    onShowMessage(effect.text)
                }
            }
        }
    }

    // Single derived flag — all four legacy step gates rolled into one
    // so the bottom Submit can disable until the user has filled the
    // minimum-valid payload. The submit handler still enforces
    // issue+address as defense-in-depth on the way out.
    val canSubmit = state.brand.isNotBlank() &&
        state.model.isNotBlank() &&
        state.issue.trim().length >= 10 &&
        (selectedSlot in 0..3 || (selectedSlot == 4 && state.pickedDateMillis != null)) &&
        !state.submitting &&
        !state.uploadingPhoto

    Scaffold(
        topBar = {
            Column {
                ESBackTopBar(
                    title = "Request service",
                    onBack = onBack,
                )
                // Round 471 — draft recovery sticky bar. Shown when the
                // ViewModel detected a saved draft from a prior session;
                // tapping Keep restores all fields, Discard wipes it.
                if (state.showDraftRecoveryBar) {
                    DraftRecoveryBar(
                        onKeep = viewModel::onKeepDraft,
                        onDiscard = viewModel::onDiscardDraft,
                    )
                }
            }
        },
        bottomBar = {
            SubmitBar(
                submitting = state.submitting,
                uploadingPhoto = state.uploadingPhoto,
                canSubmit = canSubmit,
                onSubmit = { viewModel.onSubmit(selectedSlot) },
            )
        },
    ) { inner ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(inner)
                .background(MaterialTheme.colorScheme.surface),
        ) {
            ErrorBanner(
                message = state.errorMessage,
                modifier = Modifier.padding(horizontal = Spacing.lg, vertical = Spacing.sm),
            )
            // v0.2.0 booking flow: every field on one scrollable
            // surface. The user picked an engineer on the previous
            // screen; this page is everything they need to fill in
            // before Submit. The section labels carry the visual
            // load that the HorizontalStepper used to.
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = Spacing.lg)
                    .padding(bottom = Spacing.xl),
                verticalArrangement = Arrangement.spacedBy(Spacing.md),
            ) {
                // v0.3.5 fix #9 — engineer reassurance header. Rendered
                // only when the screen was opened from a Book-again CTA
                // (engineerId was passed in the route + fetchPublicProfile
                // resolved a name). Shows the chosen engineer's name,
                // rating, and total completed jobs so the hospital keeps
                // confidence through what is otherwise a generic form.
                if (state.prefilledEngineerName != null) {
                    EngineerReassuranceHeader(
                        name = state.prefilledEngineerName!!,
                        rating = state.prefilledEngineerRating,
                        jobCount = state.prefilledEngineerJobCount,
                    )
                }
                StepEquipment(
                    category = state.category,
                    brand = state.brand,
                    model = state.model,
                    serial = state.serial,
                    onCategory = viewModel::onCategoryChange,
                    onBrand = viewModel::onBrandChange,
                    onModel = viewModel::onModelChange,
                    onSerial = viewModel::onSerialChange,
                )
                SectionDivider()
                StepIssue(
                    issue = state.issue,
                    issueError = state.issueError,
                    urgency = state.urgency,
                    photos = state.photos,
                    uploadingPhoto = state.uploadingPhoto,
                    onIssue = viewModel::onIssueChange,
                    onUrgency = viewModel::onUrgencyChange,
                    onTakePhoto = onRequestCamera,
                    onPickFromGallery = {
                        galleryLauncher.launch(
                            PickVisualMediaRequest(
                                ActivityResultContracts.PickVisualMedia.ImageOnly,
                            ),
                        )
                    },
                    onRemovePhoto = viewModel::onRemovePhoto,
                )
                SectionDivider()
                StepWhen(
                    selectedSlot = selectedSlot,
                    onSelectSlot = { selectedSlot = it },
                    pickedDateMillis = state.pickedDateMillis,
                    onPickedDateChange = viewModel::onPickedDateChange,
                )
                SectionDivider()
                StepWhere(
                    siteAddress = state.siteAddress,
                    siteAddressError = state.siteAddressError,
                    onSiteAddress = viewModel::onSiteAddressChange,
                    siteLocation = state.siteLocation,
                    onSiteLocation = viewModel::onSiteLocationChange,
                    siteLatitude = state.siteLatitude,
                    siteLongitude = state.siteLongitude,
                    onSiteCoords = viewModel::onSiteCoordsChange,
                    budget = state.budget,
                    budgetError = state.budgetError,
                    onBudget = viewModel::onBudgetChange,
                )
            }
        }
    }
}

/**
 * v0.3.5 fix #9 — engineer reassurance header shown above the booking
 * form when the screen was opened from a Book-again CTA. Star icon +
 * avatar with initials + name + (rating ✕ jobs) summary. Sits inside
 * the regular scroll surface (above StepEquipment) so it scrolls with
 * the form rather than living in the top bar.
 */
@Composable
private fun EngineerReassuranceHeader(
    name: String,
    rating: Double?,
    jobCount: Int,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(BrandGreen50)
            .border(1.dp, BrandGreen, RoundedCornerShape(12.dp))
            .padding(horizontal = Spacing.md, vertical = Spacing.sm),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
    ) {
        Icon(
            imageVector = Icons.Filled.Star,
            contentDescription = null,
            tint = BrandGreenDark,
            modifier = Modifier.size(20.dp),
        )
        val initials = name
            .split(" ")
            .mapNotNull { it.firstOrNull()?.toString() }
            .joinToString("")
            .ifBlank { "E" }
        Avatar(initials = initials, size = 36.dp)
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = stringResource(R.string.request_service_booking_name, name),
                fontSize = 14.sp,
                fontWeight = FontWeight.SemiBold,
                color = Ink900,
            )
            val ratingLabel = rating?.takeIf { it > 0.0 }
                ?.let { String.format(java.util.Locale.ENGLISH, "%.1f ★", it) }
                ?: "New"
            val jobsLabel = if (jobCount == 1) "1 job" else "$jobCount jobs"
            Text(
                text = stringResource(R.string.request_service_rating_jobs_summary, ratingLabel, jobsLabel),
                fontSize = 12.sp,
                color = Ink700,
            )
        }
    }
}

@Composable
private fun DraftRecoveryBar(
    onKeep: () -> Unit,
    onDiscard: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(BrandGreen50)
            .border(0.5.dp, BrandGreen)
            .padding(horizontal = Spacing.md, vertical = Spacing.sm),
        horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = stringResource(R.string.request_service_resume_draft),
            fontSize = 13.sp,
            fontWeight = FontWeight.Medium,
            color = BrandGreenDark,
            modifier = Modifier.weight(1f),
        )
        EsBtn(
            text = "Keep",
            onClick = onKeep,
            kind = EsBtnKind.Primary,
            size = EsBtnSize.Sm,
        )
        EsBtn(
            text = "Discard",
            onClick = onDiscard,
            kind = EsBtnKind.Secondary,
            size = EsBtnSize.Sm,
        )
    }
}

@Composable
private fun SectionDivider() {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(1.dp)
            .background(Surface200)
            .padding(vertical = Spacing.md),
    )
}

@Composable
private fun SubmitBar(
    submitting: Boolean,
    uploadingPhoto: Boolean,
    canSubmit: Boolean,
    onSubmit: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(MaterialTheme.colorScheme.surface)
            .border(1.dp, Surface200)
            .padding(Spacing.lg),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Button(
            onClick = onSubmit,
            enabled = canSubmit,
            modifier = Modifier
                .fillMaxWidth()
                .height(Spacing.MinTouchTarget),
            colors = ButtonDefaults.buttonColors(
                containerColor = MaterialTheme.colorScheme.primary,
                contentColor = MaterialTheme.colorScheme.onPrimary,
            ),
        ) {
            Icon(Icons.Filled.Check, contentDescription = null, modifier = Modifier.size(18.dp))
            Spacer(Modifier.width(6.dp))
            Text(
                when {
                    submitting -> stringResource(R.string.request_service_submitting)
                    uploadingPhoto -> stringResource(R.string.request_service_uploading_photo)
                    else -> stringResource(R.string.request_service_submit_request)
                },
            )
        }
    }
}

@Composable
private fun StepHeadline(text: String) {
    Text(
        text = text,
        fontSize = 24.sp,
        lineHeight = 30.sp,
        fontWeight = FontWeight.Bold,
        color = Ink900,
        modifier = Modifier.padding(top = 4.dp, bottom = 4.dp),
    )
}

@OptIn(androidx.compose.foundation.layout.ExperimentalLayoutApi::class)
@Composable
private fun StepEquipment(
    category: RepairEquipmentCategory,
    brand: String,
    model: String,
    serial: String,
    onCategory: (RepairEquipmentCategory) -> Unit,
    onBrand: (String) -> Unit,
    onModel: (String) -> Unit,
    onSerial: (String) -> Unit,
) {
    StepHeadline("Which equipment?")
    Text(
        text = stringResource(R.string.request_service_equipment_type_label),
        fontSize = 13.sp,
        fontWeight = FontWeight.Medium,
        color = Ink700,
    )
    FlowRow(
        horizontalArrangement = Arrangement.spacedBy(Spacing.xs),
        verticalArrangement = Arrangement.spacedBy(Spacing.xs),
    ) {
        RepairEquipmentCategory.entries
            .filter { it != RepairEquipmentCategory.Other }
            .forEach { option ->
                FilterChip(
                    selected = option == category,
                    onClick = { onCategory(option) },
                    label = { Text(option.displayName) },
                )
            }
    }
    OutlinedTextField(
        value = brand,
        onValueChange = onBrand,
        label = { Text(stringResource(R.string.request_service_brand_label)) },
        placeholder = { Text(stringResource(R.string.request_service_brand_placeholder)) },
        singleLine = true,
        // Brand names are proper nouns ("Siemens", "GE Healthcare",
        // "Philips") — capitalize each word on the soft keyboard.
        keyboardOptions = KeyboardOptions(
            capitalization = KeyboardCapitalization.Words,
        ),
        modifier = Modifier.fillMaxWidth(),
    )
    OutlinedTextField(
        value = model,
        onValueChange = onModel,
        label = { Text(stringResource(R.string.request_service_model_label)) },
        placeholder = { Text(stringResource(R.string.request_service_model_placeholder)) },
        singleLine = true,
        // Model names are also proper nouns. The default sentence-
        // case keyboard would only capitalize the FIRST word, but
        // models like "SOMATOM go.Up" have multiple capitalized
        // tokens — Words gets each one.
        keyboardOptions = KeyboardOptions(
            capitalization = KeyboardCapitalization.Words,
        ),
        modifier = Modifier.fillMaxWidth(),
    )
    OutlinedTextField(
        value = serial,
        onValueChange = onSerial,
        label = { Text(stringResource(R.string.request_service_serial_label)) },
        placeholder = { Text(stringResource(R.string.request_service_serial_placeholder)) },
        singleLine = true,
        // Serials are almost always uppercase alphanumeric on the
        // unit plate. Characters capitalization means every typed
        // letter starts uppercase, matching the source format
        // without manual shift.
        keyboardOptions = KeyboardOptions(
            keyboardType = KeyboardType.Ascii,
            capitalization = KeyboardCapitalization.Characters,
            autoCorrect = false,
        ),
        modifier = Modifier.fillMaxWidth(),
    )
}

@OptIn(androidx.compose.foundation.layout.ExperimentalLayoutApi::class)
@Composable
@Suppress("LongParameterList")
private fun StepIssue(
    issue: String,
    issueError: String?,
    urgency: RepairJobUrgency,
    photos: List<String>,
    uploadingPhoto: Boolean,
    onIssue: (String) -> Unit,
    onUrgency: (RepairJobUrgency) -> Unit,
    onTakePhoto: () -> Unit,
    onPickFromGallery: () -> Unit,
    onRemovePhoto: (String) -> Unit,
) {
    StepHeadline("What's the issue?")
    OutlinedTextField(
        value = issue,
        onValueChange = onIssue,
        label = { Text(stringResource(R.string.request_service_description_label)) },
        placeholder = { Text(stringResource(R.string.request_service_description_placeholder)) },
        isError = issueError != null,
        supportingText = issueError?.let { { Text(it) } },
        minLines = 5,
        modifier = Modifier.fillMaxWidth(),
    )
    PhotoPickerSection(
        photos = photos,
        uploading = uploadingPhoto,
        onTakePhoto = onTakePhoto,
        onPickFromGallery = onPickFromGallery,
        onRemovePhoto = onRemovePhoto,
    )
    Text(
        text = stringResource(R.string.request_service_severity_label),
        fontSize = 13.sp,
        fontWeight = FontWeight.Medium,
        color = Ink700,
    )
    Row(horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
        SeverityTile(
            label = "Low",
            icon = Icons.Outlined.Flag,
            tint = Success,
            selected = urgency == RepairJobUrgency.Scheduled,
            onClick = { onUrgency(RepairJobUrgency.Scheduled) },
            modifier = Modifier.weight(1f),
        )
        SeverityTile(
            label = "Medium",
            icon = Icons.Outlined.Flag,
            tint = Warning,
            selected = urgency == RepairJobUrgency.SameDay,
            onClick = { onUrgency(RepairJobUrgency.SameDay) },
            modifier = Modifier.weight(1f),
        )
        SeverityTile(
            label = "Critical",
            icon = Icons.Outlined.PriorityHigh,
            tint = ErrorRed,
            selected = urgency == RepairJobUrgency.Emergency,
            onClick = { onUrgency(RepairJobUrgency.Emergency) },
            modifier = Modifier.weight(1f),
        )
    }
}

@OptIn(androidx.compose.foundation.layout.ExperimentalLayoutApi::class)
@Composable
private fun PhotoPickerSection(
    photos: List<String>,
    uploading: Boolean,
    onTakePhoto: () -> Unit,
    onPickFromGallery: () -> Unit,
    onRemovePhoto: (String) -> Unit,
) {
    Text(
        text = stringResource(R.string.request_service_photos_label),
        fontSize = 13.sp,
        fontWeight = FontWeight.Medium,
        color = Ink700,
    )
    Text(
        text = stringResource(R.string.request_service_photos_hint),
        fontSize = 12.sp,
        color = Ink700,
    )
    Row(horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
        OutlinedButton(
            onClick = onTakePhoto,
            enabled = !uploading && photos.size < 5,
            modifier = Modifier.weight(1f),
        ) {
            Icon(
                imageVector = Icons.Filled.PhotoCamera,
                contentDescription = null,
                modifier = Modifier.size(18.dp),
            )
            Spacer(Modifier.width(6.dp))
            Text(stringResource(R.string.request_service_take_photo))
        }
        OutlinedButton(
            onClick = onPickFromGallery,
            enabled = !uploading && photos.size < 5,
            modifier = Modifier.weight(1f),
        ) {
            Icon(
                imageVector = Icons.Filled.PhotoLibrary,
                contentDescription = null,
                modifier = Modifier.size(18.dp),
            )
            Spacer(Modifier.width(6.dp))
            Text(stringResource(R.string.request_service_from_gallery))
        }
    }
    if (uploading) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
        ) {
            androidx.compose.material3.CircularProgressIndicator(
                modifier = Modifier.size(16.dp),
                strokeWidth = 2.dp,
            )
            Text(
                text = stringResource(R.string.request_service_uploading),
                fontSize = 12.sp,
                color = Ink700,
            )
        }
    }
    if (photos.isNotEmpty()) {
        FlowRow(
            horizontalArrangement = Arrangement.spacedBy(Spacing.xs),
            verticalArrangement = Arrangement.spacedBy(Spacing.xs),
        ) {
            photos.forEach { path ->
                Row(
                    modifier = Modifier
                        .background(BrandGreen50, androidx.compose.foundation.shape.RoundedCornerShape(8.dp))
                        .padding(horizontal = 10.dp, vertical = 6.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        text = path.substringAfterLast('/').take(26),
                        fontSize = 12.sp,
                        color = BrandGreenDark,
                        maxLines = 1,
                        overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis,
                    )
                    IconButton(onClick = { onRemovePhoto(path) }) {
                        Icon(
                            imageVector = Icons.Filled.Close,
                            contentDescription = "Remove",
                            tint = BrandGreenDark,
                            modifier = Modifier.size(16.dp),
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun SeverityTile(
    label: String,
    icon: ImageVector,
    tint: Color,
    selected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val borderColor = if (selected) BrandGreen else Surface200
    val bg = if (selected) BrandGreen50 else MaterialTheme.colorScheme.surface
    Column(
        modifier = modifier
            .background(bg, RoundedCornerShape(12.dp))
            .border(1.5.dp, borderColor, RoundedCornerShape(12.dp))
            // Round 461: selectable + Role.RadioButton; was plain
            // clickable so TalkBack read "Button" with no selected state.
            .selectable(
                selected = selected,
                onClick = onClick,
                role = androidx.compose.ui.semantics.Role.RadioButton,
            )
            .padding(14.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = tint,
            modifier = Modifier.size(24.dp),
        )
        Text(
            text = label,
            fontSize = 13.sp,
            fontWeight = FontWeight.Bold,
            color = Ink900,
            modifier = Modifier.padding(top = 4.dp),
        )
    }
}

@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
private fun StepWhen(
    selectedSlot: Int,
    onSelectSlot: (Int) -> Unit,
    pickedDateMillis: Long?,
    onPickedDateChange: (Long?) -> Unit,
) {
    StepHeadline("When?")
    Text(
        text = stringResource(R.string.request_service_preferred_slot_label),
        fontSize = 13.sp,
        fontWeight = FontWeight.Medium,
        color = Ink700,
    )
    val slots = listOf("Today · Evening", "Tomorrow · Morning", "Tomorrow · Afternoon", "Flexible")
    var datePickerOpen by rememberSaveable { mutableStateOf(false) }
    // Block past dates: a job scheduled for yesterday is nonsense and the
    // server-side scheduled_date check would later reject it with a vague
    // error. Allow today + future days only.
    val todayMillis = remember {
        java.time.LocalDate.now(java.time.ZoneId.of("Asia/Kolkata"))
            .atStartOfDay(java.time.ZoneId.of("Asia/Kolkata"))
            .toInstant().toEpochMilli()
    }
    val datePickerState = androidx.compose.material3.rememberDatePickerState(
        initialSelectedDateMillis = pickedDateMillis ?: System.currentTimeMillis(),
        selectableDates = object : androidx.compose.material3.SelectableDates {
            override fun isSelectableDate(utcTimeMillis: Long): Boolean =
                utcTimeMillis >= todayMillis
        },
    )
    val customLabel = customDateSlotLabelFromMillis(pickedDateMillis)

    Column(verticalArrangement = Arrangement.spacedBy(Spacing.sm)) {
        Row(horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
            SlotTile(
                label = slots[0],
                selected = selectedSlot == 0,
                onClick = { onSelectSlot(0) },
                modifier = Modifier.weight(1f),
            )
            SlotTile(
                label = slots[1],
                selected = selectedSlot == 1,
                onClick = { onSelectSlot(1) },
                modifier = Modifier.weight(1f),
            )
        }
        Row(horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
            SlotTile(
                label = slots[2],
                selected = selectedSlot == 2,
                onClick = { onSelectSlot(2) },
                modifier = Modifier.weight(1f),
            )
            SlotTile(
                label = slots[3],
                selected = selectedSlot == 3,
                onClick = { onSelectSlot(3) },
                modifier = Modifier.weight(1f),
            )
        }
        SlotTile(
            label = customLabel,
            selected = selectedSlot == 4,
            onClick = { datePickerOpen = true },
            modifier = Modifier.fillMaxWidth(),
        )
    }

    if (datePickerOpen) {
        androidx.compose.material3.DatePickerDialog(
            onDismissRequest = { datePickerOpen = false },
            confirmButton = {
                androidx.compose.material3.TextButton(onClick = {
                    onPickedDateChange(datePickerState.selectedDateMillis)
                    onSelectSlot(4)
                    datePickerOpen = false
                }) { Text(stringResource(R.string.request_service_date_picker_ok)) }
            },
            dismissButton = {
                androidx.compose.material3.TextButton(onClick = { datePickerOpen = false }) {
                    Text(stringResource(R.string.common_cancel))
                }
            },
        ) {
            androidx.compose.material3.DatePicker(state = datePickerState)
        }
    }
}

@Composable
private fun StepWhere(
    siteAddress: String,
    siteAddressError: String?,
    onSiteAddress: (String) -> Unit,
    siteLocation: String,
    onSiteLocation: (String) -> Unit,
    siteLatitude: Double?,
    siteLongitude: Double?,
    onSiteCoords: (Double?, Double?) -> Unit,
    budget: String,
    budgetError: String?,
    onBudget: (String) -> Unit,
) {
    StepHeadline("Where?")
    OutlinedTextField(
        value = siteAddress,
        onValueChange = onSiteAddress,
        label = { Text(stringResource(R.string.request_service_address_label)) },
        placeholder = { Text(stringResource(R.string.request_service_address_placeholder)) },
        // Surface the VM's address requirement inline. The submit
        // handler also stamps this when the field is too short, so
        // the user sees both the banner at top and the field-level
        // error.
        isError = siteAddressError != null,
        supportingText = siteAddressError?.let { { Text(it) } },
        singleLine = false,
        minLines = 2,
        modifier = Modifier.fillMaxWidth(),
    )
    OutlinedTextField(
        value = siteLocation,
        onValueChange = onSiteLocation,
        label = { Text(stringResource(R.string.request_service_engineer_note_label)) },
        placeholder = { Text(stringResource(R.string.request_service_engineer_note_placeholder)) },
        singleLine = false,
        minLines = 2,
        modifier = Modifier.fillMaxWidth(),
    )
    val pickedLatLng = if (siteLatitude != null && siteLongitude != null) {
        com.google.android.gms.maps.model.LatLng(siteLatitude, siteLongitude)
    } else null
    com.equipseva.app.features.repair.components.LocationPickerMap(
        selected = pickedLatLng,
        onLocationPicked = { ll -> onSiteCoords(ll.latitude, ll.longitude) },
    )
    OutlinedTextField(
        value = budget,
        onValueChange = { onBudget(it.filter { c -> c in '0'..'9' || c == '.' }) },
        label = { Text(stringResource(R.string.request_service_budget_label)) },
        placeholder = { Text(stringResource(R.string.request_service_budget_placeholder)) },
        isError = budgetError != null,
        supportingText = budgetError?.let { { Text(it) } },
        singleLine = true,
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
        modifier = Modifier.fillMaxWidth(),
    )
}

@Composable
private fun SlotTile(
    label: String,
    selected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val borderColor = if (selected) BrandGreen else Surface200
    val bg = if (selected) BrandGreen50 else MaterialTheme.colorScheme.surface
    val textColor = if (selected) BrandGreenDark else Ink900
    Box(
        modifier = modifier
            .background(bg, RoundedCornerShape(12.dp))
            .border(1.5.dp, borderColor, RoundedCornerShape(12.dp))
            // Round 461: selectable + Role.RadioButton for slot picker.
            .selectable(
                selected = selected,
                onClick = onClick,
                role = androidx.compose.ui.semantics.Role.RadioButton,
            )
            .padding(12.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = label,
            fontSize = 13.sp,
            fontWeight = FontWeight.SemiBold,
            color = textColor,
        )
    }
}

/**
 * Custom date-slot label on the RequestService "When?" step.
 *
 * Format: "Custom · D MMMM YYYY" (e.g. "Custom · 23 May 2026"),
 * falling back to "Pick a date" when no date is picked.
 *
 * Critical region: Locale.ENGLISH for both lowercase() AND
 * replaceFirstChar uppercase() on the month name.
 *
 *   - WHY: Turkish-locale devices corrupt the English month enum
 *     names via the dotted-vs-dotless 'i' casing rule. Default
 *     locale calls would render "İ" instead of "I" in "JANUARY",
 *     surfacing "Custom · 5 Ocak 2026" or similar mojibake. Pin
 *     so a refactor that dropped one or both Locale args surfaces
 *     here.
 *
 *   - The month name uses Java's enum NAME (uppercased English by
 *     definition) then re-cased — this is more locale-stable than
 *     calling Month.getDisplayName() which uses ICU and surfaces
 *     localised month names.
 *
 * Zone is fixed to IST (Asia/Kolkata) — EquipSeva is India-only,
 * and a traveling user would see day-shifted dates if we used the
 * device default zone.
 */
internal fun customDateSlotLabelFromMillis(pickedDateMillis: Long?): String =
    pickedDateMillis?.let {
        val d = java.time.Instant.ofEpochMilli(it)
            .atZone(java.time.ZoneId.of("Asia/Kolkata"))
            .toLocalDate()
        customDateSlotLabelForDate(d)
    } ?: "Pick a date"

/**
 * Pure form of [customDateSlotLabelFromMillis] — takes an already-
 * resolved LocalDate so tests can pass arbitrary dates without
 * having to compute epoch millis with a specific zone.
 */
internal fun customDateSlotLabelForDate(date: java.time.LocalDate): String {
    val month = date.month.name
        .lowercase(java.util.Locale.ENGLISH)
        .replaceFirstChar { c -> c.uppercase(java.util.Locale.ENGLISH) }
    return "Custom · ${date.dayOfMonth} $month ${date.year}"
}
