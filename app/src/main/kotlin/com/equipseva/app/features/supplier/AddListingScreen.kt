package com.equipseva.app.features.supplier

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.MenuAnchorType
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.ui.Alignment
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
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.core.data.parts.PartCategory
import com.equipseva.app.designsystem.components.ESBackTopBar
import com.equipseva.app.designsystem.components.ErrorBanner
import com.equipseva.app.designsystem.components.PrimaryButton
import com.equipseva.app.designsystem.components.SectionHeader
import com.equipseva.app.designsystem.theme.Spacing

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddListingScreen(
    onBack: () -> Unit,
    viewModel: AddListingViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val snackbarHost = remember { SnackbarHostState() }

    LaunchedEffect(Unit) {
        viewModel.effects.collect { effect ->
            when (effect) {
                is AddListingViewModel.Effect.ShowMessage ->
                    snackbarHost.showSnackbar(effect.text)
                AddListingViewModel.Effect.NavigateBack -> onBack()
            }
        }
    }

    Scaffold(
        topBar = { ESBackTopBar(title = "Add listing", onBack = onBack) },
        snackbarHost = { SnackbarHost(snackbarHost) },
        bottomBar = {
            Surface(
                color = MaterialTheme.colorScheme.surface,
                tonalElevation = 3.dp,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Column {
                    HorizontalDivider()
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(Spacing.lg),
                    ) {
                        PrimaryButton(
                            label = "Save listing",
                            loading = state.submitting,
                            enabled = !state.submitting && !state.noOrgWarning,
                            onClick = viewModel::onSave,
                        )
                    }
                }
            }
        },
    ) { inner ->
        LazyColumn(
            modifier = Modifier
                .padding(inner)
                .fillMaxSize()
                .imePadding(),
            contentPadding = PaddingValues(vertical = Spacing.md),
            verticalArrangement = Arrangement.spacedBy(Spacing.sm),
        ) {
            if (state.noOrgWarning) {
                item {
                    ErrorBanner(
                        message = "Your account isn't linked to a supplier organization. " +
                            "Ask your admin to link it before publishing listings.",
                        modifier = Modifier.padding(horizontal = Spacing.lg),
                    )
                }
            }
            if (state.errorMessage != null) {
                item {
                    ErrorBanner(
                        message = state.errorMessage,
                        modifier = Modifier.padding(horizontal = Spacing.lg),
                    )
                }
            }

            item { SectionHeader(title = "Basics") }
            item {
                FormColumn {
                    OutlinedTextField(
                        value = state.form.name,
                        onValueChange = viewModel::onNameChange,
                        label = { Text("Name *") },
                        isError = state.showValidationErrors && state.form.nameError != null,
                        supportingText = {
                            state.form.nameError
                                ?.takeIf { state.showValidationErrors }
                                ?.let { Text(it) }
                        },
                        keyboardOptions = KeyboardOptions(
                            capitalization = KeyboardCapitalization.Words,
                            imeAction = ImeAction.Next,
                        ),
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth(),
                    )
                    OutlinedTextField(
                        value = state.form.partNumber,
                        onValueChange = viewModel::onPartNumberChange,
                        label = { Text("Part number *") },
                        isError = state.showValidationErrors && state.form.partNumberError != null,
                        supportingText = {
                            state.form.partNumberError
                                ?.takeIf { state.showValidationErrors }
                                ?.let { Text(it) }
                        },
                        keyboardOptions = KeyboardOptions(
                            capitalization = KeyboardCapitalization.Characters,
                            imeAction = ImeAction.Next,
                        ),
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth(),
                    )
                    CategoryDropdown(
                        selected = state.form.category,
                        onSelected = viewModel::onCategoryChange,
                    )
                }
            }

            item { SectionHeader(title = "Pricing & stock") }
            item {
                FormColumn {
                    Row(horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
                        OutlinedTextField(
                            value = state.form.priceText,
                            onValueChange = viewModel::onPriceChange,
                            label = { Text("Price (INR) *") },
                            isError = state.showValidationErrors && state.form.priceError != null,
                            supportingText = {
                                state.form.priceError
                                    ?.takeIf { state.showValidationErrors }
                                    ?.let { Text(it) }
                            },
                            keyboardOptions = KeyboardOptions(
                                keyboardType = KeyboardType.Decimal,
                                imeAction = ImeAction.Next,
                            ),
                            singleLine = true,
                            modifier = Modifier.weight(1f),
                        )
                        OutlinedTextField(
                            value = state.form.mrpText,
                            onValueChange = viewModel::onMrpChange,
                            label = { Text("MRP") },
                            isError = state.form.mrpError != null,
                            supportingText = { state.form.mrpError?.let { Text(it) } },
                            keyboardOptions = KeyboardOptions(
                                keyboardType = KeyboardType.Decimal,
                                imeAction = ImeAction.Next,
                            ),
                            singleLine = true,
                            modifier = Modifier.weight(1f),
                        )
                    }
                    Row(horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
                        OutlinedTextField(
                            value = state.form.stockQuantityText,
                            onValueChange = viewModel::onStockQuantityChange,
                            label = { Text("Stock qty *") },
                            isError = state.showValidationErrors && state.form.stockQuantityError != null,
                            supportingText = {
                                state.form.stockQuantityError
                                    ?.takeIf { state.showValidationErrors }
                                    ?.let { Text(it) }
                            },
                            keyboardOptions = KeyboardOptions(
                                keyboardType = KeyboardType.Number,
                                imeAction = ImeAction.Next,
                            ),
                            singleLine = true,
                            modifier = Modifier.weight(1f),
                        )
                        OutlinedTextField(
                            value = state.form.gstRateText,
                            onValueChange = viewModel::onGstRateChange,
                            label = { Text("GST %") },
                            isError = state.form.gstRateError != null,
                            supportingText = { state.form.gstRateError?.let { Text(it) } },
                            keyboardOptions = KeyboardOptions(
                                keyboardType = KeyboardType.Decimal,
                                imeAction = ImeAction.Next,
                            ),
                            singleLine = true,
                            modifier = Modifier.weight(1f),
                        )
                    }
                    OutlinedTextField(
                        value = state.form.discountPercentText,
                        onValueChange = viewModel::onDiscountPercentChange,
                        label = { Text("Discount %") },
                        isError = state.form.discountPercentError != null,
                        supportingText = { state.form.discountPercentError?.let { Text(it) } },
                        keyboardOptions = KeyboardOptions(
                            keyboardType = KeyboardType.Number,
                            imeAction = ImeAction.Next,
                        ),
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
            }

            item { SectionHeader(title = "Details") }
            item {
                FormColumn {
                    OutlinedTextField(
                        value = state.form.description,
                        onValueChange = viewModel::onDescriptionChange,
                        label = { Text("Description") },
                        keyboardOptions = KeyboardOptions(
                            capitalization = KeyboardCapitalization.Sentences,
                            imeAction = ImeAction.Next,
                        ),
                        minLines = 3,
                        modifier = Modifier.fillMaxWidth(),
                    )
                    OutlinedTextField(
                        value = state.form.warrantyMonthsText,
                        onValueChange = viewModel::onWarrantyMonthsChange,
                        label = { Text("Warranty (months)") },
                        isError = state.form.warrantyMonthsError != null,
                        supportingText = { state.form.warrantyMonthsError?.let { Text(it) } },
                        keyboardOptions = KeyboardOptions(
                            keyboardType = KeyboardType.Number,
                            imeAction = ImeAction.Next,
                        ),
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth(),
                    )
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text("Genuine part", style = MaterialTheme.typography.bodyMedium)
                        Switch(
                            checked = state.form.isGenuine,
                            onCheckedChange = viewModel::onIsGenuineChange,
                        )
                    }
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text("OEM part", style = MaterialTheme.typography.bodyMedium)
                        Switch(
                            checked = state.form.isOem,
                            onCheckedChange = viewModel::onIsOemChange,
                        )
                    }
                    Row(horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
                        OutlinedTextField(
                            value = state.form.sku,
                            onValueChange = viewModel::onSkuChange,
                            label = { Text("SKU") },
                            keyboardOptions = KeyboardOptions(
                                capitalization = KeyboardCapitalization.Characters,
                                imeAction = ImeAction.Next,
                            ),
                            singleLine = true,
                            modifier = Modifier.weight(1f),
                        )
                        OutlinedTextField(
                            value = state.form.hsnCode,
                            onValueChange = viewModel::onHsnCodeChange,
                            label = { Text("HSN code") },
                            keyboardOptions = KeyboardOptions(
                                keyboardType = KeyboardType.Number,
                                imeAction = ImeAction.Done,
                            ),
                            singleLine = true,
                            modifier = Modifier.weight(1f),
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun FormColumn(content: @Composable () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = Spacing.lg),
        verticalArrangement = Arrangement.spacedBy(Spacing.sm),
    ) {
        content()
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun CategoryDropdown(
    selected: PartCategory,
    onSelected: (PartCategory) -> Unit,
) {
    var expanded by remember { mutableStateOf(false) }
    ExposedDropdownMenuBox(
        expanded = expanded,
        onExpandedChange = { expanded = it },
    ) {
        OutlinedTextField(
            value = selected.displayName,
            onValueChange = {},
            readOnly = true,
            label = { Text("Category") },
            trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = expanded) },
            colors = ExposedDropdownMenuDefaults.outlinedTextFieldColors(),
            modifier = Modifier
                .fillMaxWidth()
                .menuAnchor(MenuAnchorType.PrimaryNotEditable, enabled = true),
        )
        DropdownMenu(
            expanded = expanded,
            onDismissRequest = { expanded = false },
        ) {
            PartCategory.entries.forEach { category ->
                DropdownMenuItem(
                    text = { Text(category.displayName) },
                    onClick = {
                        onSelected(category)
                        expanded = false
                    },
                )
            }
        }
    }
}
