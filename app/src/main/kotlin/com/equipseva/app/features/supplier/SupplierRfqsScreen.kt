package com.equipseva.app.features.supplier

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.RequestQuote
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.MaterialTheme
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
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.core.data.rfq.Rfq
import com.equipseva.app.core.util.countdownLabel
import com.equipseva.app.core.util.formatRupees
import com.equipseva.app.core.util.relativeLabel
import java.time.Instant
import com.equipseva.app.designsystem.components.ESBackTopBar
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.components.ErrorBanner
import com.equipseva.app.designsystem.components.PrimaryButton
import com.equipseva.app.designsystem.components.StatusChip
import com.equipseva.app.designsystem.components.StatusTone
import com.equipseva.app.designsystem.theme.Spacing

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
    ) { inner ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(inner),
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
                        contentPadding = PaddingValues(horizontal = Spacing.lg, vertical = Spacing.md),
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
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp),
    ) {
        Column(
            modifier = Modifier.padding(Spacing.lg),
            verticalArrangement = Arrangement.spacedBy(Spacing.xs),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = rfq.title,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.weight(1f),
                )
                StatusChip(
                    label = rfq.status.replaceFirstChar { it.uppercase() },
                    tone = if (rfq.isOpen) StatusTone.Info else StatusTone.Neutral,
                )
            }
            rfq.rfqNumber?.let {
                Text(
                    text = "#$it",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            rfq.equipmentCategory?.takeIf { it.isNotBlank() }?.let {
                Text(
                    text = it,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            rfq.description?.takeIf { it.isNotBlank() }?.let {
                Text(
                    text = it,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            val budget = formatBudget(rfq.budgetMinRupees, rfq.budgetMaxRupees)
            if (budget != null) {
                Text(
                    text = "Budget $budget",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            rfq.deliveryLocation?.takeIf { it.isNotBlank() }?.let {
                Text(
                    text = "Ship to $it",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            rfq.deliveryDeadlineIso?.takeIf { it.isNotBlank() }?.let {
                Text(
                    text = "Deliver by $it",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            val posted = rfq.createdAtInstant?.let { "· Posted ${relativeLabel(it)} ago" } ?: ""
            Text(
                text = "Qty ${rfq.quantity} · ${rfq.bidsCount} bid(s) $posted".trimEnd(),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            rfq.deadlineInstant?.let { deadline ->
                val now = Instant.now()
                val overdue = deadline.isBefore(now)
                Text(
                    text = countdownLabel(deadline, now) + " to quote",
                    style = MaterialTheme.typography.bodySmall,
                    color = if (overdue) MaterialTheme.colorScheme.error
                    else MaterialTheme.colorScheme.primary,
                    fontWeight = FontWeight.SemiBold,
                )
            }
            if (onPlaceBid != null && rfq.isOpen) {
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
        )
        Text(
            text = "Quantity: ${form.quantity}",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
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
            modifier = Modifier.fillMaxWidth(),
        )
        if (form.unitPriceText.toDoubleOrNull() != null) {
            Text(
                text = "Total: ${formatRupees(form.totalPrice)}",
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.SemiBold,
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
                modifier = Modifier.weight(1f),
            )
        }

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text("Includes installation", style = MaterialTheme.typography.bodyMedium)
            Switch(checked = form.includesInstallation, onCheckedChange = onInstallChange)
        }
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text("Includes training", style = MaterialTheme.typography.bodyMedium)
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
            minLines = 2,
            modifier = Modifier.fillMaxWidth(),
        )

        Row(
            modifier = Modifier.fillMaxWidth().padding(top = Spacing.sm),
            horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
        ) {
            TextButton(
                onClick = onCancel,
                enabled = !submitting,
                modifier = Modifier.weight(1f),
            ) { Text("Cancel") }
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
