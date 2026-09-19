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
import com.equipseva.app.core.network.toUserMessage
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.equipseva.app.R
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.util.formatRupeesPaise
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.amc.AmcRepository
import com.equipseva.app.core.payments.RazorpayCheckoutLauncher
import com.equipseva.app.core.payments.isScopeCancellation
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
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive
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
    private val pendingPaymentsStore: com.equipseva.app.core.payments.PendingAmcPaymentsStore,
    private val crashReporter: com.equipseva.app.core.observability.CrashReporter,
) : ViewModel() {

    data class UiState(val busy: Boolean = false)

    /** Terminal outcomes worth telling the hospital about. */
    sealed interface Effect {
        /** Server verified the charge; the pool is credited. */
        data object Paid : Effect

        /**
         * Razorpay captured the money but the server has not confirmed it yet.
         * Distinct from a failure: telling a charged hospital their payment
         * did not go through is the worst copy we can ship on this path.
         */
        data object ChargedAwaitingConfirmation : Effect

        /**
         * The charge did not go through, and here is what to tell the
         * hospital.
         *
         * Failure copy travels as an effect for the same reason the two
         * outcomes above do: the charge outlives the sheet. Written to
         * the sheet's own state instead, it reached a sheet that had already
         * left composition — nobody read it, nobody consumed it, and it
         * surfaced as a stale toast the next time the sheet opened.
         */
        data class Failed(val message: String) : Effect
    }

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    // SharedFlow(replay = 0) — collected by the hosting screen, NOT the sheet,
    // so an outcome still reaches the hospital when the sheet was swiped away
    // while the charge was in flight.
    private val _effects = kotlinx.coroutines.flow.MutableSharedFlow<Effect>(
        extraBufferCapacity = 4,
    )
    val effects: kotlinx.coroutines.flow.Flow<Effect> = _effects

    /**
     * Starts the end-to-end checkout on [viewModelScope].
     *
     * Deliberately NOT a suspend function called from the sheet's own
     * coroutine scope: dismissing the sheet cancelled that scope mid-charge,
     * and because [toUserMessage] re-throws CancellationException from inside
     * the state-update lambda, `busy` was never cleared — the ViewModel
     * outlives the sheet (it is scoped to the screen's back-stack entry), so
     * the reopened sheet sat on a disabled "Processing…" button until the
     * whole screen was popped. Money in flight must also outlive the sheet:
     * the verify call below is the only thing that credits the pool.
     */
    fun startCheckout(
        activity: Activity,
        amcContractId: String,
        months: Int,
        engineerName: String,
    ) {
        if (_state.value.busy) return
        _state.update { it.copy(busy = true) }
        viewModelScope.launch {
            var failure: String? = null
            try {
                failure = runCheckout(activity, amcContractId, months, engineerName)
            } finally {
                // Unconditional: every early return, throw and cancellation
                // has to leave the button usable again.
                _state.update { it.copy(busy = false) }
                failure?.let { _effects.tryEmit(Effect.Failed(it)) }
            }
        }
    }

    /**
     * Returns the message to surface, or null when the charge succeeded or
     * the user cancelled without anything to report.
     */
    private suspend fun runCheckout(
        activity: Activity,
        amcContractId: String,
        months: Int,
        engineerName: String,
    ): String? {
        // 1. Server creates the Razorpay order + binds it.
        val orderRes = repo.createPaymentOrder(amcContractId, months)
        if (orderRes.isFailure) {
            val cause = orderRes.exceptionOrNull()
            if (isScopeCancellation(cause)) throw cause!!
            return checkoutFailureMessage(cause)
        }
        val order = orderRes.getOrThrow()

        // 2. Resolve email for prefill (best-effort).
        val session = auth.sessionState
            .filterIsInstance<AuthSession.SignedIn>()
            .firstOrNull()
        val email = session?.email

        // Process-death recovery: persist the payment_order id so the
        // reconciler can notice if our process gets killed while the
        // user is mid-payment in the UPI app. Round 472: marker is now
        // cleared ONLY on outcomes where we know no money is in flight
        // (Cancelled / Failed / verify-success). On verify-failure we
        // KEEP the marker so PendingAmcPaymentsReconciler can recover
        // on next cold-start — verify could have failed transiently
        // while the Razorpay webhook is still en route + payment is
        // captured server-side.
        //
        // The marker write must NOT swallow cancellation: a swallowed
        // CancellationException let execution fall through to checkout.open()
        // with the bridge already torn down, so Razorpay appeared with no
        // listener — the hospital could pay into a charge nobody was waiting
        // for, with no marker on disk for the reconciler to recover from.
        try {
            pendingPaymentsStore.add(order.paymentOrderId)
        } catch (ce: CancellationException) {
            throw ce
        } catch (_: Throwable) {
            // Best-effort marker; the server-side order row is the truth.
        }

        // 3. Launch Razorpay Standard Checkout. If the SDK itself
        // throws BEFORE returning a result, we leave the marker so
        // the reconciler can resolve based on server-side status —
        // a thrown SDK exception doesn't prove the payment didn't
        // capture.
        //
        // Never open checkout on a dead coroutine: startPayment registers the
        // result bridge and then awaits it, so a cancellation racing the open
        // call would show the SDK with nothing listening for the result.
        currentCoroutineContext().ensureActive()
        val result = try {
            launcher.startPayment(
                activity = activity,
                amountPaise = order.amountPaise,
                currency = order.currency,
                name = "EquipSeva AMC",
                description = amcPaymentRazorpayDescription(months, engineerName),
                prefillEmail = email,
                prefillContact = null,
                razorpayOrderId = order.razorpayOrderId,
                keyId = order.keyId,
            )
        } catch (ce: CancellationException) {
            throw ce
        } catch (e: Throwable) {
            return checkoutFailureMessage(e)
        }

        when (result) {
            is RazorpayCheckoutLauncher.RazorpayPaymentResult.Cancelled -> {
                // User cancelled inside Razorpay — no payment captured,
                // safe to clear the in-flight marker.
                clearMarker(order.paymentOrderId)
                return "Payment cancelled"
            }
            is RazorpayCheckoutLauncher.RazorpayPaymentResult.Failed -> {
                // Razorpay reported failure — no payment captured, safe
                // to clear the in-flight marker.
                clearMarker(order.paymentOrderId)
                return result.message ?: "Payment failed (${result.code})"
            }
            is RazorpayCheckoutLauncher.RazorpayPaymentResult.Success -> {
                // 4. Verify on-server. The HMAC re-check is the gate.
                //
                // Persist the signature FIRST: between here and a successful
                // verify the client is the only holder of the proof that this
                // charge happened, so a crash or a dead network would
                // otherwise leave the hospital charged with nothing but the
                // Razorpay dashboard webhook to fall back on.
                val payload = com.equipseva.app.core.payments.VerifiableAmcPayment(
                    paymentOrderId = order.paymentOrderId,
                    razorpayOrderId = result.razorpayOrderId.ifBlank { order.razorpayOrderId },
                    razorpayPaymentId = result.razorpayPaymentId,
                    razorpaySignature = result.razorpaySignature,
                )
                try {
                    pendingPaymentsStore.recordVerifiable(payload)
                } catch (ce: CancellationException) {
                    throw ce
                } catch (_: Throwable) {
                    // Best-effort; the verify attempts below usually settle it.
                }
                val verifyError = verifyWithRetries(payload)
                if (verifyError == null) {
                    // Verify succeeded — payment is now reflected
                    // on the server-side ledger; safe to clear.
                    clearMarker(order.paymentOrderId)
                    _effects.emit(Effect.Paid)
                    return null
                }
                // Verify failed AFTER Razorpay reported Success
                // — payment likely captured, server reconcile
                // is still pending. DO NOT clear the marker;
                // PendingAmcPaymentsReconciler will recover on
                // next cold-start once status flips paid/failed.
                // Report it — hospital charged, contract not yet
                // credited is the highest-consequence money case.
                crashReporter.report(verifyError, "amc payment verify failed after Razorpay success")
                _effects.emit(Effect.ChargedAwaitingConfirmation)
                return null
            }
        }
    }

    /**
     * Replays the (idempotent) verify a bounded number of times. Only the
     * last error is reported; a 4xx is the server's decision, so retrying it
     * would just delay the honest message.
     */
    private suspend fun verifyWithRetries(
        payload: com.equipseva.app.core.payments.VerifiableAmcPayment,
    ): Throwable? {
        var lastError: Throwable? = null
        for (attempt in 0..AMC_VERIFY_RETRY_DELAYS_MS.size) {
            if (attempt > 0) kotlinx.coroutines.delay(AMC_VERIFY_RETRY_DELAYS_MS[attempt - 1])
            val res = repo.verifyPayment(
                paymentOrderId = payload.paymentOrderId,
                razorpayOrderId = payload.razorpayOrderId,
                razorpayPaymentId = payload.razorpayPaymentId,
                razorpaySignature = payload.razorpaySignature,
            )
            if (res.isSuccess) return null
            val error = res.exceptionOrNull() ?: return null
            if (isScopeCancellation(error)) throw error
            lastError = error
            if (!shouldRetryAmcVerify(error)) break
        }
        return lastError
    }

    private suspend fun clearMarker(paymentOrderId: String) {
        try {
            pendingPaymentsStore.remove(paymentOrderId)
        } catch (ce: CancellationException) {
            throw ce
        } catch (_: Throwable) {
            // Best-effort; the reconciler clears it on the next cold start.
        }
    }
}

/**
 * Backoff between verify replays. Two retries keep the hospital's wait under
 * the attention span of the "confirming your payment" spinner while covering
 * the common transient causes (a dropped edge-function connection, a gateway
 * hiccup).
 */
private val AMC_VERIFY_RETRY_DELAYS_MS = longArrayOf(1_000L, 3_000L)

/**
 * True when a failed `verify-amc-payment` call is worth replaying.
 *
 * A 4xx is a decision (bad signature, order already resolved, not our order):
 * the same request will get the same answer, and looping on it delays telling
 * the hospital what actually happened. Everything else — timeouts, IO
 * failures, 5xx, an unrecognised error — is treated as transient, because the
 * alternative (giving up on a captured payment) is the expensive mistake.
 */
internal fun shouldRetryAmcVerify(error: Throwable): Boolean {
    if (isScopeCancellation(error)) return false
    // The repository's own withTimeout surfaces here; a gateway that was slow
    // once is the textbook case for replaying an idempotent verify.
    if (error is kotlinx.coroutines.TimeoutCancellationException) return true
    // Read the status off the typed failure. Matching "HTTP 4xx" in the
    // message could not work: the function answers every refusal with a
    // parseable body, so the parsed copy replaced the status and this rule
    // never fired once against the real contract.
    if (error is AmcRepository.EdgeFnHttpException) return error.status !in 400..499
    return true
}

/**
 * Checkout-failure copy that survives the CancellationException rules.
 *
 * [toUserMessage] re-throws every CancellationException, and the repositories
 * bound their calls with `withTimeout` inside `runCatching` — so calling it on
 * a timed-out payment call would throw instead of returning copy, and the
 * hospital would watch the spinner stop with no explanation at all.
 */
internal fun checkoutFailureMessage(error: Throwable?): String? = when {
    error == null -> null
    error is kotlinx.coroutines.TimeoutCancellationException ->
        "That took too long. Check your connection and try again."
    error is CancellationException -> null
    else -> error.toUserMessage()
}

/**
 * Bottom sheet hospital uses to top up the AMC pool. Controls a 1..12
 * month picker and triggers the full Razorpay end-to-end on Confirm.
 *
 * The actual heavy lifting lives in [AmcPaymentViewModel.startCheckout];
 * this composable is just the UI shell + months picker. The paid / charged
 * outcome is deliberately collected by the hosting screen instead of here,
 * so it still reaches the hospital if the sheet is dismissed while the
 * charge is in flight.
 */
@Composable
fun AmcPaymentSheet(
    contractId: String,
    monthlyFeeRupees: Double,
    initialMonths: Int = 1,
    onMonthsChange: (Int) -> Unit = {},
    onClose: () -> Unit,
    onShowMessage: (String) -> Unit,
    engineerName: String = "your engineer",
    viewModel: AmcPaymentViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val context = LocalContext.current
    val activity = context as? Activity
    // rememberSaveable so the months chip selection survives rotation /
    // process death — `remember` reset to `initialMonths` on every config
    // change, forcing a user to re-pick e.g. 6 if they had just selected
    // it before the orientation flip.
    var months by rememberSaveable { mutableIntStateOf(initialMonths) }
    val total = monthlyFeeRupees * months

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
                stringResource(R.string.amc_payment_prepay_note),
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
                        Text(stringResource(R.string.amc_payment_monthly_fee_label), color = SevaInk700, fontSize = 13.sp)
                        Text(
                            // Paise-exact on every line of this sheet: the
                            // server charges round(fee * months * 100) paise,
                            // so a whole-rupee display disagreed with the
                            // amount the Razorpay sheet then asked for.
                            formatRupeesPaise(monthlyFeeRupees),
                            color = SevaInk900,
                            fontSize = 13.sp,
                            fontWeight = FontWeight.SemiBold,
                        )
                    }
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                    ) {
                        Text(stringResource(R.string.amc_payment_months_label), color = SevaInk700, fontSize = 13.sp)
                        Text(
                            stringResource(R.string.amc_payment_months_value, months),
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
                        Text(stringResource(R.string.order_summary_total_label), color = SevaInk900, fontSize = 14.sp, fontWeight = FontWeight.Bold)
                        Text(
                            formatRupeesPaise(total),
                            color = SevaInk900,
                            fontSize = 14.sp,
                            fontWeight = FontWeight.Bold,
                        )
                    }
                }
            }
            EsBtn(
                text = amcPayButtonLabel(busy = state.busy, totalRupees = total),
                onClick = {
                    if (activity == null) {
                        onShowMessage("Couldn't open Razorpay — please try again.")
                        return@EsBtn
                    }
                    viewModel.startCheckout(
                        activity = activity,
                        amcContractId = contractId,
                        months = months,
                        engineerName = engineerName,
                    )
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

/**
 * Razorpay description string surfaced in the Razorpay checkout UI
 * and the hospital's payment history.
 *
 * Format: "N month[s] for $engineerName" with singular/plural split.
 *
 * Critical pins:
 *   - Singular at months == 1 → "1 month for ${name}" (no 's'). A
 *     "1 months" surface in the Razorpay UI would erode trust in the
 *     payment flow — this is the most-visible string at the highest-
 *     stakes moment in the funnel.
 *   - "for ${engineerName}" — load-bearing context the hospital uses
 *     to confirm WHO they're paying. A refactor to omit the name
 *     would make the description ambiguous on hospitals with multiple
 *     active AMC contracts.
 *
 * Also pinned: the engineerName is taken VERBATIM (no truncate, no
 * isBlank fallback). The caller is responsible for passing a
 * sensible name string.
 */
/**
 * Primary CTA copy for the top-up sheet.
 *
 * Pinned: the amount is paise-exact. The server charges
 * `round(monthly_fee * months * 100)` paise, so a whole-rupee label promised
 * one figure and the Razorpay sheet immediately asked for another — the exact
 * moment in the funnel where a mismatch reads as fraud.
 */
internal fun amcPayButtonLabel(busy: Boolean, totalRupees: Double): String =
    if (busy) "Processing…" else "Pay ${formatRupeesPaise(totalRupees)}"

internal fun amcPaymentRazorpayDescription(months: Int, engineerName: String): String {
    val noun = if (months == 1) "month" else "months"
    return "$months $noun for $engineerName"
}
