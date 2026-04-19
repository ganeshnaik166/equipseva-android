package com.equipseva.app.features.repair

import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.outlined.ChatBubbleOutline
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
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
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
import com.equipseva.app.designsystem.components.StatusChip
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.features.repair.components.toTone

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RepairJobDetailScreen(
    onBack: () -> Unit,
    onShowMessage: (String) -> Unit,
    onOpenChat: (String) -> Unit,
    viewModel: RepairJobDetailViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    LaunchedEffect(viewModel) {
        viewModel.messages.collect { onShowMessage(it) }
    }
    LaunchedEffect(viewModel) {
        viewModel.effects.collect { effect ->
            when (effect) {
                is RepairJobDetailViewModel.Effect.NavigateToChat -> onOpenChat(effect.conversationId)
            }
        }
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
                    openingChat = state.openingChat,
                    onPlaceBid = viewModel::openBidComposer,
                    onWithdraw = viewModel::withdrawBid,
                    onMessageHospital = viewModel::openChatWithHospital,
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
    openingChat: Boolean,
    onPlaceBid: () -> Unit,
    onWithdraw: () -> Unit,
    onMessageHospital: () -> Unit,
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
            StatusChip(label = job.status.displayName, tone = job.status.toTone())
            if (job.urgency != RepairJobUrgency.Unknown) {
                StatusChip(label = job.urgency.displayName, tone = job.urgency.toTone())
            }
        }

        SectionTitle("Progress")
        JobTimeline(currentStatus = job.status)

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

        if (job.hospitalUserId != null) {
            TextButton(
                onClick = onMessageHospital,
                enabled = !openingChat,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Icon(Icons.Outlined.ChatBubbleOutline, contentDescription = null)
                Spacer(Modifier.width(Spacing.sm))
                Text(if (openingChat) "Opening chat…" else "Message requester")
            }
        }
    }
}

@Composable
private fun JobTimeline(currentStatus: RepairJobStatus) {
    val steps = listOf("Requested", "Assigned", "In progress", "Completed")
    val currentIndex = when (currentStatus) {
        RepairJobStatus.Requested -> 0
        RepairJobStatus.Assigned -> 1
        RepairJobStatus.EnRoute, RepairJobStatus.InProgress -> 2
        RepairJobStatus.Completed -> 3
        RepairJobStatus.Cancelled, RepairJobStatus.Disputed, RepairJobStatus.Unknown -> -1
    }

    Column(modifier = Modifier.fillMaxWidth()) {
        steps.forEachIndexed { index, label ->
            TimelineRow(
                label = label,
                state = when {
                    currentIndex < 0 -> TimelineState.Future
                    index < currentIndex -> TimelineState.Completed
                    index == currentIndex -> TimelineState.Current
                    else -> TimelineState.Future
                },
                showConnector = index != steps.lastIndex,
            )
        }
    }
}

private enum class TimelineState { Completed, Current, Future }

@Composable
private fun TimelineRow(label: String, state: TimelineState, showConnector: Boolean) {
    val primary = MaterialTheme.colorScheme.primary
    val outline = MaterialTheme.colorScheme.outline
    val outlineVariant = MaterialTheme.colorScheme.outlineVariant

    Row(verticalAlignment = Alignment.Top) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            when (state) {
                TimelineState.Current -> Box(
                    modifier = Modifier
                        .size(12.dp)
                        .background(color = primary, shape = CircleShape),
                )
                TimelineState.Completed -> Box(
                    modifier = Modifier
                        .size(12.dp)
                        .background(color = primary.copy(alpha = 0.6f), shape = CircleShape),
                )
                TimelineState.Future -> Box(
                    modifier = Modifier
                        .size(12.dp)
                        .border(width = 1.dp, color = outline, shape = CircleShape),
                )
            }
            if (showConnector) {
                Box(
                    modifier = Modifier
                        .width(2.dp)
                        .height(28.dp)
                        .background(outlineVariant),
                )
            }
        }
        Spacer(Modifier.width(Spacing.md))
        Text(
            text = label,
            style = MaterialTheme.typography.titleSmall,
            color = when (state) {
                TimelineState.Current -> MaterialTheme.colorScheme.onSurface
                TimelineState.Completed -> MaterialTheme.colorScheme.onSurface
                TimelineState.Future -> MaterialTheme.colorScheme.onSurfaceVariant
            },
            modifier = Modifier.padding(top = 0.dp),
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

    var amountTouched by rememberSaveable { mutableStateOf(false) }
    var etaTouched by rememberSaveable { mutableStateOf(false) }
    var amountFocused by remember { mutableStateOf(false) }
    var etaFocused by remember { mutableStateOf(false) }

    val parsedAmount = amount.toDoubleOrNull()
    val amountValid = parsedAmount != null && parsedAmount > 0.0
    val parsedEta = eta.trim().takeIf { it.isNotEmpty() }?.toIntOrNull()
    val etaValid = eta.trim().isEmpty() || (parsedEta != null && parsedEta > 0)

    val amountError by remember(amount, amountTouched) {
        derivedStateOf { amountTouched && !amountValid }
    }
    val etaError by remember(eta, etaTouched) {
        derivedStateOf { etaTouched && !etaValid }
    }

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
                isError = amountError,
                supportingText = {
                    if (amountError) Text("Enter a valid amount")
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .onFocusChanged { focusState ->
                        if (!focusState.isFocused && amountFocused) amountTouched = true
                        amountFocused = focusState.isFocused
                    },
            )

            OutlinedTextField(
                value = eta,
                onValueChange = { eta = it.filter(Char::isDigit) },
                label = { Text("ETA hours (optional)") },
                singleLine = true,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                isError = etaError,
                supportingText = {
                    if (etaError) Text("Enter hours as a positive whole number")
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .onFocusChanged { focusState ->
                        if (!focusState.isFocused && etaFocused) etaTouched = true
                        etaFocused = focusState.isFocused
                    },
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
                    amountTouched = true
                    etaTouched = true
                    val value = parsedAmount
                    if (value != null && amountValid && etaValid) {
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
