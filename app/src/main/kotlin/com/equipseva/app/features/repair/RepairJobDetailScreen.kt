package com.equipseva.app.features.repair

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.input.KeyboardType
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.core.data.repair.RepairBid
import com.equipseva.app.core.data.repair.RepairBidStatus
import com.equipseva.app.core.data.repair.RepairJob
import com.equipseva.app.core.data.repair.RepairJobStatus
import com.equipseva.app.core.data.repair.RepairJobUrgency
import com.equipseva.app.core.util.formatRupees
import com.equipseva.app.designsystem.components.ErrorBanner
import com.equipseva.app.designsystem.components.PrimaryButton
import com.equipseva.app.designsystem.theme.Spacing

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RepairJobDetailScreen(
    onBack: () -> Unit,
    onShowMessage: (String) -> Unit,
    viewModel: RepairJobDetailViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    LaunchedEffect(viewModel) {
        viewModel.messages.collect { onShowMessage(it) }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(state.job?.jobNumber ?: "Repair request") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
            )
        },
    ) { padding ->
        Box(modifier = Modifier.padding(padding).fillMaxSize()) {
            when {
                state.loading -> Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center,
                ) { CircularProgressIndicator() }
                state.notFound -> NotFoundState(onBack)
                state.job == null && state.errorMessage != null -> ErrorState(
                    message = state.errorMessage!!,
                    onRetry = viewModel::retry,
                )
                state.job != null -> JobBody(
                    job = state.job!!,
                    ownBid = state.ownBid,
                    withdrawing = state.withdrawingBid,
                    onPlaceBid = viewModel::openBidComposer,
                    onWithdraw = viewModel::withdrawBid,
                )
            }
        }
    }

    if (state.bidComposerOpen && state.job != null) {
        BidComposerSheet(
            existingBid = state.ownBid?.takeIf { it.status == RepairBidStatus.Pending },
            placingBid = state.placingBid,
            onDismiss = viewModel::closeBidComposer,
            onSubmit = viewModel::submitBid,
        )
    }
}

@Composable
private fun JobBody(
    job: RepairJob,
    ownBid: RepairBid?,
    withdrawing: Boolean,
    onPlaceBid: () -> Unit,
    onWithdraw: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(Spacing.lg),
        verticalArrangement = Arrangement.spacedBy(Spacing.md),
    ) {
        Text(job.equipmentLabel, style = MaterialTheme.typography.headlineSmall)
        val brandModel = listOfNotNull(job.equipmentBrand, job.equipmentModel).joinToString(" ")
        if (brandModel.isNotBlank() && brandModel != job.equipmentLabel) {
            Text(
                text = brandModel,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }

        Row(horizontalArrangement = Arrangement.spacedBy(Spacing.xs)) {
            StatusChip(job.status)
            if (job.urgency != RepairJobUrgency.Unknown) UrgencyChip(job.urgency)
        }

        SectionTitle("Issue")
        Text(job.issueDescription, style = MaterialTheme.typography.bodyMedium)

        val schedule = listOfNotNull(job.scheduledDate, job.scheduledTimeSlot).joinToString(" ")
        if (schedule.isNotBlank()) {
            SectionTitle("Scheduled")
            Text(schedule, style = MaterialTheme.typography.bodyMedium)
        }

        job.estimatedCostRupees?.let { cost ->
            SectionTitle("Estimated cost")
            Text("₹%.0f".format(cost), style = MaterialTheme.typography.bodyMedium)
        }

        HorizontalDivider()

        SectionTitle("Your bid")
        if (ownBid == null) {
            Text(
                "You haven't bid on this job yet.",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        } else {
            OwnBidCard(ownBid)
        }

        BidActions(
            job = job,
            ownBid = ownBid,
            withdrawing = withdrawing,
            onPlaceBid = onPlaceBid,
            onWithdraw = onWithdraw,
        )
    }
}

@Composable
private fun OwnBidCard(bid: RepairBid) {
    Column(verticalArrangement = Arrangement.spacedBy(Spacing.xs)) {
        Text(formatRupees(bid.amountRupees), style = MaterialTheme.typography.titleLarge)
        Text(
            text = "Status: ${bid.status.displayName}",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        bid.etaHours?.let {
            Text("ETA: $it hours", style = MaterialTheme.typography.bodyMedium)
        }
        if (!bid.note.isNullOrBlank()) {
            Text("Note: ${bid.note}", style = MaterialTheme.typography.bodyMedium)
        }
    }
}

@Composable
private fun BidActions(
    job: RepairJob,
    ownBid: RepairBid?,
    withdrawing: Boolean,
    onPlaceBid: () -> Unit,
    onWithdraw: () -> Unit,
) {
    val acceptsBids = job.status == RepairJobStatus.Requested

    when {
        !acceptsBids -> Text(
            text = "Bidding closed for this job",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        ownBid == null -> PrimaryButton(
            label = "Place bid",
            onClick = onPlaceBid,
        )
        ownBid.status == RepairBidStatus.Pending -> {
            PrimaryButton(
                label = "Update bid",
                onClick = onPlaceBid,
                enabled = !withdrawing,
            )
            TextButton(
                onClick = onWithdraw,
                enabled = !withdrawing,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text(if (withdrawing) "Withdrawing…" else "Withdraw")
            }
        }
        else -> Text(
            text = "Bidding closed for this job",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun StatusChip(status: RepairJobStatus) {
    val (container, content) = when (status) {
        RepairJobStatus.Requested -> MaterialTheme.colorScheme.primaryContainer to MaterialTheme.colorScheme.onPrimaryContainer
        RepairJobStatus.Assigned -> MaterialTheme.colorScheme.secondaryContainer to MaterialTheme.colorScheme.onSecondaryContainer
        else -> MaterialTheme.colorScheme.surfaceVariant to MaterialTheme.colorScheme.onSurfaceVariant
    }
    Chip(text = status.displayName, container = container, content = content)
}

@Composable
private fun UrgencyChip(urgency: RepairJobUrgency) {
    val (container, content) = when (urgency) {
        RepairJobUrgency.Emergency -> MaterialTheme.colorScheme.errorContainer to MaterialTheme.colorScheme.onErrorContainer
        RepairJobUrgency.SameDay -> MaterialTheme.colorScheme.tertiaryContainer to MaterialTheme.colorScheme.onTertiaryContainer
        else -> MaterialTheme.colorScheme.surfaceVariant to MaterialTheme.colorScheme.onSurfaceVariant
    }
    Chip(text = urgency.displayName, container = container, content = content)
}

@Composable
private fun Chip(text: String, container: Color, content: Color) {
    Surface(
        color = container,
        contentColor = content,
        shape = RoundedCornerShape(Spacing.xs),
    ) {
        Text(
            text = text,
            style = MaterialTheme.typography.labelSmall,
            modifier = Modifier.padding(horizontal = Spacing.sm, vertical = Spacing.xxs),
        )
    }
}

@Composable
private fun SectionTitle(text: String) {
    Text(
        text = text,
        style = MaterialTheme.typography.titleMedium,
        modifier = Modifier.padding(top = Spacing.sm),
    )
}

@Composable
private fun NotFoundState(onBack: () -> Unit) {
    Column(
        modifier = Modifier.fillMaxSize().padding(Spacing.xl),
        verticalArrangement = Arrangement.spacedBy(Spacing.md, Alignment.CenterVertically),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            "This repair job is no longer available.",
            style = MaterialTheme.typography.titleMedium,
        )
        Button(onClick = onBack) { Text("Back") }
    }
}

@Composable
private fun ErrorState(message: String, onRetry: () -> Unit) {
    Column(
        modifier = Modifier.fillMaxSize().padding(Spacing.xl),
        verticalArrangement = Arrangement.spacedBy(Spacing.md, Alignment.CenterVertically),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        ErrorBanner(message = message)
        Button(onClick = onRetry) { Text("Retry") }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun BidComposerSheet(
    existingBid: RepairBid?,
    placingBid: Boolean,
    onDismiss: () -> Unit,
    onSubmit: (amountRupees: Double, etaHours: Int?, note: String?) -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    var amount by rememberSaveable(existingBid?.id) {
        mutableStateOf(existingBid?.amountRupees?.let { "%.0f".format(it) } ?: "")
    }
    var eta by rememberSaveable(existingBid?.id) {
        mutableStateOf(existingBid?.etaHours?.toString() ?: "")
    }
    var note by rememberSaveable(existingBid?.id) {
        mutableStateOf(existingBid?.note.orEmpty())
    }

    val parsedAmount = amount.toDoubleOrNull()
    val amountValid = parsedAmount != null && parsedAmount > 0.0
    val parsedEta = eta.trim().takeIf { it.isNotEmpty() }?.toIntOrNull()
    val etaValid = eta.trim().isEmpty() || parsedEta != null

    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheetState) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = Spacing.lg)
                .padding(bottom = Spacing.xl),
            verticalArrangement = Arrangement.spacedBy(Spacing.md),
        ) {
            Text(
                text = if (existingBid != null) "Update your bid" else "Place your bid",
                style = MaterialTheme.typography.titleLarge,
            )

            OutlinedTextField(
                value = amount,
                onValueChange = { amount = it.filter { ch -> ch.isDigit() || ch == '.' } },
                label = { Text("Amount (₹)") },
                singleLine = true,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                isError = amount.isNotEmpty() && !amountValid,
                modifier = Modifier.fillMaxWidth(),
            )

            OutlinedTextField(
                value = eta,
                onValueChange = { eta = it.filter(Char::isDigit) },
                label = { Text("ETA hours (optional)") },
                singleLine = true,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                isError = !etaValid,
                modifier = Modifier.fillMaxWidth(),
            )

            OutlinedTextField(
                value = note,
                onValueChange = { note = it },
                label = { Text("Note (optional)") },
                maxLines = 4,
                modifier = Modifier.fillMaxWidth(),
            )

            PrimaryButton(
                label = if (placingBid) "Submitting…" else "Submit",
                onClick = {
                    val value = parsedAmount
                    if (value != null) {
                        onSubmit(value, parsedEta, note.trim().ifBlank { null })
                    }
                },
                enabled = amountValid && etaValid && !placingBid,
                loading = placingBid,
            )

            TextButton(
                onClick = onDismiss,
                enabled = !placingBid,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text("Cancel")
            }
        }
    }
}
