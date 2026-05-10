package com.equipseva.app.features.amc

import android.app.Activity
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.util.formatRupees
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.amc.AmcRepository
import com.equipseva.app.core.payments.RazorpayCheckoutLauncher
import com.equipseva.app.designsystem.components.EsBottomSheet
import com.equipseva.app.designsystem.components.EsBtn
import com.equipseva.app.designsystem.components.EsBtnKind
import com.equipseva.app.designsystem.components.EsBtnSize
import com.equipseva.app.designsystem.components.EsChip
import com.equipseva.app.designsystem.theme.Paper2
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk700
import com.equipseva.app.designsystem.theme.SevaInk900
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.filterIsInstance
import kotlinx.coroutines.flow.firstOrNull
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

@HiltViewModel
class AmcPaymentViewModel @Inject constructor(
    private val repo: AmcRepository,
    private val auth: AuthRepository,
    private val launcher: RazorpayCheckoutLauncher,
) : ViewModel() {

    data class UiState(val busy: Boolean = false, val error: String? = null)

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    /**
     * End-to-end checkout flow used by both the top-up sheet and the
     * wizard's first-month upfront payment. Returns true on a verified
     * paid charge; false on cancellation or any failure (caller shows
     * a snackbar with [UiState.error] in that case).
     */
    suspend fun runCheckout(
        activity: Activity,
        amcContractId: String,
        months: Int,
        engineerName: String,
    ): Boolean {
        if (_state.value.busy) return false
        _state.update { it.copy(busy = true, error = null) }

        // 1. Server creates the Razorpay order + binds it.
        val orderRes = repo.createPaymentOrder(amcContractId, months)
        if (orderRes.isFailure) {
            _state.update { it.copy(busy = false, error = orderRes.exceptionOrNull()?.message) }
            return false
        }
        val order = orderRes.getOrThrow()

        // 2. Resolve email for prefill (best-effort).
        val session = auth.sessionState
            .filterIsInstance<AuthSession.SignedIn>()
            .firstOrNull()
        val email = session?.email

        // 3. Launch Razorpay Standard Checkout.
        val result = runCatching {
            launcher.startPayment(
                activity = activity,
                amountPaise = order.amountPaise,
                currency = order.currency,
                name = "EquipSeva AMC",
                description = "$months month${if (months == 1) "" else "s"} for $engineerName",
                prefillEmail = email,
                prefillContact = null,
                razorpayOrderId = order.razorpayOrderId,
                keyId = order.keyId,
            )
        }.getOrElse {
            _state.update { s -> s.copy(busy = false, error = it.message) }
            return false
        }

        when (result) {
            is RazorpayCheckoutLauncher.RazorpayPaymentResult.Cancelled -> {
                _state.update { it.copy(busy = false, error = "Payment cancelled") }
                return false
            }
            is RazorpayCheckoutLauncher.RazorpayPaymentResult.Failed -> {
                _state.update { s ->
                    s.copy(
                        busy = false,
                        error = result.message ?: "Payment failed (${result.code})",
                    )
                }
                return false
            }
            is RazorpayCheckoutLauncher.RazorpayPaymentResult.Success -> {
                // 4. Verify on-server. The HMAC re-check is the gate.
                val verifyRes = repo.verifyPayment(
                    paymentOrderId = order.paymentOrderId,
                    razorpayOrderId = result.razorpayOrderId.ifBlank { order.razorpayOrderId },
                    razorpayPaymentId = result.razorpayPaymentId,
                    razorpaySignature = result.razorpaySignature,
                )
                return verifyRes.fold(
                    onSuccess = {
                        _state.update { it.copy(busy = false) }
                        true
                    },
                    onFailure = { e ->
                        _state.update { it.copy(busy = false, error = e.message) }
                        false
                    },
                )
            }
        }
    }
}

/**
 * Bottom sheet hospital uses to top up the AMC pool. Controls a 1..12
 * month picker and triggers the full Razorpay end-to-end on Confirm.
 *
 * The actual heavy lifting lives in [AmcPaymentViewModel.runCheckout];
 * this composable is just the UI shell + months picker.
 */
@Composable
fun AmcPaymentSheet(
    contractId: String,
    monthlyFeeRupees: Double,
    initialMonths: Int = 1,
    onMonthsChange: (Int) -> Unit = {},
    onClose: () -> Unit,
    onShowMessage: (String) -> Unit,
    onCompleted: () -> Unit,
    engineerName: String = "your engineer",
    viewModel: AmcPaymentViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsState()
    val context = LocalContext.current
    val activity = context as? Activity
    val scope = rememberCoroutineScope()
    var months by remember { mutableStateOf(initialMonths) }
    val total = monthlyFeeRupees * months

    LaunchedEffect(state.error) {
        state.error?.let {
            if (it.isNotBlank()) onShowMessage(it)
        }
    }

    EsBottomSheet(
        onClose = onClose,
        title = "Top up maintenance pool",
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(
                "Pre-pay 1 to 12 months of monthly fee. Engineer's per-visit share is deducted automatically as visits complete.",
                color = SevaInk500,
                fontSize = 12.sp,
            )
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                listOf(1, 3, 6, 12).forEach { m ->
                    EsChip(
                        text = "$m mo",
                        active = months == m,
                        onClick = {
                            months = m
                            onMonthsChange(m)
                        },
                    )
                }
            }
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(10.dp))
                    .background(Paper2)
                    .padding(14.dp),
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                    ) {
                        Text("Monthly fee", color = SevaInk700, fontSize = 13.sp)
                        Text(
                            "₹${monthlyFeeRupees.toInt()}",
                            color = SevaInk900,
                            fontSize = 13.sp,
                            fontWeight = FontWeight.SemiBold,
                        )
                    }
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                    ) {
                        Text("Months", color = SevaInk700, fontSize = 13.sp)
                        Text(
                            "$months",
                            color = SevaInk900,
                            fontSize = 13.sp,
                            fontWeight = FontWeight.SemiBold,
                        )
                    }
                    Spacer(Modifier.height(2.dp))
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                    ) {
                        Text("Total", color = SevaInk900, fontSize = 14.sp, fontWeight = FontWeight.Bold)
                        Text(
                            formatRupees(total),
                            color = SevaInk900,
                            fontSize = 14.sp,
                            fontWeight = FontWeight.Bold,
                        )
                    }
                }
            }
            EsBtn(
                text = if (state.busy) "Processing…" else "Pay ${formatRupees(total)}",
                onClick = {
                    if (activity == null) {
                        onShowMessage("Couldn't open Razorpay — please try again.")
                        return@EsBtn
                    }
                    scope.launch {
                        val ok = viewModel.runCheckout(
                            activity = activity,
                            amcContractId = contractId,
                            months = months,
                            engineerName = engineerName,
                        )
                        if (ok) {
                            onShowMessage("Payment received — pool updated.")
                            onCompleted()
                        }
                    }
                },
                kind = EsBtnKind.Primary,
                size = EsBtnSize.Lg,
                full = true,
                disabled = state.busy,
            )
            if (state.busy) {
                Box(modifier = Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }
            }
            Spacer(Modifier.height(8.dp))
        }
    }
}
