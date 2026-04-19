package com.equipseva.app.features.hospital

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.CalendarToday
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.designsystem.components.ErrorBanner
import com.equipseva.app.designsystem.components.PrimaryButton
import com.equipseva.app.designsystem.components.SectionHeader
import com.equipseva.app.designsystem.theme.Spacing
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CreateRfqScreen(
    onBack: () -> Unit,
    viewModel: CreateRfqViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val snackbarHost = remember { SnackbarHostState() }
    var datePickerOpen by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        viewModel.effects.collect { effect ->
            when (effect) {
                is CreateRfqViewModel.Effect.ShowMessage -> snackbarHost.showSnackbar(effect.text)
                CreateRfqViewModel.Effect.NavigateBack -> onBack()
            }
        }
    }

    Scaffold(
        topBar = {
            CenterAlignedTopAppBar(
                title = { Text("Create RFQ") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                colors = TopAppBarDefaults.centerAlignedTopAppBarColors(
                    containerColor = MaterialTheme.colorScheme.primary,
                    titleContentColor = MaterialTheme.colorScheme.onPrimary,
                    navigationIconContentColor = MaterialTheme.colorScheme.onPrimary,
                ),
            )
        },
        snackbarHost = { SnackbarHost(snackbarHost) },
    ) { inner ->
        Column(
            modifier = Modifier
                .padding(inner)
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .imePadding(),
            verticalArrangement = Arrangement.spacedBy(Spacing.md),
        ) {
            SectionHeader(title = "RFQ details")

            ErrorBanner(
                message = state.errorMessage,
                modifier = Modifier.padding(horizontal = Spacing.lg),
            )

            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = Spacing.lg),
                verticalArrangement = Arrangement.spacedBy(Spacing.sm),
            ) {
                OutlinedTextField(
                    value = state.title,
                    onValueChange = viewModel::onTitleChange,
                    label = { Text("Title") },
                    isError = state.showValidationErrors && state.titleError != null,
                    supportingText = {
                        state.titleError?.takeIf { state.showValidationErrors }?.let { Text(it) }
                    },
                    keyboardOptions = KeyboardOptions(
                        capitalization = KeyboardCapitalization.Sentences,
                        imeAction = ImeAction.Next,
                    ),
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )

                OutlinedTextField(
                    value = state.description,
                    onValueChange = viewModel::onDescriptionChange,
                    label = { Text("Description (20+ chars)") },
                    isError = state.showValidationErrors && state.descriptionError != null,
                    supportingText = {
                        state.descriptionError?.takeIf { state.showValidationErrors }?.let { Text(it) }
                    },
                    keyboardOptions = KeyboardOptions(
                        capitalization = KeyboardCapitalization.Sentences,
                        imeAction = ImeAction.Default,
                    ),
                    minLines = 4,
                    maxLines = 8,
                    modifier = Modifier.fillMaxWidth(),
                )

                OutlinedTextField(
                    value = state.equipmentType,
                    onValueChange = viewModel::onEquipmentTypeChange,
                    label = { Text("Equipment type") },
                    placeholder = { Text("e.g. Ultrasound, Patient monitor") },
                    isError = state.showValidationErrors && state.equipmentTypeError != null,
                    supportingText = {
                        state.equipmentTypeError?.takeIf { state.showValidationErrors }?.let { Text(it) }
                    },
                    keyboardOptions = KeyboardOptions(
                        capitalization = KeyboardCapitalization.Words,
                        imeAction = ImeAction.Next,
                    ),
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )

                OutlinedTextField(
                    value = state.quantity,
                    onValueChange = viewModel::onQuantityChange,
                    label = { Text("Quantity") },
                    isError = state.showValidationErrors && state.quantityError != null,
                    supportingText = {
                        state.quantityError?.takeIf { state.showValidationErrors }?.let { Text(it) }
                    },
                    keyboardOptions = KeyboardOptions(
                        keyboardType = KeyboardType.Number,
                        imeAction = ImeAction.Next,
                    ),
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )
            }

            SectionHeader(title = "Budget (optional)")

            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = Spacing.lg),
                verticalArrangement = Arrangement.spacedBy(Spacing.sm),
            ) {
                Row(horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
                    OutlinedTextField(
                        value = state.budgetMin,
                        onValueChange = viewModel::onBudgetMinChange,
                        label = { Text("Min ₹") },
                        isError = state.showValidationErrors && state.budgetError != null,
                        keyboardOptions = KeyboardOptions(
                            keyboardType = KeyboardType.Decimal,
                            imeAction = ImeAction.Next,
                        ),
                        singleLine = true,
                        modifier = Modifier.weight(1f),
                    )
                    OutlinedTextField(
                        value = state.budgetMax,
                        onValueChange = viewModel::onBudgetMaxChange,
                        label = { Text("Max ₹") },
                        isError = state.showValidationErrors && state.budgetError != null,
                        keyboardOptions = KeyboardOptions(
                            keyboardType = KeyboardType.Decimal,
                            imeAction = ImeAction.Done,
                        ),
                        singleLine = true,
                        modifier = Modifier.weight(1f),
                    )
                }
                state.budgetError?.takeIf { state.showValidationErrors }?.let {
                    Text(
                        text = it,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.error,
                    )
                }
            }

            SectionHeader(title = "Expected delivery")

            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = Spacing.lg),
                verticalArrangement = Arrangement.spacedBy(Spacing.sm),
            ) {
                OutlinedTextField(
                    value = state.expectedDeliveryIso.orEmpty(),
                    onValueChange = { /* read-only */ },
                    readOnly = true,
                    label = { Text("Expected delivery date") },
                    placeholder = { Text("Tap calendar to pick a date") },
                    trailingIcon = {
                        IconButton(onClick = { datePickerOpen = true }) {
                            Icon(Icons.Filled.CalendarToday, contentDescription = "Pick date")
                        }
                    },
                    isError = state.showValidationErrors && state.deliveryError != null,
                    supportingText = {
                        state.deliveryError?.takeIf { state.showValidationErrors }?.let { Text(it) }
                    },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )
            }

            Spacer(Modifier.height(Spacing.md))

            PrimaryButton(
                label = "Submit RFQ",
                loading = state.submitting,
                onClick = viewModel::onSubmit,
                modifier = Modifier.padding(horizontal = Spacing.lg),
            )

            Spacer(Modifier.height(Spacing.lg))
        }
    }

    if (datePickerOpen) {
        val initialMillis = state.expectedDeliveryIso?.let { runCatching { isoToEpochMillis(it) }.getOrNull() }
        val pickerState = rememberDatePickerState(initialSelectedDateMillis = initialMillis)
        DatePickerDialog(
            onDismissRequest = { datePickerOpen = false },
            confirmButton = {
                TextButton(onClick = {
                    val millis = pickerState.selectedDateMillis
                    if (millis != null) {
                        viewModel.onDeliveryDateSelected(epochMillisToIso(millis))
                    }
                    datePickerOpen = false
                }) { Text("OK") }
            },
            dismissButton = {
                TextButton(onClick = { datePickerOpen = false }) { Text("Cancel") }
            },
        ) {
            DatePicker(state = pickerState)
        }
    }
}

private val IsoDateFormatter: DateTimeFormatter = DateTimeFormatter.ISO_LOCAL_DATE

private fun epochMillisToIso(millis: Long): String =
    Instant.ofEpochMilli(millis).atZone(ZoneOffset.UTC).toLocalDate().format(IsoDateFormatter)

private fun isoToEpochMillis(iso: String): Long =
    LocalDate.parse(iso, IsoDateFormatter).atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli()
