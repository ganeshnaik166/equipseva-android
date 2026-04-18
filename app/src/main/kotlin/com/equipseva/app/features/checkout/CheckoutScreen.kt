package com.equipseva.app.features.checkout

import android.app.Activity
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedCard
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.text.KeyboardOptions
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.core.util.formatRupees
import com.equipseva.app.designsystem.components.PrimaryButton
import com.equipseva.app.designsystem.components.SectionHeader
import com.equipseva.app.designsystem.theme.Spacing
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CheckoutScreen(
    onBack: () -> Unit,
    onOrderPlaced: (orderId: String) -> Unit,
    viewModel: CheckoutViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val snackbarHost = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()
    val context = LocalContext.current
    val activity = context as? Activity

    LaunchedEffect(Unit) {
        viewModel.effects.collect { effect ->
            when (effect) {
                is CheckoutViewModel.Effect.LaunchRazorpay -> {
                    val act = activity ?: return@collect
                    scope.launch {
                        val result = viewModel.launchRazorpay(act, effect.request)
                        viewModel.onPaymentResult(result)
                    }
                }
                is CheckoutViewModel.Effect.OpenOrder -> onOrderPlaced(effect.orderId)
                is CheckoutViewModel.Effect.ShowMessage -> snackbarHost.showSnackbar(effect.text)
            }
        }
    }

    Scaffold(
        topBar = {
            CenterAlignedTopAppBar(
                title = { Text("Checkout") },
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
        bottomBar = {
            CheckoutBottomBar(
                totalRupees = state.totalRupees,
                submitting = state.submitting,
                enabled = !state.loading && state.snapshot.isNotEmpty() && !state.supplierConflict,
                onSubmit = viewModel::onPlaceOrder,
            )
        },
    ) { inner ->
        Column(
            modifier = Modifier
                .padding(inner)
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .imePadding(),
            verticalArrangement = Arrangement.spacedBy(Spacing.md),
        ) {
            if (state.supplierConflict) {
                Surface(
                    color = MaterialTheme.colorScheme.errorContainer,
                    contentColor = MaterialTheme.colorScheme.onErrorContainer,
                    shape = RoundedCornerShape(Spacing.md),
                    modifier = Modifier
                        .padding(horizontal = Spacing.lg)
                        .fillMaxWidth(),
                ) {
                    Text(
                        text = "Your cart has items from more than one supplier. Remove some lines to continue — multi-supplier orders aren't supported yet.",
                        style = MaterialTheme.typography.bodyMedium,
                        modifier = Modifier.padding(Spacing.md),
                    )
                }
            }

            SectionHeader(
                title = "Shipping address",
                modifier = Modifier.padding(horizontal = Spacing.lg),
            )
            AddressForm(
                form = state.form,
                showErrors = state.showValidationErrors,
                onFullNameChange = viewModel::onFullNameChange,
                onPhoneChange = viewModel::onPhoneChange,
                onAddressChange = viewModel::onAddressChange,
                onCityChange = viewModel::onCityChange,
                onStateChange = viewModel::onStateChange,
                onPincodeChange = viewModel::onPincodeChange,
            )

            SectionHeader(
                title = "Order summary",
                modifier = Modifier.padding(horizontal = Spacing.lg),
            )
            OrderSummaryCard(state = state)

            Spacer(Modifier.height(Spacing.lg))
        }
    }
}

@Composable
private fun AddressForm(
    form: CheckoutViewModel.FormState,
    showErrors: Boolean,
    onFullNameChange: (String) -> Unit,
    onPhoneChange: (String) -> Unit,
    onAddressChange: (String) -> Unit,
    onCityChange: (String) -> Unit,
    onStateChange: (String) -> Unit,
    onPincodeChange: (String) -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = Spacing.lg),
        verticalArrangement = Arrangement.spacedBy(Spacing.sm),
    ) {
        OutlinedTextField(
            value = form.fullName,
            onValueChange = onFullNameChange,
            label = { Text("Full name") },
            isError = showErrors && form.fullNameError != null,
            supportingText = { form.fullNameError?.takeIf { showErrors }?.let { Text(it) } },
            keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Words, imeAction = ImeAction.Next),
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
        )
        OutlinedTextField(
            value = form.phone,
            onValueChange = onPhoneChange,
            label = { Text("Phone (10 digits)") },
            isError = showErrors && form.phoneError != null,
            supportingText = { form.phoneError?.takeIf { showErrors }?.let { Text(it) } },
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone, imeAction = ImeAction.Next),
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
        )
        OutlinedTextField(
            value = form.addressLine,
            onValueChange = onAddressChange,
            label = { Text("Street address") },
            isError = showErrors && form.addressError != null,
            supportingText = { form.addressError?.takeIf { showErrors }?.let { Text(it) } },
            keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Words, imeAction = ImeAction.Next),
            modifier = Modifier.fillMaxWidth(),
        )
        Row(horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
            OutlinedTextField(
                value = form.city,
                onValueChange = onCityChange,
                label = { Text("City") },
                isError = showErrors && form.cityError != null,
                supportingText = { form.cityError?.takeIf { showErrors }?.let { Text(it) } },
                keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Words, imeAction = ImeAction.Next),
                singleLine = true,
                modifier = Modifier.weight(1f),
            )
            OutlinedTextField(
                value = form.state,
                onValueChange = onStateChange,
                label = { Text("State") },
                isError = showErrors && form.stateError != null,
                supportingText = { form.stateError?.takeIf { showErrors }?.let { Text(it) } },
                keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Words, imeAction = ImeAction.Next),
                singleLine = true,
                modifier = Modifier.weight(1f),
            )
        }
        OutlinedTextField(
            value = form.pincode,
            onValueChange = onPincodeChange,
            label = { Text("PIN code") },
            isError = showErrors && form.pincodeError != null,
            supportingText = { form.pincodeError?.takeIf { showErrors }?.let { Text(it) } },
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.NumberPassword, imeAction = ImeAction.Done),
            singleLine = true,
            modifier = Modifier.fillMaxWidth().width(200.dp),
        )
    }
}

@Composable
private fun OrderSummaryCard(state: CheckoutViewModel.UiState) {
    OutlinedCard(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = Spacing.lg),
    ) {
        Column(
            modifier = Modifier.padding(Spacing.md),
            verticalArrangement = Arrangement.spacedBy(Spacing.sm),
        ) {
            state.snapshot.forEach { line ->
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                ) {
                    Text(
                        text = "${line.part.name} × ${line.item.quantity}",
                        style = MaterialTheme.typography.bodyMedium,
                        modifier = Modifier.weight(1f),
                    )
                    Text(
                        text = formatRupees(line.lineSubtotalRupees),
                        style = MaterialTheme.typography.bodyMedium,
                    )
                }
            }
            HorizontalDivider()
            TotalRow("Subtotal", formatRupees(state.subtotalRupees))
            TotalRow("GST", formatRupees(state.gstRupees))
            TotalRow("Shipping", if (state.shippingRupees == 0.0) "Free" else formatRupees(state.shippingRupees))
            HorizontalDivider()
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                Text(
                    text = "Total",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                )
                Text(
                    text = formatRupees(state.totalRupees),
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.primary,
                )
            }
        }
    }
}

@Composable
private fun TotalRow(label: String, value: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Text(text = value, style = MaterialTheme.typography.bodyMedium)
    }
}

@Composable
private fun CheckoutBottomBar(
    totalRupees: Double,
    submitting: Boolean,
    enabled: Boolean,
    onSubmit: () -> Unit,
) {
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
                verticalArrangement = Arrangement.spacedBy(Spacing.sm),
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        text = "Pay with Razorpay",
                        style = MaterialTheme.typography.titleMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Text(
                        text = formatRupees(totalRupees),
                        style = MaterialTheme.typography.headlineSmall,
                        fontWeight = FontWeight.SemiBold,
                    )
                }
                PrimaryButton(
                    label = "Place order",
                    enabled = enabled,
                    loading = submitting,
                    onClick = onSubmit,
                )
            }
        }
    }
}
