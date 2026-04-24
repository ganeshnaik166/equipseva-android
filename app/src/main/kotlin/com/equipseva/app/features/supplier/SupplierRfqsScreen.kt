package com.equipseva.app.features.supplier

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.LocationOn
import androidx.compose.material.icons.outlined.RequestQuote
import androidx.compose.material.icons.outlined.Schedule
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.core.data.rfq.Rfq
import com.equipseva.app.core.util.countdownLabel
import com.equipseva.app.core.util.formatRupees
import com.equipseva.app.core.util.relativeLabel
import java.time.Duration
import java.time.Instant
import com.equipseva.app.designsystem.components.ESBackTopBar
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.ErrorBanner
import com.equipseva.app.designsystem.components.PrimaryButton
import com.equipseva.app.designsystem.components.SecondaryButton
import com.equipseva.app.designsystem.components.StatusChip
import com.equipseva.app.designsystem.components.StatusTone
import com.equipseva.app.designsystem.theme.BrandGreenDark
import com.equipseva.app.designsystem.theme.Ink500
import com.equipseva.app.designsystem.theme.Ink700
import com.equipseva.app.designsystem.theme.Ink900
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.designsystem.theme.Surface0
import com.equipseva.app.designsystem.theme.Surface200
import com.equipseva.app.designsystem.theme.Surface50

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SupplierRfqsScreen(
    onBack: () -> Unit,
    viewModel: SupplierRfqsViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val snackbarHost = remember { SnackbarHostState() }

    LaunchedEffect(Unit) {
        viewModel.effects.collect { effect ->
            when (effect) {
                is SupplierRfqsViewModel.Effect.ShowMessage ->
                    snackbarHost.showSnackbar(effect.text)
            }
        }
    }

    Scaffold(
        topBar = { ESBackTopBar(title = "Open RFQs", onBack = onBack) },
        snackbarHost = { SnackbarHost(snackbarHost) },
        containerColor = Surface50,
    ) { inner ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(inner)
                .background(Surface50),
        ) {
            ErrorBanner(
                message = state.errorMessage,
                modifier = Modifier.padding(horizontal = Spacing.lg),
            )
            PullToRefreshBox(
                isRefreshing = state.refreshing,
                onRefresh = viewModel::onRefresh,
                modifier = Modifier.fillMaxSize(),
            ) {
                when {
                    state.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator()
                    }
                    state.rfqs.isEmpty() -> EmptyStateView(
                        icon = Icons.Outlined.RequestQuote,
                        title = "No open RFQs",
                        subtitle = "Check back later for new bulk inquiries.",
                    )
                    else -> LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(
                            horizontal = Spacing.lg,
                            vertical = Spacing.md,
                        ),
                        verticalArrangement = Arrangement.spacedBy(Spacing.md),
                    ) {
                        items(items = state.rfqs, key = { it.id }) { rfq ->
                            RfqListCard(
                                rfq = rfq,
                                onPlaceBid = { viewModel.onOpenBid(rfq) },
                            )
                        }
                    }
                }
            }
        }
    }

    val bidForm = state.bidForm
    if (bidForm != null) {
        val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
        ModalBottomSheet(
            onDismissRequest = viewModel::onDismissBid,
            sheetState = sheetState,
        ) {
            BidComposer(
                form = bidForm,
                submitting = state.submittingBid,
                onUnitPriceChange = viewModel::onUnitPriceChange,
                onDeliveryChange = viewModel::onDeliveryTimelineChange,
                onWarrantyChange = viewModel::onWarrantyMonthsChange,
                onInstallChange = viewModel::onIncludesInstallationChange,
                onTrainingChange = viewModel::onIncludesTrainingChange,
                onNotesChange = viewModel::onNotesChange,
                onSubmit = viewModel::onSubmitBid,
                onCancel = viewModel::onDismissBid,
            )
        }
    }
}

@Composable
internal fun RfqListCard(
    rfq: Rfq,
    onPlaceBid: (() -> Unit)? = null,
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(8.dp),
        colors = CardDefaults.cardColors(containerColor = Surface0),
        border = BorderStroke(1.dp, Surface200),
        elevation = CardDefaults.cardElevation(defaultElevation = 0.dp),
    ) {
        Column(
            modifier = Modifier.padding(Spacing.md),
            verticalArrangement = Arrangement.spacedBy(Spacing.xs),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.Top,
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = rfq.title,
                        fontSize = 15.sp,
                        lineHeight = 20.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = Ink900,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                    )
                    rfq.rfqNumber?.let {
                        Text(
                            text = "#$it",
                            fontSize = 11.sp,
                            lineHeight = 14.sp,
                            color = Ink500,
                        )
                    }
                }
                StatusChip(
                    label = rfq.status.replaceFirstChar { it.uppercase() },
                    tone = if (rfq.isOpen) StatusTone.Info else StatusTone.Neutral,
                )
            }

            // Chip row: equipment category + budget
            Row(
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.padding(top = 2.dp),
            ) {
                rfq.equipmentCategory?.takeIf { it.isNotBlank() }?.let { cat ->
                    StatusChip(label = cat, tone = StatusTone.Neutral)
                }
                val budget = formatBudget(rfq.budgetMinRupees, rfq.budgetMaxRupees)
                if (budget != null) {
                    StatusChip(label = "Budget $budget", tone = StatusTone.Info)
                }
            }

            rfq.description?.takeIf { it.isNotBlank() }?.let {
                Text(
                    text = it,
                    fontSize = 12.sp,
                    lineHeight = 16.sp,
                    color = Ink700,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            rfq.deliveryLocation?.takeIf { it.isNotBlank() }?.let { loc ->
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(4.dp),
                ) {
                    Icon(
                        imageVector = Icons.Outlined.LocationOn,
                        contentDescription = null,
                        tint = Ink500,
                        modifier = Modifier.size(14.dp),
                    )
                    Text(
                        text = loc,
                        fontSize = 12.sp,
                        lineHeight = 16.sp,
                        color = Ink500,
                    )
                }
            }
            rfq.deliveryDeadlineIso?.takeIf { it.isNotBlank() }?.let {
                Text(
                    text = "Deliver by $it",
                    fontSize = 11.sp,
                    lineHeight = 14.sp,
                    color = Ink500,
                )
            }
            val posted = rfq.createdAtInstant?.let { " · Posted ${relativeLabel(it)} ago" }.orEmpty()
            Text(
                text = "Qty ${rfq.quantity} · ${rfq.bidsCount} bid(s)$posted",
                fontSize = 11.sp,
                lineHeight = 14.sp,
                color = Ink500,
            )
            rfq.deadlineInstant?.let { deadline ->
                val now = Instant.now()
                val overdue = deadline.isBefore(now)
                val soon = !overdue && Duration.between(now, deadline).toHours() < 24
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(4.dp),
                ) {
                    Icon(
                        imageVector = Icons.Outlined.Schedule,
                        contentDescription = null,
                        tint = if (overdue) MaterialTheme.colorScheme.error
                            else if (soon) MaterialTheme.colorScheme.tertiary
                            else BrandGreenDark,
                        modifier = Modifier.size(14.dp),
                    )
                    StatusChip(
                        label = countdownLabel(deadline, now) + " to quote",
                        tone = when {
                            overdue -> StatusTone.Danger
                            soon -> StatusTone.Warn
                            else -> StatusTone.Success
                        },
                    )
                }
            }
            if (onPlaceBid != null && rfq.isOpen) {
                Spacer(Modifier.height(4.dp))
                PrimaryButton(
                    label = "Place bid",
                    onClick = onPlaceBid,
                )
            }
        }
    }
}

@Composable
private fun BidComposer(
    form: SupplierRfqsViewModel.BidForm,
    submitting: Boolean,
    onUnitPriceChange: (String) -> Unit,
    onDeliveryChange: (String) -> Unit,
    onWarrantyChange: (String) -> Unit,
    onInstallChange: (Boolean) -> Unit,
    onTrainingChange: (Boolean) -> Unit,
    onNotesChange: (String) -> Unit,
    onSubmit: () -> Unit,
    onCancel: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = Spacing.lg, vertical = Spacing.md),
        verticalArrangement = Arrangement.spacedBy(Spacing.sm),
    ) {
        Text(
            text = "Place a bid",
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.SemiBold,
            color = Ink900,
        )
        Text(
            text = "Quantity: ${form.quantity}",
            style = MaterialTheme.typography.bodyMedium,
            color = Ink500,
        )

        OutlinedTextField(
            value = form.unitPriceText,
            onValueChange = onUnitPriceChange,
            label = { Text("Unit price (INR) *") },
            isError = form.showValidationErrors && form.unitPriceError != null,
            supportingText = {
                form.unitPriceError?.takeIf { form.showValidationErrors }?.let { Text(it) }
            },
            keyboardOptions = KeyboardOptions(
                keyboardType = KeyboardType.Decimal,
                imeAction = ImeAction.Next,
            ),
            singleLine = true,
            shape = RoundedCornerShape(8.dp),
            modifier = Modifier.fillMaxWidth(),
        )
        if (form.unitPriceText.toDoubleOrNull() != null) {
            Text(
                text = "Total: ${formatRupees(form.totalPrice)}",
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.SemiBold,
                color = BrandGreenDark,
            )
        }

        Row(horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
            OutlinedTextField(
                value = form.deliveryTimelineDaysText,
                onValueChange = onDeliveryChange,
                label = { Text("Delivery (days)") },
                isError = form.deliveryTimelineError != null,
                supportingText = { form.deliveryTimelineError?.let { Text(it) } },
                keyboardOptions = KeyboardOptions(
                    keyboardType = KeyboardType.Number,
                    imeAction = ImeAction.Next,
                ),
                singleLine = true,
                shape = RoundedCornerShape(8.dp),
                modifier = Modifier.weight(1f),
            )
            OutlinedTextField(
                value = form.warrantyMonthsText,
                onValueChange = onWarrantyChange,
                label = { Text("Warranty (months)") },
                isError = form.warrantyMonthsError != null,
                supportingText = { form.warrantyMonthsError?.let { Text(it) } },
                keyboardOptions = KeyboardOptions(
                    keyboardType = KeyboardType.Number,
                    imeAction = ImeAction.Next,
                ),
                singleLine = true,
                shape = RoundedCornerShape(8.dp),
                modifier = Modifier.weight(1f),
            )
        }

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = "Includes installation",
                style = MaterialTheme.typography.bodyMedium,
                color = Ink900,
            )
            Switch(checked = form.includesInstallation, onCheckedChange = onInstallChange)
        }
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = "Includes training",
                style = MaterialTheme.typography.bodyMedium,
                color = Ink900,
            )
            Switch(checked = form.includesTraining, onCheckedChange = onTrainingChange)
        }

        OutlinedTextField(
            value = form.notes,
            onValueChange = onNotesChange,
            label = { Text("Notes") },
            keyboardOptions = KeyboardOptions(
                capitalization = KeyboardCapitalization.Sentences,
                imeAction = ImeAction.Done,
            ),
            minLines = 3,
            shape = RoundedCornerShape(8.dp),
            modifier = Modifier.fillMaxWidth(),
        )

        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = Spacing.sm),
            horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
        ) {
            SecondaryButton(
                label = "Cancel",
                onClick = onCancel,
                enabled = !submitting,
                modifier = Modifier.weight(1f),
            )
            PrimaryButton(
                label = "Submit bid",
                loading = submitting,
                enabled = !submitting,
                onClick = onSubmit,
                modifier = Modifier.weight(1f),
            )
        }
    }
}

internal fun formatBudget(min: Double?, max: Double?): String? = when {
    min != null && max != null && max > min -> "${formatRupees(min)} – ${formatRupees(max)}"
    max != null -> "up to ${formatRupees(max)}"
    min != null -> "from ${formatRupees(min)}"
    else -> null
}
