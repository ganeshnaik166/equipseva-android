package com.equipseva.app.features.repair

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
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.escrow.RepairJobEscrowRepository
import com.equipseva.app.core.payments.PendingEscrowPaymentsStore
import com.equipseva.app.core.payments.RazorpayCheckoutLauncher
import com.equipseva.app.core.util.formatRupees
import com.equipseva.app.designsystem.components.EsBottomSheet
import com.equipseva.app.designsystem.components.EsBtn
import com.equipseva.app.designsystem.components.EsBtnKind
import com.equipseva.app.designsystem.components.EsBtnSize
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

// v2.1 PR-D5 — bottom sheet that runs the per-job escrow pay-in
// end-to-end: createPaymentOrder → Razorpay Checkout → verifyPayment.
// Sister of AmcPaymentSheet (#268) but for the per-job escrow row,
// fixed amount (the contracted bid price), no months picker.

@HiltViewModel
class JobEscrowPaymentViewModel @Inject constructor(
    private val repo: RepairJobEscrowRepository,
    private val auth: AuthRepository,
    private val launcher: RazorpayCheckoutLauncher,
    private val pendingEscrowPaymentsStore: PendingEscrowPaymentsStore,
) : ViewModel() {

    data class UiState(val busy: Boolean = false, val error: String? = null)

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    suspend fun runCheckout(
        activity: Activity,
        repairJobId: String,
        engineerName: String,
    ): Boolean {
        if (_state.value.busy) return false
        _state.update { it.copy(busy = true, error = null) }

        val orderRes = repo.createPaymentOrder(repairJobId)
        if (orderRes.isFailure) {
            _state.update { it.copy(busy = false, error = orderRes.exceptionOrNull()?.message) }
            return false
        }
        val order = orderRes.getOrThrow()

        val session = auth.sessionState
            .filterIsInstance<AuthSession.SignedIn>()
            .firstOrNull()
        val email = session?.email

        // Round 280 — process-death recovery: persist the repair_job_id
        // so [PendingEscrowPaymentsReconciler] can clear the marker on
        // next cold-start (or surface it as in-flight to the user) if
        // Android kills our process while Razorpay's checkout activity
        // is foregrounded. Cleared in the `finally` regardless of
        // outcome — Razorpay's three result branches each fall through.
        runCatching { pendingEscrowPaymentsStore.add(repairJobId) }

        val result = try {
            runCatching {
                launcher.startPayment(
                    activity = activity,
                    amountPaise = order.amountPaise,
                    currency = order.currency,
                    name = "EquipSeva Escrow",
                    description = "Hold ${engineerName}'s payment until job is complete",
                    prefillEmail = email,
                    prefillContact = null,
                    razorpayOrderId = order.razorpayOrderId,
                    keyId = order.keyId,
                )
            }.getOrElse {
                _state.update { s -> s.copy(busy = false, error = it.message) }
                return false
            }
        } finally {
            // SDK returned cleanly — clear the recovery marker before
            // verify so the home banner doesn't surface a stale
            // "in-flight" pill. If verify itself crashes we re-add via
            // reconciler on next cold-start.
            runCatching { pendingEscrowPaymentsStore.remove(repairJobId) }
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
                val verifyRes = repo.verifyPayment(
                    escrowId = order.escrowId,
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

@Composable
fun JobEscrowPaymentSheet(
    repairJobId: String,
    amountRupees: Double,
    engineerName: String,
    onClose: () -> Unit,
    onShowMessage: (String) -> Unit,
    onCompleted: () -> Unit,
    viewModel: JobEscrowPaymentViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val context = LocalContext.current
    val activity = context as? Activity
    val scope = rememberCoroutineScope()

    LaunchedEffect(state.error) {
        state.error?.let {
            if (it.isNotBlank()) onShowMessage(it)
        }
    }

    EsBottomSheet(
        onClose = onClose,
        title = "Pay to start work",
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(
                "Funds sit in EquipSeva escrow until the engineer completes the job. Released automatically 48 hours after completion, or anytime you confirm — and refundable if the job is cancelled.",
                color = SevaInk500,
                fontSize = 12.sp,
            )
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(10.dp))
                    .background(Paper2)
                    .padding(horizontal = 14.dp, vertical = 12.dp),
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Column {
                        Text("Engineer", color = SevaInk500, fontSize = 11.sp)
                        Text(engineerName, color = SevaInk900, fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
                    }
                    Column(horizontalAlignment = Alignment.End) {
                        Text("Amount", color = SevaInk500, fontSize = 11.sp)
                        Text(
                            formatRupees(amountRupees),
                            color = SevaInk900,
                            fontSize = 18.sp,
                            fontWeight = FontWeight.Bold,
                        )
                    }
                }
            }
            Text(
                "You'll be redirected to Razorpay to complete payment. UPI, cards, and net banking are all supported.",
                color = SevaInk700,
                fontSize = 12.sp,
            )
            Spacer(Modifier.height(4.dp))
            EsBtn(
                text = if (state.busy) "Processing…" else "Pay ${formatRupees(amountRupees)}",
                kind = EsBtnKind.Primary,
                size = EsBtnSize.Lg,
                full = true,
                disabled = state.busy || activity == null,
                onClick = {
                    if (activity == null) {
                        onShowMessage("Couldn't start payment — try again from the main screen.")
                        return@EsBtn
                    }
                    scope.launch {
                        val ok = viewModel.runCheckout(activity, repairJobId, engineerName)
                        if (ok) {
                            onCompleted()
                            onClose()
                        }
                    }
                },
            )
            if (state.busy) {
                Box(
                    modifier = Modifier.fillMaxWidth(),
                    contentAlignment = Alignment.Center,
                ) {
                    CircularProgressIndicator(strokeWidth = 2.dp, modifier = Modifier.height(20.dp))
                }
            }
            Spacer(Modifier.height(8.dp))
        }
    }
}
