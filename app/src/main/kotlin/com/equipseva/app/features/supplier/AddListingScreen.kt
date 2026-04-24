package com.equipseva.app.features.supplier

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.PhotoCamera
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.MenuAnchorType
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.core.data.parts.PartCategory
import com.equipseva.app.designsystem.components.ESBackTopBar
import com.equipseva.app.designsystem.components.EquipmentArt
import com.equipseva.app.designsystem.components.ErrorBanner
import com.equipseva.app.designsystem.components.GradientTile
import com.equipseva.app.designsystem.components.PrimaryButton
import com.equipseva.app.designsystem.components.SectionHeader
import com.equipseva.app.designsystem.theme.BrandGreenDark
import com.equipseva.app.designsystem.theme.Ink500
import com.equipseva.app.designsystem.theme.Ink900
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.designsystem.theme.Surface0
import com.equipseva.app.designsystem.theme.Surface50

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
        containerColor = Surface50,
        bottomBar = {
            Surface(
                color = Surface0,
                tonalElevation = 0.dp,
                shadowElevation = 8.dp,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Column {
                    HorizontalDivider(
                        thickness = 1.dp,
                        color = MaterialTheme.colorScheme.outlineVariant,
                    )
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = Spacing.lg, vertical = Spacing.md),
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
                .background(Surface50)
                .imePadding(),
            contentPadding = PaddingValues(bottom = Spacing.lg),
            verticalArrangement = Arrangement.spacedBy(Spacing.xs),
        ) {
            if (state.noOrgWarning) {
                item {
                    ErrorBanner(
                        message = "Your account isn't linked to a supplier organization. " +
                            "Ask your admin to link it before publishing listings.",
                        modifier = Modifier.padding(horizontal = Spacing.lg, vertical = Spacing.sm),
                    )
                }
            }
            if (state.errorMessage != null) {
                item {
                    ErrorBanner(
                        message = state.errorMessage,
                        modifier = Modifier.padding(horizontal = Spacing.lg, vertical = Spacing.sm),
                    )
                }
            }

            // Photo upload placeholder
            item {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = Spacing.lg, vertical = Spacing.md),
                    verticalArrangement = Arrangement.spacedBy(Spacing.sm),
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(Spacing.md),
                    ) {
                        Box {
                            GradientTile(
                                art = EquipmentArt.Image,
                                hue = 160,
                                size = 64.dp,
                            )
                            Box(
                                modifier = Modifier
                                    .align(Alignment.BottomEnd)
                                    .size(22.dp)
                                    .background(
                                        color = BrandGreenDark,
                                        shape = RoundedCornerShape(percent = 50),
                                    ),
                                contentAlignment = Alignment.Center,
                            ) {
                                Icon(
                                    imageVector = Icons.Filled.PhotoCamera,
                                    contentDescription = null,
                                    tint = Surface0,
                                    modifier = Modifier.size(14.dp),
                                )
                            }
                        }
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                text = "Add photos",
                                fontSize = 14.sp,
                                lineHeight = 18.sp,
                                fontWeight = FontWeight.SemiBold,
                                color = Ink900,
                            )
                            Text(
                                text = "Photo upload coming soon",
                                fontSize = 11.sp,
                                lineHeight = 14.sp,
                                color = Ink500,
                            )
                        }
                    }
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
                        shape = RoundedCornerShape(8.dp),
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
                        shape = RoundedCornerShape(8.dp),
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
                            shape = RoundedCornerShape(8.dp),
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
                            shape = RoundedCornerShape(8.dp),
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
                            shape = RoundedCornerShape(8.dp),
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
                            shape = RoundedCornerShape(8.dp),
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
                        shape = RoundedCornerShape(8.dp),
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
            }

            item { SectionHeader(title = "Compatibility") }
            item {
                FormColumn {
                    OutlinedTextField(
                        value = state.form.compatibleBrandsText,
                        onValueChange = viewModel::onCompatibleBrandsChange,
                        label = { Text("Compatible brands") },
                        placeholder = { Text("e.g. GE, Philips, Siemens") },
                        supportingText = { Text("Separate multiple values with a comma") },
                        keyboardOptions = KeyboardOptions(
                            capitalization = KeyboardCapitalization.Words,
                            imeAction = ImeAction.Next,
                        ),
                        singleLine = true,
                        shape = RoundedCornerShape(8.dp),
                        modifier = Modifier.fillMaxWidth(),
                    )
                    OutlinedTextField(
                        value = state.form.compatibleModelsText,
                        onValueChange = viewModel::onCompatibleModelsChange,
                        label = { Text("Compatible models") },
                        placeholder = { Text("e.g. Innova 2100, LOGIQ E9") },
                        supportingText = { Text("Separate multiple values with a comma") },
                        keyboardOptions = KeyboardOptions(
                            capitalization = KeyboardCapitalization.Words,
                            imeAction = ImeAction.Next,
                        ),
                        singleLine = true,
                        shape = RoundedCornerShape(8.dp),
                        modifier = Modifier.fillMaxWidth(),
                    )
                    OutlinedTextField(
                        value = state.form.compatibleEquipmentCategoriesText,
                        onValueChange = viewModel::onCompatibleEquipmentCategoriesChange,
                        label = { Text("Equipment categories") },
                        placeholder = { Text("e.g. MRI, CT Scanner, Ultrasound") },
                        supportingText = { Text("Separate multiple values with a comma") },
                        keyboardOptions = KeyboardOptions(
                            capitalization = KeyboardCapitalization.Words,
                            imeAction = ImeAction.Next,
                        ),
                        singleLine = true,
                        shape = RoundedCornerShape(8.dp),
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
                        shape = RoundedCornerShape(8.dp),
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
                        shape = RoundedCornerShape(8.dp),
                        modifier = Modifier.fillMaxWidth(),
                    )
                    Surface(
                        color = Surface0,
                        shape = RoundedCornerShape(8.dp),
                        tonalElevation = 0.dp,
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Column {
                            ToggleRow(
                                label = "Genuine part",
                                checked = state.form.isGenuine,
                                onChange = viewModel::onIsGenuineChange,
                            )
                            HorizontalDivider(
                                color = MaterialTheme.colorScheme.outlineVariant,
                            )
                            ToggleRow(
                                label = "OEM part",
                                checked = state.form.isOem,
                                onChange = viewModel::onIsOemChange,
                            )
                        }
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
                            shape = RoundedCornerShape(8.dp),
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
                            shape = RoundedCornerShape(8.dp),
                            modifier = Modifier.weight(1f),
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun ToggleRow(
    label: String,
    checked: Boolean,
    onChange: (Boolean) -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = Spacing.md, vertical = Spacing.sm),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.Medium,
            color = Ink900,
        )
        Switch(checked = checked, onCheckedChange = onChange)
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
            shape = RoundedCornerShape(8.dp),
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
