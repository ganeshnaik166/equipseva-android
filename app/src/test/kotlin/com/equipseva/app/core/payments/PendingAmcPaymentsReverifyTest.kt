package com.equipseva.app.core.payments

import com.equipseva.app.core.data.amc.AmcRepository
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.mockk
import kotlinx.coroutines.test.runTest
import org.junit.Test
import java.io.IOException

/**
 * The cold-start recovery for a payment Razorpay captured but the server
 * never confirmed.
 *
 * Before this, the sweep only READ the order status: a still-pending order
 * kept its marker forever and the pool was credited only if the Razorpay
 * dashboard webhook happened to be configured.
 */
class PendingAmcPaymentsReverifyTest {

    private val payload = VerifiableAmcPayment(
        paymentOrderId = "po-1",
        razorpayOrderId = "order_1",
        razorpayPaymentId = "pay_1",
        razorpaySignature = "sig",
    )

    private fun store(
        pending: Set<String> = setOf("po-1"),
        stored: VerifiableAmcPayment? = payload,
    ): PendingAmcPaymentsStore = mockk(relaxed = true) {
        coEvery { list() } returns pending
        coEvery { verifiable(any()) } returns stored
    }

    @Test fun `a pending order with a stored signature is re-verified and cleared`() = runTest {
        val store = store()
        val repo = mockk<AmcRepository>(relaxed = true) {
            coEvery { fetchAmcPaymentOrderStatus("po-1") } returns Result.success("pending")
            coEvery { verifyPayment(any(), any(), any(), any()) } returns Result.success(
                AmcRepository.VerifyAmcPaymentResponse(paymentOrderId = "po-1"),
            )
        }

        PendingAmcPaymentsReconciler(store, repo).reconcile()

        coVerify(exactly = 1) {
            repo.verifyPayment(
                paymentOrderId = "po-1",
                razorpayOrderId = "order_1",
                razorpayPaymentId = "pay_1",
                razorpaySignature = "sig",
            )
        }
        coVerify(exactly = 1) { store.remove("po-1") }
    }

    @Test fun `a failed re-verify keeps the marker for the next cold start`() = runTest {
        val store = store()
        val repo = mockk<AmcRepository>(relaxed = true) {
            coEvery { fetchAmcPaymentOrderStatus("po-1") } returns Result.success("pending")
            coEvery { verifyPayment(any(), any(), any(), any()) } returns
                Result.failure(IOException("still offline"))
        }

        PendingAmcPaymentsReconciler(store, repo).reconcile()

        coVerify(exactly = 0) { store.remove(any()) }
    }

    @Test fun `without a stored signature the sweep leaves the order alone`() = runTest {
        // Nothing to replay: the marker stays so the home banner can still
        // surface the in-flight payment to the user.
        val store = store(stored = null)
        val repo = mockk<AmcRepository>(relaxed = true) {
            coEvery { fetchAmcPaymentOrderStatus("po-1") } returns Result.success("pending")
        }

        PendingAmcPaymentsReconciler(store, repo).reconcile()

        coVerify(exactly = 0) { repo.verifyPayment(any(), any(), any(), any()) }
        coVerify(exactly = 0) { store.remove(any()) }
    }

    @Test fun `a resolved order is cleared without a verify call`() = runTest {
        val store = store()
        val repo = mockk<AmcRepository>(relaxed = true) {
            coEvery { fetchAmcPaymentOrderStatus("po-1") } returns Result.success("paid")
        }

        PendingAmcPaymentsReconciler(store, repo).reconcile()

        coVerify(exactly = 0) { repo.verifyPayment(any(), any(), any(), any()) }
        coVerify(exactly = 1) { store.remove("po-1") }
    }

    @Test fun `a failed status read does not replay a signature blindly`() = runTest {
        // We do not know the order's state, so neither clearing the marker nor
        // replaying the charge is justified.
        val store = store()
        val repo = mockk<AmcRepository>(relaxed = true) {
            coEvery { fetchAmcPaymentOrderStatus("po-1") } returns Result.failure(IOException("offline"))
        }

        PendingAmcPaymentsReconciler(store, repo).reconcile()

        coVerify(exactly = 0) { repo.verifyPayment(any(), any(), any(), any()) }
        coVerify(exactly = 0) { store.remove(any()) }
    }
}
