package com.equipseva.app.features.checkout

import android.app.Activity
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AccountBalance
import androidx.compose.material.icons.filled.AccountBalanceWallet
import androidx.compose.material.icons.filled.CreditCard
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.MedicalServices
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import coil3.compose.AsyncImage
import com.equipseva.app.core.util.formatRupees
import com.equipseva.app.designsystem.components.ESBackTopBar
import com.equipseva.app.designsystem.components.GradientTile
import com.equipseva.app.designsystem.components.SecureScreen
import com.equipseva.app.designsystem.components.SectionHeader
import com.equipseva.app.designsystem.theme.BrandGreen
import com.equipseva.app.designsystem.theme.BrandGreen50
import com.equipseva.app.designsystem.theme.BrandGreenDark
import com.equipseva.app.designsystem.theme.Ink300
import com.equipseva.app.designsystem.theme.Ink500
import com.equipseva.app.designsystem.theme.Ink700
import com.equipseva.app.designsystem.theme.Ink900
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.designsystem.theme.Surface0
import com.equipseva.app.designsystem.theme.Surface100
import com.equipseva.app.designsystem.theme.Surface200
import com.equipseva.app.designsystem.theme.Surface50
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CheckoutScreen(
    onBack: () -> Unit,
    onOrderPlaced: (orderId: String) -> Unit,
    viewModel: CheckoutViewModel = hiltViewModel(),
) {
    SecureScreen()
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

    // Address starts expanded if the form isn't already complete (newly-minted session).
    var addressExpanded by remember { mutableStateOf(true) }
    var selectedPayment by remember { mutableStateOf("upi") }

    Scaffold(
        topBar = { ESBackTopBar(title = "Checkout", onBack = onBack) },
        snackbarHost = { SnackbarHost(snackbarHost) },
        containerColor = Surface50,
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
                .imePadding()
                .background(Surface50),
            verticalArrangement = Arrangement.spacedBy(0.dp),
        ) {
            if (state.supplierConflict) {
                Surface(
                    color = MaterialTheme.colorScheme.errorContainer,
                    contentColor = MaterialTheme.colorScheme.onErrorContainer,
                    shape = RoundedCornerShape(5.dp),
                    modifier = Modifier
                        .padding(horizontal = Spacing.lg, vertical = Spacing.sm)
                        .fillMaxWidth(),
                ) {
                    Text(
                        text = "Your cart has items from more than one supplier. " +
                            "Remove some lines to continue — multi-supplier orders aren't supported yet.",
                        style = MaterialTheme.typography.bodyMedium,
                        modifier = Modifier.padding(Spacing.md),
                    )
                }
            }

            // Delivery address
            SectionHeader(
                title = "Delivery address",
                actionLabel = if (addressExpanded) "Done" else "Change",
                onAction = { addressExpanded = !addressExpanded },
            )
            AddressCard(form = state.form)

            AnimatedVisibility(visible = addressExpanded) {
                AddressFormFields(
                    form = state.form,
                    showErrors = state.showValidationErrors,
                    onFullNameChange = viewModel::onFullNameChange,
                    onPhoneChange = viewModel::onPhoneChange,
                    onAddressChange = viewModel::onAddressChange,
                    onCityChange = viewModel::onCityChange,
                    onStateChange = viewModel::onStateChange,
                    onPincodeChange = viewModel::onPincodeChange,
                )
            }

            // Payment method
            SectionHeader(title = "Payment method")
            if (com.equipseva.app.BuildConfig.RAZORPAY_KEY.startsWith("rzp_test_")) {
                androidx.compose.material3.AssistChip(
                    onClick = {},
                    label = { androidx.compose.material3.Text("Razorpay TEST mode — no real charge") },
                    colors = androidx.compose.material3.AssistChipDefaults.assistChipColors(
                        containerColor = com.equipseva.app.designsystem.theme.WarningBg,
                        labelColor = com.equipseva.app.designsystem.theme.Warning,
                    ),
                )
                Spacer(Modifier.height(Spacing.sm))
            }
            PaymentMethodList(
                selected = selectedPayment,
                onSelect = { selectedPayment = it },
            )

            // Order summary
            SectionHeader(title = "Order summary")
            OrderSummaryCard(state = state)

            Spacer(Modifier.height(Spacing.xl))
        }
    }

    if (state.showKycSheet) {
        BuyerKycSheet(
            status = state.buyerKycStatus,
            saving = state.kycUploading,
            error = state.kycError,
            rejectionReason = state.kycRejectionReason,
            onDismiss = { viewModel.dismissKycSheet() },
            onSubmit = { _, _, pickFile -> pickFile() },
            onPickedFile = { ctx, uri, doc, gst -> viewModel.submitKycDoc(ctx, uri, doc, gst) },
        )
    }
}

/* ------------------------------------------------------------------ */
/* Address card                                                       */
/* ------------------------------------------------------------------ */

@Composable
private fun AddressCard(form: CheckoutViewModel.FormState) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = Spacing.lg),
        shape = RoundedCornerShape(5.dp),
        colors = CardDefaults.cardColors(containerColor = Surface0),
        border = BorderStroke(1.dp, Surface200),
        elevation = CardDefaults.cardElevation(defaultElevation = 0.dp),
    ) {
        Row(
            modifier = Modifier.padding(14.dp),
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Icon(
                imageVector = Icons.Filled.LocationOn,
                contentDescription = null,
                tint = BrandGreen,
                modifier = Modifier
                    .size(24.dp)
                    .padding(top = 2.dp),
            )
            Column(modifier = Modifier.weight(1f)) {
                val name = form.fullName.ifBlank { "Delivery contact" }
                Text(
                    text = name,
                    fontSize = 14.sp,
                    lineHeight = 18.sp,
                    fontWeight = FontWeight.Bold,
                    color = Ink900,
                )
                val addressBits = listOfNotNull(
                    form.addressLine.takeIf { it.isNotBlank() },
                    listOf(form.city, form.state, form.pincode)
                        .filter { it.isNotBlank() }
                        .joinToString(", ")
                        .takeIf { it.isNotBlank() },
                    form.phone.takeIf { it.isNotBlank() }?.let { "+91 $it" },
                )
                val addressText = if (addressBits.isNotEmpty()) addressBits.joinToString(" · ")
                    else "Enter a delivery address to continue."
                Text(
                    text = addressText,
                    fontSize = 13.sp,
                    lineHeight = 18.sp,
                    color = Ink700,
                    modifier = Modifier.padding(top = 2.dp),
                )
                Box(
                    modifier = Modifier
                        .padding(top = 8.dp)
                        .clip(RoundedCornerShape(50))
                        .background(BrandGreen50)
                        .padding(horizontal = 10.dp, vertical = 4.dp),
                ) {
                    Text(
                        text = "Default",
                        fontSize = 12.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = BrandGreenDark,
                    )
                }
            }
        }
    }
}

/* ------------------------------------------------------------------ */
/* Address form (inline, beneath the card)                            */
/* ------------------------------------------------------------------ */

@Composable
private fun AddressFormFields(
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
            .padding(horizontal = Spacing.lg, vertical = Spacing.sm),
        verticalArrangement = Arrangement.spacedBy(Spacing.sm),
    ) {
        OutlinedTextField(
            value = form.fullName,
            onValueChange = onFullNameChange,
            label = { Text("Full name") },
            isError = showErrors && form.fullNameError != null,
            supportingText = {
                form.fullNameError?.takeIf { showErrors }?.let { Text(it) }
            },
            keyboardOptions = KeyboardOptions(
                capitalization = KeyboardCapitalization.Words,
                imeAction = ImeAction.Next,
            ),
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
        )
        OutlinedTextField(
            value = form.phone,
            onValueChange = onPhoneChange,
            label = { Text("Phone (10 digits)") },
            isError = showErrors && form.phoneError != null,
            supportingText = {
                form.phoneError?.takeIf { showErrors }?.let { Text(it) }
            },
            keyboardOptions = KeyboardOptions(
                keyboardType = KeyboardType.Phone,
                imeAction = ImeAction.Next,
            ),
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
        )
        OutlinedTextField(
            value = form.addressLine,
            onValueChange = onAddressChange,
            label = { Text("Street address") },
            isError = showErrors && form.addressError != null,
            supportingText = {
                form.addressError?.takeIf { showErrors }?.let { Text(it) }
            },
            keyboardOptions = KeyboardOptions(
                capitalization = KeyboardCapitalization.Words,
                imeAction = ImeAction.Next,
            ),
            modifier = Modifier.fillMaxWidth(),
        )
        Row(horizontalArrangement = Arrangement.spacedBy(Spacing.sm)) {
            OutlinedTextField(
                value = form.city,
                onValueChange = onCityChange,
                label = { Text("City") },
                isError = showErrors && form.cityError != null,
                supportingText = {
                    form.cityError?.takeIf { showErrors }?.let { Text(it) }
                },
                keyboardOptions = KeyboardOptions(
                    capitalization = KeyboardCapitalization.Words,
                    imeAction = ImeAction.Next,
                ),
                singleLine = true,
                modifier = Modifier.weight(1f),
            )
            OutlinedTextField(
                value = form.state,
                onValueChange = onStateChange,
                label = { Text("State") },
                isError = showErrors && form.stateError != null,
                supportingText = {
                    form.stateError?.takeIf { showErrors }?.let { Text(it) }
                },
                keyboardOptions = KeyboardOptions(
                    capitalization = KeyboardCapitalization.Words,
                    imeAction = ImeAction.Next,
                ),
                singleLine = true,
                modifier = Modifier.weight(1f),
            )
        }
        OutlinedTextField(
            value = form.pincode,
            onValueChange = onPincodeChange,
            label = { Text("PIN code") },
            isError = showErrors && form.pincodeError != null,
            supportingText = {
                form.pincodeError?.takeIf { showErrors }?.let { Text(it) }
            },
            keyboardOptions = KeyboardOptions(
                keyboardType = KeyboardType.NumberPassword,
                imeAction = ImeAction.Done,
            ),
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
        )
    }
}

/* ------------------------------------------------------------------ */
/* Payment method                                                     */
/* ------------------------------------------------------------------ */

private data class PayOption(val id: String, val label: String, val sub: String, val icon: ImageVector)

@Composable
private fun PaymentMethodList(selected: String, onSelect: (String) -> Unit) {
    val options = listOf(
        PayOption("upi", "UPI", "GPay, PhonePe, Paytm", Icons.Filled.AccountBalance),
        PayOption("card", "Card", "Visa, Mastercard, Rupay", Icons.Filled.CreditCard),
        PayOption("nb", "Net banking", "All major Indian banks", Icons.Filled.AccountBalanceWallet),
    )
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = Spacing.lg),
        shape = RoundedCornerShape(5.dp),
        colors = CardDefaults.cardColors(containerColor = Surface0),
        border = BorderStroke(1.dp, Surface200),
        elevation = CardDefaults.cardElevation(defaultElevation = 0.dp),
    ) {
        Column {
            options.forEachIndexed { i, option ->
                PaymentRow(
                    option = option,
                    selected = option.id == selected,
                    onClick = { onSelect(option.id) },
                )
                if (i < options.size - 1) {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(1.dp)
                            .background(Surface100),
                    )
                }
            }
        }
    }
}

@Composable
private fun PaymentRow(option: PayOption, selected: Boolean, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Box(
            modifier = Modifier
                .size(36.dp)
                .clip(RoundedCornerShape(5.dp))
                .background(BrandGreen50),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = option.icon,
                contentDescription = null,
                tint = BrandGreenDark,
                modifier = Modifier.size(20.dp),
            )
        }
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = option.label,
                fontSize = 14.sp,
                lineHeight = 18.sp,
                fontWeight = FontWeight.Bold,
                color = Ink900,
            )
            Text(
                text = option.sub,
                fontSize = 12.sp,
                lineHeight = 15.sp,
                color = Ink500,
            )
        }
        Radio(selected = selected)
    }
}

@Composable
private fun Radio(selected: Boolean) {
    Box(
        modifier = Modifier
            .size(22.dp)
            .clip(CircleShape)
            .background(if (selected) MaterialTheme.colorScheme.primary else Color.Transparent)
            .border(
                width = 2.dp,
                color = if (selected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.outline,
                shape = CircleShape,
            ),
        contentAlignment = Alignment.Center,
    ) {
        if (selected) {
            Box(
                modifier = Modifier
                    .size(10.dp)
                    .clip(CircleShape)
                    .background(MaterialTheme.colorScheme.onPrimary),
            )
        }
    }
}

/* ------------------------------------------------------------------ */
/* Summary                                                            */
/* ------------------------------------------------------------------ */

@Composable
private fun OrderSummaryCard(state: CheckoutViewModel.UiState) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = Spacing.lg),
        shape = RoundedCornerShape(5.dp),
        colors = CardDefaults.cardColors(containerColor = Surface0),
        border = BorderStroke(1.dp, Surface200),
        elevation = CardDefaults.cardElevation(defaultElevation = 0.dp),
    ) {
        Column(modifier = Modifier.padding(14.dp)) {
            state.snapshot.forEach { line ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 5.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    val imageUrl = line.part.primaryImageUrl?.takeIf { it.isNotBlank() }
                    if (imageUrl != null) {
                        AsyncImage(
                            model = imageUrl,
                            contentDescription = null,
                            contentScale = ContentScale.Crop,
                            modifier = Modifier
                                .size(40.dp)
                                .clip(RoundedCornerShape(5.dp)),
                        )
                    } else {
                        GradientTile(
                            icon = Icons.Filled.MedicalServices,
                            hue = 40,
                            size = 40.dp,
                        )
                    }
                    Text(
                        text = "${line.item.quantity}× ${line.part.name}",
                        fontSize = 13.sp,
                        lineHeight = 16.sp,
                        color = Ink700,
                        modifier = Modifier.weight(1f),
                    )
                    Text(
                        text = formatRupees(line.lineSubtotalRupees),
                        fontSize = 13.sp,
                        lineHeight = 16.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = Ink900,
                    )
                }
            }
            SummaryRow("GST", formatRupees(state.gstRupees))
            SummaryRow(
                "Delivery",
                if (state.shippingRupees == 0.0) "FREE" else formatRupees(state.shippingRupees),
            )
            Spacer(Modifier.height(Spacing.xs))
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(1.dp)
                    .background(Surface200),
            )
            Spacer(Modifier.height(10.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = "Total",
                    fontSize = 14.sp,
                    lineHeight = 18.sp,
                    fontWeight = FontWeight.Bold,
                    color = Ink900,
                )
                Text(
                    text = formatRupees(state.totalRupees),
                    fontSize = 18.sp,
                    lineHeight = 22.sp,
                    fontWeight = FontWeight.Bold,
                    color = BrandGreenDark,
                )
            }
        }
    }
}

@Composable
private fun SummaryRow(label: String, value: String) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 5.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(text = label, fontSize = 13.sp, lineHeight = 16.sp, color = Ink700)
        Text(
            text = value,
            fontSize = 13.sp,
            lineHeight = 16.sp,
            fontWeight = FontWeight.SemiBold,
            color = Ink900,
        )
    }
}

/* ------------------------------------------------------------------ */
/* Bottom CTA                                                         */
/* ------------------------------------------------------------------ */

@Composable
private fun CheckoutBottomBar(
    totalRupees: Double,
    submitting: Boolean,
    enabled: Boolean,
    onSubmit: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(Surface0)
            .border(1.dp, Surface200, RoundedCornerShape(0.dp))
            .padding(16.dp),
    ) {
        Button(
            onClick = onSubmit,
            enabled = enabled && !submitting,
            modifier = Modifier
                .fillMaxWidth()
                .height(56.dp),
            shape = RoundedCornerShape(50),
            colors = ButtonDefaults.buttonColors(containerColor = BrandGreen),
        ) {
            Text(
                text = if (submitting) "Processing…" else "Pay ${formatRupees(totalRupees)}",
                fontSize = 16.sp,
                fontWeight = FontWeight.SemiBold,
            )
            Spacer(Modifier.width(8.dp))
            Icon(
                imageVector = Icons.Filled.Lock,
                contentDescription = null,
                modifier = Modifier.size(18.dp),
            )
        }
    }
}
