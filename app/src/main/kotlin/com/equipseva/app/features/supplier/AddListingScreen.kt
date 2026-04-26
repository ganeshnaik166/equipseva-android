package com.equipseva.app.features.supplier

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.CircularProgressIndicator
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
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
    val context = LocalContext.current

    LaunchedEffect(Unit) {
        viewModel.effects.collect { effect ->
            when (effect) {
                is AddListingViewModel.Effect.ShowMessage ->
                    snackbarHost.showSnackbar(effect.text)
                AddListingViewModel.Effect.NavigateBack -> onBack()
            }
        }
    }

    val imagePicker = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.OpenDocument(),
    ) { uri: Uri? ->
        uri ?: return@rememberLauncherForActivityResult
        val resolver = context.contentResolver
        val mime = resolver.getType(uri)
        val name = resolver.query(
            uri,
            arrayOf(android.provider.OpenableColumns.DISPLAY_NAME),
            null, null, null,
        )?.use { c -> if (c.moveToFirst()) c.getString(0) else null }
            ?: uri.lastPathSegment ?: "image"
        val bytes = resolver.openInputStream(uri)?.use { it.readBytes() } ?: return@rememberLauncherForActivityResult
        viewModel.addImage(name, bytes, mime)
    }

    if (state.catalogPickerOpen) {
        CatalogPickerSheet(
            query = state.catalogQuery,
            results = state.catalogResults,
            searching = state.catalogSearching,
            onQueryChange = viewModel::onCatalogQueryChange,
            onPick = viewModel::applyFromCatalog,
            onDismiss = viewModel::closeCatalogPicker,
        )
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

            // Quick prefill from the 25k-row hospital catalogue. Saves
            // sellers from re-typing brand / model / specs that we already
            // know server-side.
            item {
                FormColumn {
                    androidx.compose.material3.OutlinedButton(
                        onClick = viewModel::openCatalogPicker,
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Text("Prefill from hospital catalogue")
                    }
                }
            }

            item { SectionHeader(title = "Photos") }
            item {
                ImagesSection(
                    images = state.imageUrls,
                    uploading = state.uploadingImage,
                    onAdd = {
                        imagePicker.launch(arrayOf("image/jpeg", "image/png", "image/webp"))
                    },
                    onRemove = viewModel::removeImage,
                    canAdd = !state.noOrgWarning,
                )
            }

            item { SectionHeader(title = "Listing type") }
            item {
                FormColumn {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(Spacing.sm),
                    ) {
                        listOf("spare_part" to "Spare part", "equipment" to "Equipment").forEach { (key, label) ->
                            val selected = state.form.listingType == key
                            if (selected) {
                                androidx.compose.material3.Button(
                                    onClick = { viewModel.onListingTypeChange(key) },
                                    modifier = Modifier.weight(1f),
                                ) { Text(label) }
                            } else {
                                androidx.compose.material3.OutlinedButton(
                                    onClick = { viewModel.onListingTypeChange(key) },
                                    modifier = Modifier.weight(1f),
                                ) { Text(label) }
                            }
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
private fun ImagesSection(
    images: List<String>,
    uploading: Boolean,
    canAdd: Boolean,
    onAdd: () -> Unit,
    onRemove: (String) -> Unit,
) {
    val remainingSlots = AddListingViewModel.MAX_IMAGES - images.size
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = Spacing.lg),
        verticalArrangement = Arrangement.spacedBy(Spacing.xs),
    ) {
        LazyRow(horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
            items(images.size) { i ->
                val url = images[i]
                Box(modifier = Modifier.size(96.dp)) {
                    coil3.compose.AsyncImage(
                        model = url,
                        contentDescription = null,
                        contentScale = ContentScale.Crop,
                        modifier = Modifier
                            .fillMaxSize()
                            .clip(RoundedCornerShape(10.dp))
                            .background(MaterialTheme.colorScheme.surfaceVariant),
                    )
                    Box(
                        modifier = Modifier
                            .align(Alignment.TopEnd)
                            .padding(4.dp)
                            .size(22.dp)
                            .clip(CircleShape)
                            .background(Color.Black.copy(alpha = 0.6f))
                            .clickable { onRemove(url) },
                        contentAlignment = Alignment.Center,
                    ) {
                        Icon(
                            Icons.Filled.Close,
                            contentDescription = "Remove",
                            tint = Color.White,
                            modifier = Modifier.size(14.dp),
                        )
                    }
                }
            }
            if (remainingSlots > 0) {
                items(1) {
                    Box(
                        modifier = Modifier
                            .size(96.dp)
                            .clip(RoundedCornerShape(10.dp))
                            .border(
                                1.dp,
                                MaterialTheme.colorScheme.outline,
                                RoundedCornerShape(10.dp),
                            )
                            .clickable(enabled = canAdd && !uploading, onClick = onAdd),
                        contentAlignment = Alignment.Center,
                    ) {
                        if (uploading) {
                            CircularProgressIndicator(
                                modifier = Modifier.size(24.dp),
                                strokeWidth = 2.dp,
                            )
                        } else {
                            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                Icon(Icons.Filled.Add, contentDescription = "Add image")
                                Text(
                                    "Add photo",
                                    style = MaterialTheme.typography.labelSmall,
                                )
                            }
                        }
                    }
                }
            }
        }
        Text(
            "${images.size} / ${AddListingViewModel.MAX_IMAGES} photos · first photo is the cover",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
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

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun CatalogPickerSheet(
    query: String,
    results: List<com.equipseva.app.core.data.catalog.CatalogReferenceRepository.Item>,
    searching: Boolean,
    onQueryChange: (String) -> Unit,
    onPick: (com.equipseva.app.core.data.catalog.CatalogReferenceRepository.Item) -> Unit,
    onDismiss: () -> Unit,
) {
    val sheetState = androidx.compose.material3.rememberModalBottomSheetState(skipPartiallyExpanded = true)
    androidx.compose.material3.ModalBottomSheet(
        sheetState = sheetState,
        onDismissRequest = onDismiss,
    ) {
        Column(modifier = Modifier.fillMaxWidth().padding(Spacing.lg)) {
            Text(
                "Pick from hospital catalogue",
                style = MaterialTheme.typography.titleMedium,
                modifier = Modifier.padding(bottom = Spacing.sm),
            )
            OutlinedTextField(
                value = query,
                onValueChange = onQueryChange,
                placeholder = { Text("Search 25,000+ items…") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
            )
            androidx.compose.foundation.layout.Spacer(Modifier.size(Spacing.sm))
            if (searching) {
                androidx.compose.foundation.layout.Box(
                    modifier = Modifier.fillMaxWidth().padding(Spacing.lg),
                    contentAlignment = Alignment.Center,
                ) {
                    androidx.compose.material3.CircularProgressIndicator(
                        modifier = Modifier.size(28.dp),
                        strokeWidth = 2.dp,
                    )
                }
            } else if (results.isEmpty()) {
                Text(
                    "No matches. Try a brand or model name.",
                    style = MaterialTheme.typography.bodySmall,
                    modifier = Modifier.padding(Spacing.md),
                )
            } else {
                androidx.compose.foundation.lazy.LazyColumn(
                    modifier = Modifier.fillMaxWidth().heightIn(max = 480.dp),
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    items(results.size) { i ->
                        val item = results[i]
                        Column(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clip(androidx.compose.foundation.shape.RoundedCornerShape(10.dp))
                                .clickable { onPick(item) }
                                .padding(Spacing.sm),
                        ) {
                            Text(item.itemName, style = MaterialTheme.typography.bodyMedium)
                            Text(
                                listOfNotNull(item.brand, item.model, item.type)
                                    .joinToString(" · "),
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                    }
                }
            }
        }
    }
}
