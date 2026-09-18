package com.equipseva.app.features.amc

import android.app.Activity
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.amc.AmcRepository
import com.equipseva.app.core.observability.CrashReporter
import com.equipseva.app.core.payments.PendingAmcPaymentsStore
import com.equipseva.app.core.payments.RazorpayCheckoutLauncher
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.async
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Before
import org.junit.Test
import java.io.IOException

/**
 * The AMC top-up charge, end to end in the ViewModel.
 *
 * Three incidents are pinned here:
 *
 *  1. `busy` used to be cleared inside a state-update lambda that also called
 *     `toUserMessage()` — which RE-THROWS CancellationException — so the flag
 *     survived the failure and the reopened sheet showed a permanently
 *     disabled "Processing…" button.
 *  2. The pending-marker write swallowed cancellation and execution fell
 *     through to `checkout.open()`, putting Razorpay on screen with no
 *     listener: the hospital could pay into a charge nobody was awaiting.
 *  3. A single verify attempt was made after Razorpay reported success. The
 *     verify is idempotent, so a transient failure must be replayed rather
 *     than abandoned with the money already captured.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class AmcPaymentCheckoutTest {

    private val dispatcher = UnconfinedTestDispatcher()

    @Before fun setUp() { Dispatchers.setMain(dispatcher) }
    @After fun tearDown() { Dispatchers.resetMain() }

    private val activity: Activity = mockk(relaxed = true)

    private fun order() = AmcRepository.CreateAmcPaymentOrderResponse(
        paymentOrderId = "po-1",
        razorpayOrderId = "order_rzp_1",
        amountPaise = 299_999L,
        currency = "INR",
        keyId = "rzp_test_key",
    )

    private fun auth(): AuthRepository = mockk(relaxed = true) {
        every { sessionState } returns MutableStateFlow(
            AuthSession.SignedIn(userId = "user-1", email = "hospital@x.test"),
        )
    }

    private fun newViewModel(
        repo: AmcRepository,
        launcher: RazorpayCheckoutLauncher = mockk(relaxed = true),
        store: PendingAmcPaymentsStore = mockk(relaxed = true),
        crashReporter: CrashReporter = mockk(relaxed = true),
    ) = AmcPaymentViewModel(
        repo = repo,
        auth = auth(),
        launcher = launcher,
        pendingPaymentsStore = store,
        crashReporter = crashReporter,
    )

    private fun successResult() = RazorpayCheckoutLauncher.RazorpayPaymentResult.Success(
        razorpayPaymentId = "pay_1",
        razorpayOrderId = "order_rzp_1",
        razorpaySignature = "deadbeef",
    )

    @Test fun `busy clears when order creation fails`() = runTest(dispatcher) {
        val repo = mockk<AmcRepository>(relaxed = true) {
            coEvery { createPaymentOrder(any(), any()) } returns Result.failure(IOException("offline"))
        }
        val vm = newViewModel(repo)

        val effect = async(start = CoroutineStart.UNDISPATCHED) { vm.effects.first() }
        vm.startCheckout(activity, "contract-1", months = 1, engineerName = "Asha")
        advanceUntilIdle()

        assertFalse("a failed order must leave the Pay button usable", vm.state.value.busy)
        // The copy travels as an effect, collected by the screen. Held in the
        // view model's own state it reached a sheet the charge had outlived,
        // so nobody read it and it fired as a stale toast later.
        assertEquals(
            AmcPaymentViewModel.Effect.Failed("Network problem. Check your connection and retry."),
            effect.await(),
        )
    }

    @Test fun `busy clears when the order call is cancelled`() = runTest(dispatcher) {
        // Repositories wrap their calls in runCatching, so a cancelled call
        // arrives as a FAILED RESULT rather than unwinding the caller.
        val repo = mockk<AmcRepository>(relaxed = true) {
            coEvery { createPaymentOrder(any(), any()) } returns
                Result.failure(CancellationException("sheet dismissed"))
        }
        val vm = newViewModel(repo)

        val emitted = mutableListOf<AmcPaymentViewModel.Effect>()
        val collector = launch { vm.effects.collect { emitted += it } }
        vm.startCheckout(activity, "contract-1", months = 1, engineerName = "Asha")
        advanceUntilIdle()
        collector.cancel()

        assertFalse(vm.state.value.busy)
        assertEquals(
            "a cancelled charge has nothing to say to the user",
            emptyList<AmcPaymentViewModel.Effect>(),
            emitted,
        )
    }

    @Test fun `razorpay is not opened when the marker write is cancelled`() = runTest(dispatcher) {
        val launcher = mockk<RazorpayCheckoutLauncher>(relaxed = true)
        val store = mockk<PendingAmcPaymentsStore>(relaxed = true) {
            coEvery { add(any()) } throws CancellationException("scope gone")
        }
        val repo = mockk<AmcRepository>(relaxed = true) {
            coEvery { createPaymentOrder(any(), any()) } returns Result.success(order())
        }
        val vm = newViewModel(repo, launcher = launcher, store = store)

        vm.startCheckout(activity, "contract-1", months = 1, engineerName = "Asha")
        advanceUntilIdle()

        coVerify(exactly = 0) {
            launcher.startPayment(any(), any(), any(), any(), any(), any(), any(), any(), any())
        }
        assertFalse(vm.state.value.busy)
    }

    @Test fun `verify is replayed after a transient failure and then reports paid`() = runTest(dispatcher) {
        val launcher = mockk<RazorpayCheckoutLauncher>(relaxed = true) {
            coEvery {
                startPayment(any(), any(), any(), any(), any(), any(), any(), any(), any())
            } returns successResult()
        }
        val store = mockk<PendingAmcPaymentsStore>(relaxed = true)
        val repo = mockk<AmcRepository>(relaxed = true) {
            coEvery { createPaymentOrder(any(), any()) } returns Result.success(order())
            coEvery { verifyPayment(any(), any(), any(), any()) } returnsMany listOf(
                Result.failure(IOException("gateway hiccup")),
                Result.success(
                    AmcRepository.VerifyAmcPaymentResponse(paymentOrderId = "po-1"),
                ),
            )
        }
        val vm = newViewModel(repo, launcher = launcher, store = store)

        val effect = async(start = CoroutineStart.UNDISPATCHED) { vm.effects.first() }
        vm.startCheckout(activity, "contract-1", months = 1, engineerName = "Asha")
        advanceUntilIdle()

        assertEquals(AmcPaymentViewModel.Effect.Paid, effect.await())
        coVerify(exactly = 2) { repo.verifyPayment(any(), any(), any(), any()) }
        // Marker cleared only once the server confirmed the charge.
        coVerify(exactly = 1) { store.remove("po-1") }
        assertFalse(vm.state.value.busy)
    }

    @Test fun `a charged-but-unverified payment keeps its marker and is reported`() = runTest(dispatcher) {
        val launcher = mockk<RazorpayCheckoutLauncher>(relaxed = true) {
            coEvery {
                startPayment(any(), any(), any(), any(), any(), any(), any(), any(), any())
            } returns successResult()
        }
        val store = mockk<PendingAmcPaymentsStore>(relaxed = true)
        val crashReporter = mockk<CrashReporter>(relaxed = true)
        val repo = mockk<AmcRepository>(relaxed = true) {
            coEvery { createPaymentOrder(any(), any()) } returns Result.success(order())
            coEvery { verifyPayment(any(), any(), any(), any()) } returns
                Result.failure(IllegalStateException("Payment verification failed (HTTP 502)"))
        }
        val vm = newViewModel(repo, launcher = launcher, store = store, crashReporter = crashReporter)

        val emitted = mutableListOf<AmcPaymentViewModel.Effect>()
        val collector = launch { vm.effects.collect { emitted += it } }
        vm.startCheckout(activity, "contract-1", months = 1, engineerName = "Asha")
        advanceUntilIdle()
        collector.cancel()

        // Exactly one outcome, and never a failure: the hospital WAS charged,
        // so "payment failed" is the worst copy this path could ship.
        assertEquals(
            listOf(AmcPaymentViewModel.Effect.ChargedAwaitingConfirmation),
            emitted,
        )
        // The signature is kept so the reconciler can re-assert the charge…
        coVerify(exactly = 1) { store.recordVerifiable(any()) }
        // …and the marker is NOT cleared: money moved, the pool is not credited.
        coVerify(exactly = 0) { store.remove(any()) }
        coVerify(exactly = 1) { crashReporter.report(any(), any()) }
        assertFalse(vm.state.value.busy)
    }

    @Test fun `a 4xx verify refusal is not replayed`() = runTest(dispatcher) {
        val launcher = mockk<RazorpayCheckoutLauncher>(relaxed = true) {
            coEvery {
                startPayment(any(), any(), any(), any(), any(), any(), any(), any(), any())
            } returns successResult()
        }
        val repo = mockk<AmcRepository>(relaxed = true) {
            coEvery { createPaymentOrder(any(), any()) } returns Result.success(order())
            coEvery { verifyPayment(any(), any(), any(), any()) } returns
                Result.failure(
                    AmcRepository.EdgeFnHttpException(status = 400, message = "signature mismatch"),
                )
        }
        val vm = newViewModel(repo, launcher = launcher)

        val effect = async(start = CoroutineStart.UNDISPATCHED) { vm.effects.first() }
        vm.startCheckout(activity, "contract-1", months = 1, engineerName = "Asha")
        advanceUntilIdle()

        assertEquals(AmcPaymentViewModel.Effect.ChargedAwaitingConfirmation, effect.await())
        coVerify(exactly = 1) { repo.verifyPayment(any(), any(), any(), any()) }
    }

    @Test fun `a second tap while a charge is in flight is ignored`() = runTest(dispatcher) {
        val repo = mockk<AmcRepository>(relaxed = true) {
            coEvery { createPaymentOrder(any(), any()) } coAnswers {
                kotlinx.coroutines.delay(5_000L)
                Result.failure(IOException("offline"))
            }
        }
        val vm = newViewModel(repo)

        vm.startCheckout(activity, "contract-1", months = 1, engineerName = "Asha")
        vm.startCheckout(activity, "contract-1", months = 1, engineerName = "Asha")
        advanceUntilIdle()

        coVerify(exactly = 1) { repo.createPaymentOrder(any(), any()) }
    }
}
