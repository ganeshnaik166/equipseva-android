package com.equipseva.app.features.hospital

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import android.graphics.Bitmap
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.CalendarMonth
import androidx.compose.material.icons.outlined.CheckCircle
import androidx.compose.material.icons.outlined.LocationOn
import androidx.compose.material.icons.outlined.PhotoCamera
import androidx.compose.material3.Icon
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.core.data.repair.RepairEquipmentCategory
import com.equipseva.app.core.data.repair.RepairJobUrgency
import com.equipseva.app.designsystem.components.ErrorBanner
import com.equipseva.app.designsystem.components.EsBtn
import com.equipseva.app.designsystem.components.EsBtnKind
import com.equipseva.app.designsystem.components.EsBtnSize
import com.equipseva.app.designsystem.components.EsChip
import com.equipseva.app.designsystem.components.EsField
import com.equipseva.app.designsystem.components.EsFieldType
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.Paper2
import com.equipseva.app.designsystem.theme.Paper3
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaGreen50
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaInk400
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk700
import com.equipseva.app.designsystem.theme.SevaInk900
import androidx.compose.foundation.Canvas
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Size

@Composable
fun RequestServiceScreen(
    onBack: () -> Unit,
    onSubmitted: (jobId: String?, jobNumber: String?) -> Unit,
    onShowMessage: (String) -> Unit,
    viewModel: RequestServiceViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    var step by rememberSaveable { mutableStateOf(0) }
    // selectedSlot is preserved (VM submit takes it). Step 2 wires it.
    var selectedSlot by rememberSaveable { mutableStateOf(-1) }

    val context = androidx.compose.ui.platform.LocalContext.current

    // Camera preview thumbnail capture; encode to JPEG before VM hand-off.
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
                contentType = "image/jpeg",
            )
        }
    }

    // Gallery pick (image/* only).
    val galleryLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.PickVisualMedia(),
    ) { uri: android.net.Uri? ->
        if (uri != null) {
            val cr = context.contentResolver
            val mime = cr.getType(uri) ?: "image/jpeg"
            val bytes = cr.openInputStream(uri)?.use { it.readBytes() }
            val fileName = uri.lastPathSegment ?: "gallery-${System.currentTimeMillis()}"
            if (bytes != null) {
                viewModel.onPhotoPicked(fileName, bytes, mime)
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

    val totalSteps = 4

    Scaffold(
        topBar = {
            EsTopBar(
                title = "Request service",
                subtitle = "Step ${step + 1} of $totalSteps",
                onBack = { if (step == 0) onBack() else step -= 1 },
            )
        },
        bottomBar = {
            WizardBottomBar(
                step = step,
                submitting = state.submitting,
                onBack = { if (step > 0) step -= 1 },
                onNext = { if (step < totalSteps - 1) step += 1 },
                onSubmit = { viewModel.onSubmit(selectedSlot) },
            )
        },
        containerColor = PaperDefault,
    ) { inner ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(inner)
                .background(PaperDefault),
        ) {
            // Progress bar — 4dp track, green-700 fill animated to (step+1)/4 over 280ms.
            val progress by animateFloatAsState(
                targetValue = (step + 1) / totalSteps.toFloat(),
                animationSpec = tween(durationMillis = 280),
                label = "wizard-progress",
            )
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(4.dp)
                    .background(Paper2),
            ) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth(progress)
                        .fillMaxHeight()
                        .background(SevaGreen700),
                )
            }
            ErrorBanner(
                message = state.errorMessage,
                modifier = Modifier.padding(horizontal = 16.dp),
            )
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
                    .padding(16.dp),
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
                        photos = state.photos,
                        uploadingPhoto = state.uploadingPhoto,
                        onIssue = viewModel::onIssueChange,
                        onTakePhoto = { cameraLauncher.launch(null) },
                        onPickFromGallery = {
                            galleryLauncher.launch(
                                PickVisualMediaRequest(
                                    ActivityResultContracts.PickVisualMedia.ImageOnly,
                                ),
                            )
                        },
                    )
                    2 -> StepWhen(
                        urgency = state.urgency,
                        onUrgency = viewModel::onUrgencyChange,
                    )
                    3 -> StepWhere(
                        siteLocation = state.siteLocation,
                        onSiteLocation = viewModel::onSiteLocationChange,
                        onUseMyLocation = {
                            // Defer to VM coords picker (Step "Where" preserves VM map flow).
                        },
                        siteLatitude = state.siteLatitude,
                        siteLongitude = state.siteLongitude,
                        onSiteCoords = viewModel::onSiteCoordsChange,
                    )
                }
            }
        }
    }
}

@Composable
private fun StepHeadline(text: String, subtitle: String) {
    Text(
        text = text,
        fontSize = 18.sp,
        fontWeight = FontWeight.Bold,
        color = SevaInk900,
    )
    Spacer(Modifier.height(4.dp))
    Text(
        text = subtitle,
        fontSize = 12.sp,
        color = SevaInk500,
    )
    Spacer(Modifier.height(16.dp))
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
    StepHeadline("Equipment", subtitle = "Tell us what needs servicing.")
    Text(
        text = "Equipment type",
        fontSize = 12.sp,
        fontWeight = FontWeight.SemiBold,
        color = SevaInk700,
    )
    Spacer(Modifier.height(6.dp))
    // First 8 categories — mirrors JSX `EQ_TYPES.slice(0, 8)`.
    val visible = RepairEquipmentCategory.entries
        .filter { it != RepairEquipmentCategory.Other }
        .take(8)
    FlowRow(
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        visible.forEach { option ->
            EsChip(
                text = option.displayName,
                active = option == category,
                onClick = { onCategory(option) },
            )
        }
    }
    Spacer(Modifier.height(12.dp))
    EsField(
        value = brand,
        onChange = onBrand,
        label = "Brand",
        placeholder = "e.g. Philips",
    )
    Spacer(Modifier.height(12.dp))
    EsField(
        value = model,
        onChange = onModel,
        label = "Model",
        placeholder = "e.g. IntelliVue MX450",
    )
    Spacer(Modifier.height(12.dp))
    EsField(
        value = serial,
        onChange = onSerial,
        label = "Serial number",
        placeholder = "Optional",
    )
}

@Composable
private fun StepIssue(
    issue: String,
    issueError: String?,
    photos: List<String>,
    uploadingPhoto: Boolean,
    onIssue: (String) -> Unit,
    onTakePhoto: () -> Unit,
    onPickFromGallery: () -> Unit,
) {
    StepHeadline(
        "Issue",
        subtitle = "Describe what's wrong. Photos help engineers bid accurately.",
    )
    EsField(
        value = issue,
        onChange = onIssue,
        label = "Description",
        placeholder = "e.g. SpO2 probe not detected, intermittent...",
        type = EsFieldType.Multiline,
        error = issueError,
    )
    Spacer(Modifier.height(16.dp))
    Text(
        text = "Photos (up to 5)",
        fontSize = 12.sp,
        fontWeight = FontWeight.SemiBold,
        color = SevaInk700,
    )
    Spacer(Modifier.height(8.dp))
    val filledCount = photos.size.coerceAtMost(5)
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        repeat(5) { i ->
            PhotoSlot(
                filled = i < filledCount,
                onClick = {
                    // Tapping any empty slot launches gallery; tapping the
                    // first empty slot also accepts camera. Match JSX
                    // intent: any slot adds-up-to-5.
                    if (i >= filledCount) {
                        if (i == filledCount && !uploadingPhoto && photos.size < 5) {
                            onPickFromGallery()
                        } else if (!uploadingPhoto && photos.size < 5) {
                            onPickFromGallery()
                        }
                    }
                },
                modifier = Modifier.weight(1f),
            )
        }
    }
    if (photos.size < 5) {
        Spacer(Modifier.height(10.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            EsBtn(
                text = "Take photo",
                onClick = onTakePhoto,
                kind = EsBtnKind.Secondary,
                size = EsBtnSize.Sm,
                disabled = uploadingPhoto,
                modifier = Modifier.weight(1f),
            )
            EsBtn(
                text = "From gallery",
                onClick = onPickFromGallery,
                kind = EsBtnKind.Secondary,
                size = EsBtnSize.Sm,
                disabled = uploadingPhoto,
                modifier = Modifier.weight(1f),
            )
        }
    }
}

@Composable
private fun PhotoSlot(
    filled: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val borderColor = if (filled) SevaGreen700 else BorderDefault
    val bg = if (filled) Paper2 else Color.White
    val radius = 10.dp
    Box(
        modifier = modifier
            .aspectRatio(1f)
            .clip(RoundedCornerShape(radius))
            .background(bg)
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        // Dashed border via Canvas (Compose has no built-in dashed Modifier.border).
        Canvas(modifier = Modifier.fillMaxSize()) {
            val stroke = 1.5.dp.toPx()
            val dash = PathEffect.dashPathEffect(floatArrayOf(6f, 4f), 0f)
            drawRoundRect(
                color = borderColor,
                topLeft = androidx.compose.ui.geometry.Offset(stroke / 2f, stroke / 2f),
                size = Size(size.width - stroke, size.height - stroke),
                cornerRadius = CornerRadius(radius.toPx(), radius.toPx()),
                style = Stroke(width = stroke, pathEffect = dash),
            )
        }
        if (filled) {
            Icon(
                imageVector = Icons.Outlined.CheckCircle,
                contentDescription = null,
                tint = SevaGreen700,
                modifier = Modifier.size(20.dp),
            )
        } else {
            Icon(
                imageVector = Icons.Outlined.PhotoCamera,
                contentDescription = null,
                tint = SevaInk400,
                modifier = Modifier.size(18.dp),
            )
        }
    }
}

@Composable
private fun StepWhen(
    urgency: RepairJobUrgency,
    onUrgency: (RepairJobUrgency) -> Unit,
) {
    StepHeadline("When?", subtitle = "How urgent is this?")
    val options = listOf(
        Triple(RepairJobUrgency.SameDay, "Same-day", "Today, within 8 hours"),
        Triple(RepairJobUrgency.Scheduled, "Next-day", "Tomorrow"),
        Triple(RepairJobUrgency.Emergency, "Within a week", "Schedule for a date"),
    )
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        options.forEach { (key, label, desc) ->
            UrgencyCard(
                label = label,
                desc = desc,
                selected = urgency == key,
                onClick = { onUrgency(key) },
            )
        }
    }
    Spacer(Modifier.height(16.dp))
    // Preferred date / time is a free-form note (we don't parse client-side).
    var dateText by rememberSaveable { mutableStateOf("") }
    EsField(
        value = dateText,
        onChange = { dateText = it },
        label = "Preferred date / time",
        placeholder = "14 May, 10:00–12:00",
        leading = {
            Icon(
                imageVector = Icons.Outlined.CalendarMonth,
                contentDescription = null,
                tint = SevaInk500,
                modifier = Modifier.size(16.dp),
            )
        },
    )
}

@Composable
private fun UrgencyCard(
    label: String,
    desc: String,
    selected: Boolean,
    onClick: () -> Unit,
) {
    val border = if (selected) SevaGreen700 else BorderDefault
    val bg = if (selected) SevaGreen50 else Color.White
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(bg)
            .border(1.5.dp, border, RoundedCornerShape(12.dp))
            .clickable(onClick = onClick)
            .padding(14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = label,
                fontSize = 14.sp,
                fontWeight = FontWeight.SemiBold,
                color = SevaInk900,
            )
            Spacer(Modifier.height(2.dp))
            Text(
                text = desc,
                fontSize = 12.sp,
                color = SevaInk500,
            )
        }
        if (selected) {
            Icon(
                imageVector = Icons.Outlined.CheckCircle,
                contentDescription = null,
                tint = SevaGreen700,
                modifier = Modifier.size(20.dp),
            )
        }
    }
}

@Composable
private fun StepWhere(
    siteLocation: String,
    onSiteLocation: (String) -> Unit,
    onUseMyLocation: () -> Unit,
    siteLatitude: Double?,
    siteLongitude: Double?,
    onSiteCoords: (Double?, Double?) -> Unit,
) {
    StepHeadline("Where?", subtitle = "Confirm the site address.")
    EsField(
        value = siteLocation,
        onChange = onSiteLocation,
        label = "Site / hospital",
        placeholder = "Ward · Department · Floor · Gate to enter from",
        type = EsFieldType.Multiline,
    )
    Spacer(Modifier.height(12.dp))
    EsBtn(
        text = "Use my location",
        onClick = onUseMyLocation,
        kind = EsBtnKind.Secondary,
        full = true,
        leading = {
            Icon(
                imageVector = Icons.Outlined.LocationOn,
                contentDescription = null,
                tint = SevaGreen700,
                modifier = Modifier.size(16.dp),
            )
        },
    )
    Spacer(Modifier.height(12.dp))
    // Location picker map — 160dp paper-3 background placeholder when not picked,
    // live picker when interacted with. Preserves VM coords flow.
    val pickedLatLng = if (siteLatitude != null && siteLongitude != null) {
        com.google.android.gms.maps.model.LatLng(siteLatitude, siteLongitude)
    } else null
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(160.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(Paper3),
    ) {
        // LocationPickerMap renders its own "Tap 'Use my current location'…"
        // hint when selected is null, so don't stack a second "Map preview"
        // label on top of it.
        com.equipseva.app.features.repair.components.LocationPickerMap(
            selected = pickedLatLng,
            onLocationPicked = { ll -> onSiteCoords(ll.latitude, ll.longitude) },
        )
    }
}

@Composable
private fun WizardBottomBar(
    step: Int,
    submitting: Boolean,
    onBack: () -> Unit,
    onNext: () -> Unit,
    onSubmit: () -> Unit,
) {
    val isLast = step == 3
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(Color.White)
            .border(1.dp, BorderDefault, RoundedCornerShape(0.dp))
            .padding(horizontal = 16.dp, vertical = 12.dp),
        horizontalArrangement = Arrangement.spacedBy(10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (step > 0) {
            EsBtn(
                text = "Back",
                onClick = onBack,
                kind = EsBtnKind.Secondary,
                size = EsBtnSize.Lg,
            )
        }
        EsBtn(
            text = when {
                isLast && submitting -> "Submitting…"
                isLast -> "Submit request"
                else -> "Continue"
            },
            onClick = if (isLast) onSubmit else onNext,
            kind = EsBtnKind.Primary,
            size = EsBtnSize.Lg,
            full = true,
            disabled = submitting,
            modifier = Modifier.weight(1f),
        )
    }
}
