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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.core.data.repair.RepairEquipmentCategory
import com.equipseva.app.core.data.repair.RepairJobUrgency
import com.equipseva.app.core.util.MIME_JPEG
import com.equipseva.app.designsystem.components.ESBackTopBar
import com.equipseva.app.designsystem.components.ErrorBanner
import com.equipseva.app.designsystem.components.HorizontalStepper
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
    var step by rememberSaveable { mutableIntStateOf(0) }
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

    val stepLabels = listOf("Equipment", "Issue", "When", "Where")

    // Mirror the PR #639 AmcWizard gating pattern: each step gates Next on
    // its own minimum-valid input so the user can't reach Submit with a
    // provably-bad form. The submit handler (onSubmit) already enforces
    // issue+address again as a defense-in-depth, but without per-step
    // gating the wizard let an empty Brand/Model job advance to Step 2.
    val canProceed = when (step) {
        0 -> state.brand.isNotBlank() && state.model.isNotBlank()
        1 -> state.issue.trim().length >= 10
        2 -> selectedSlot in 0..3 ||
            (selectedSlot == 4 && state.pickedDateMillis != null)
        else -> true
    }

    Scaffold(
        topBar = {
            ESBackTopBar(
                title = "Request service",
                onBack = { if (step == 0) onBack() else step -= 1 },
            )
        },
        bottomBar = {
            WizardBottomBar(
                step = step,
                submitting = state.submitting,
                // Block Next/Submit while a photo upload is mid-flight —
                // otherwise the user can navigate past Step 1 before the
                // upload completes and the resulting URL never lands in
                // state.photos. The submitted job loses that photo with
                // no error surfaced.
                uploadingPhoto = state.uploadingPhoto,
                canProceed = canProceed,
                onBack = { if (step > 0) step -= 1 },
                onNext = { if (step < stepLabels.lastIndex) step += 1 },
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
            Box(modifier = Modifier.padding(horizontal = Spacing.lg, vertical = Spacing.md)) {
                HorizontalStepper(steps = stepLabels, current = step)
            }
            ErrorBanner(
                message = state.errorMessage,
                modifier = Modifier.padding(horizontal = Spacing.lg),
            )
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = Spacing.lg)
                    .padding(bottom = Spacing.xl),
                verticalArrangement = Arrangement.spacedBy(Spacing.md),
            ) {
                when (step) {
                    0 -> StepEquipment(
                        category = state.category,
                        brand = state.brand,
                        model = state.model,
                        serial = state.serial,
                        onCategory = viewModel::onCategoryChange,
                        onBrand = viewModel::onBrandChange,
                        onModel = viewModel::onModelChange,
                        onSerial = viewModel::onSerialChange,
                    )
                    1 -> StepIssue(
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
                    2 -> StepWhen(
                        selectedSlot = selectedSlot,
                        onSelectSlot = { selectedSlot = it },
                        pickedDateMillis = state.pickedDateMillis,
                        onPickedDateChange = viewModel::onPickedDateChange,
                    )
                    3 -> StepWhere(
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
        text = "Equipment type",
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
        label = { Text("Brand") },
        placeholder = { Text("e.g. Siemens") },
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
        label = { Text("Model") },
        placeholder = { Text("e.g. SOMATOM go.Up") },
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
        label = { Text("Serial number (optional)") },
        placeholder = { Text("Usually behind the unit") },
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
        label = { Text("Description") },
        placeholder = { Text("Describe the issue clearly — symptoms, error codes, when it started.") },
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
        text = "Severity",
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
        text = "Photos (optional)",
        fontSize = 13.sp,
        fontWeight = FontWeight.Medium,
        color = Ink700,
    )
    Text(
        text = "Attach photos of the nameplate or fault. Up to 5 images, JPEG/PNG/WEBP.",
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
            Text("Take photo")
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
            Text("From gallery")
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
                text = "Uploading…",
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
            .clickable(onClick = onClick)
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
        text = "Preferred slot",
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
                }) { Text("OK") }
            },
            dismissButton = {
                androidx.compose.material3.TextButton(onClick = { datePickerOpen = false }) {
                    Text("Cancel")
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
        label = { Text("Address") },
        placeholder = { Text("Hospital name, street, city — type if you can't pin on the map") },
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
        label = { Text("Note for the engineer") },
        placeholder = { Text("Ward · Department · Floor · Gate to enter from") },
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
        label = { Text("Budget (₹, optional)") },
        placeholder = { Text("e.g. 5000") },
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
            .clickable(onClick = onClick)
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

@Composable
private fun WizardBottomBar(
    step: Int,
    submitting: Boolean,
    uploadingPhoto: Boolean,
    canProceed: Boolean,
    onBack: () -> Unit,
    onNext: () -> Unit,
    onSubmit: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(MaterialTheme.colorScheme.surface)
            .border(1.dp, Surface200)
            .padding(Spacing.lg),
        horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (step > 0) {
            OutlinedButton(
                onClick = onBack,
                modifier = Modifier
                    .weight(1f)
                    .height(Spacing.MinTouchTarget),
            ) { Text("Back") }
        }
        val isLast = step == 3
        Button(
            onClick = if (isLast) onSubmit else onNext,
            enabled = !submitting && !uploadingPhoto && canProceed,
            modifier = Modifier
                .weight(1f)
                .height(Spacing.MinTouchTarget),
            colors = ButtonDefaults.buttonColors(
                containerColor = MaterialTheme.colorScheme.primary,
                contentColor = MaterialTheme.colorScheme.onPrimary,
            ),
        ) {
            if (isLast) {
                Icon(Icons.Filled.Check, contentDescription = null, modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(6.dp))
                Text(if (submitting) "Submitting…" else "Submit request")
            } else {
                Text("Next")
            }
        }
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
