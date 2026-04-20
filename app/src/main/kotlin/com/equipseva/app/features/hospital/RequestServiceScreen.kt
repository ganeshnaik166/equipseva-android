package com.equipseva.app.features.hospital

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
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.outlined.Flag
import androidx.compose.material.icons.outlined.PriorityHigh
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
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
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

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RequestServiceScreen(
    onBack: () -> Unit,
    onSubmitted: () -> Unit,
    onShowMessage: (String) -> Unit,
    viewModel: RequestServiceViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    var step by rememberSaveable { mutableStateOf(0) }
    // UI-only field — VM doesn't persist serials yet.
    var serial by rememberSaveable { mutableStateOf("") }
    var selectedSlot by rememberSaveable { mutableStateOf(-1) }
    // UI-only — VM doesn't persist site location yet (no schema column).
    var siteLocation by rememberSaveable { mutableStateOf("") }

    LaunchedEffect(viewModel) {
        viewModel.effects.collect { effect ->
            when (effect) {
                RequestServiceViewModel.Effect.Submitted -> {
                    onShowMessage("Service request submitted")
                    onSubmitted()
                }
            }
        }
    }

    val stepLabels = listOf("Equipment", "Issue", "Schedule")

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
                        serial = serial,
                        onCategory = viewModel::onCategoryChange,
                        onBrand = viewModel::onBrandChange,
                        onModel = viewModel::onModelChange,
                        onSerial = { serial = it },
                    )
                    1 -> StepIssue(
                        issue = state.issue,
                        issueError = state.issueError,
                        urgency = state.urgency,
                        onIssue = viewModel::onIssueChange,
                        onUrgency = viewModel::onUrgencyChange,
                    )
                    2 -> StepSchedule(
                        selectedSlot = selectedSlot,
                        onSelectSlot = { selectedSlot = it },
                        siteLocation = siteLocation,
                        onSiteLocation = { siteLocation = it },
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
        modifier = Modifier.fillMaxWidth(),
    )
    OutlinedTextField(
        value = model,
        onValueChange = onModel,
        label = { Text("Model") },
        placeholder = { Text("e.g. SOMATOM go.Up") },
        singleLine = true,
        modifier = Modifier.fillMaxWidth(),
    )
    OutlinedTextField(
        value = serial,
        onValueChange = onSerial,
        label = { Text("Serial number (optional)") },
        placeholder = { Text("Usually behind the unit") },
        singleLine = true,
        modifier = Modifier.fillMaxWidth(),
    )
}

@Composable
private fun StepIssue(
    issue: String,
    issueError: String?,
    urgency: RepairJobUrgency,
    onIssue: (String) -> Unit,
    onUrgency: (RepairJobUrgency) -> Unit,
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

@Composable
private fun StepSchedule(
    selectedSlot: Int,
    onSelectSlot: (Int) -> Unit,
    siteLocation: String,
    onSiteLocation: (String) -> Unit,
) {
    StepHeadline("Schedule & location")
    Text(
        text = "Preferred slot",
        fontSize = 13.sp,
        fontWeight = FontWeight.Medium,
        color = Ink700,
    )
    val slots = listOf("Today · Evening", "Tomorrow · Morning", "Tomorrow · Afternoon", "Flexible")
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
    }
    OutlinedTextField(
        value = siteLocation,
        onValueChange = onSiteLocation,
        label = { Text("Site location") },
        placeholder = { Text("Ward · Department · Floor") },
        singleLine = true,
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
        val isLast = step == 2
        Button(
            onClick = if (isLast) onSubmit else onNext,
            enabled = !submitting,
            modifier = Modifier
                .weight(1f)
                .height(Spacing.MinTouchTarget),
            colors = ButtonDefaults.buttonColors(
                containerColor = BrandGreen,
                contentColor = Color.White,
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
