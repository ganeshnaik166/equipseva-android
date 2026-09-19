package com.equipseva.app.core.payments

import com.equipseva.app.core.data.amc.AmcRepository
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.mockk
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.cancel
import kotlinx.coroutines.cancelAndJoin
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.IOException

/**
 * Actual reconciler contract, with offline repository/store doubles.
 *
 * verify-amc-payment writes `paid` BEFORE applying the pool credit. It also
 * supports repairing `paid` without a credit ledger. A stored SDK proof must
 * therefore survive until that verification succeeds, not merely until a
 * status read happens to say `paid`. These are desired regression targets,
 * not passing characterization of b453f19a.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class PendingAmcPaidCreditRecoveryTest {
    private val paymentOrderId = "00000000-0000-0000-0000-000000000101"
    private val ledgerId = "00000000-0000-0000-0000-000000000202"
    private val proof = VerifiableAmcPayment(
        paymentOrderId = paymentOrderId,
        razorpayOrderId = "order_synthetic01",
        razorpayPaymentId = "pay_synthetic001",
        razorpaySignature = "a".repeat(64),
    )

    private inner class Fixture(
        status: String?,
        private val initialProof: VerifiableAmcPayment? = proof,
    ) {
        val pending = linkedSetOf(paymentOrderId)
        var storedProof = initialProof
        val trace = mutableListOf<String>()
        val repo = mockk<AmcRepository>()
        val store = mockk<PendingAmcPaymentsStore>()

        init {
            coEvery { store.list() } coAnswers { pending.toSet() }
            coEvery { store.verifiable(paymentOrderId) } coAnswers { storedProof }
            coEvery { store.remove(paymentOrderId) } coAnswers {
                trace += "remove"
                pending.remove(paymentOrderId)
                storedProof = null
            }
            coEvery { repo.fetchAmcPaymentOrderStatus(paymentOrderId) } returns Result.success(status)
        }

        val reconciler = PendingAmcPaymentsReconciler(store, repo)

        fun verifyReturns(result: Result<AmcRepository.VerifyAmcPaymentResponse>) {
            coEvery {
                repo.verifyPayment(
                    paymentOrderId = proof.paymentOrderId,
                    razorpayOrderId = proof.razorpayOrderId,
                    razorpayPaymentId = proof.razorpayPaymentId,
                    razorpaySignature = proof.razorpaySignature,
                )
            } coAnswers {
                trace += "verify"
                result
            }
        }

        fun verifyCount(expected: Int) {
            coVerify(exactly = expected) {
                repo.verifyPayment(
                    paymentOrderId = proof.paymentOrderId,
                    razorpayOrderId = proof.razorpayOrderId,
                    razorpayPaymentId = proof.razorpayPaymentId,
                    razorpaySignature = proof.razorpaySignature,
                )
            }
        }

        fun assertRetained() {
            assertEquals("Unconfirmed credit keeps its recovery marker", setOf(paymentOrderId), pending)
            assertEquals("Unconfirmed credit keeps its original SDK proof, if present", initialProof, storedProof)
            coVerify(exactly = 0) { store.remove(any()) }
        }

        fun assertCleared() {
            assertTrue(pending.isEmpty())
            assertNull(storedProof)
            coVerify(exactly = 1) { store.remove(paymentOrderId) }
        }
    }

    private fun credited(idempotent: Boolean = false) =
        AmcRepository.VerifyAmcPaymentResponse(
            ok = true,
            paymentOrderId = paymentOrderId,
            ledgerId = ledgerId,
            balanceAfter = 5000.0,
            contractStatus = "active",
            idempotent = idempotent,
        )

    @Test fun `paid with stored proof is repaired before that proof is removed`() = runTest {
        val f = Fixture("paid")
        f.verifyReturns(Result.success(credited()))

        f.reconciler.reconcile()

        assertEquals(listOf("verify", "remove"), f.trace)
        f.verifyCount(1)
        f.assertCleared()
    }

    @Test fun `paid credit still in flight keeps both marker and proof`() = runTest {
        val f = Fixture("paid")
        val entered = CompletableDeferred<Unit>()
        val gate = CompletableDeferred<AmcRepository.VerifyAmcPaymentResponse>()
        coEvery { f.repo.verifyPayment(any(), any(), any(), any()) } coAnswers {
            f.trace += "verify"
            entered.complete(Unit)
            Result.success(gate.await())
        }
        val sweep = launch { f.reconciler.reconcile() }
        try {
            runCurrent()
            assertTrue("Paid status must reach the credit-confirming verify", entered.isCompleted)
            assertFalse("The sweep must await that confirmation", sweep.isCompleted)
            f.assertRetained()

            gate.complete(credited())
            runCurrent()

            assertTrue(sweep.isCompleted)
            assertEquals(listOf("verify", "remove"), f.trace)
            f.verifyCount(1)
            f.assertCleared()
        } finally {
            sweep.cancelAndJoin()
            gate.cancel()
        }
    }

    @Test fun `paid order whose credit verification fails keeps recovery material`() = runTest {
        val f = Fixture("paid")
        f.verifyReturns(Result.failure(IOException("synthetic credit service unavailable")))

        f.reconciler.reconcile()

        f.verifyCount(1)
        f.assertRetained()
    }

    @Test fun `paid proof survives cancellation while credit verification is suspended`() = runTest {
        val f = Fixture("paid")
        val entered = CompletableDeferred<Unit>()
        val gate = CompletableDeferred<AmcRepository.VerifyAmcPaymentResponse>()
        coEvery { f.repo.verifyPayment(any(), any(), any(), any()) } coAnswers {
            entered.complete(Unit)
            Result.success(gate.await())
        }
        val sweep = launch { f.reconciler.reconcile() }
        try {
            runCurrent()
            assertTrue("A real credit verify must have started", entered.isCompleted)
            sweep.cancelAndJoin()

            assertTrue(sweep.isCancelled)
            f.assertRetained()
            f.verifyCount(1)
        } finally {
            sweep.cancelAndJoin()
            gate.cancel()
        }
    }

    @Test fun `already credited paid order clears after idempotent confirmation`() = runTest {
        val f = Fixture("paid")
        f.verifyReturns(Result.success(credited(idempotent = true)))

        f.reconciler.reconcile()
        f.reconciler.reconcile()

        // The second sweep sees an empty store: it must not replay again.
        assertEquals(listOf("verify", "remove"), f.trace)
        f.verifyCount(1)
        f.assertCleared()
    }

    @Test fun `pending order with a valid proof still verifies and clears`() = runTest {
        val f = Fixture("pending")
        f.verifyReturns(Result.success(credited()))

        f.reconciler.reconcile()

        f.verifyCount(1)
        assertEquals(listOf("verify", "remove"), f.trace)
        f.assertCleared()
    }

    @Test fun `verification with ok false preserves the recovery proof`() = runTest {
        val f = Fixture("pending")
        f.verifyReturns(Result.success(credited().copy(ok = false)))

        f.reconciler.reconcile()

        f.verifyCount(1)
        f.assertRetained()
    }

    @Test fun `verification for a different payment order preserves the recovery proof`() = runTest {
        val f = Fixture("pending")
        f.verifyReturns(Result.success(credited().copy(paymentOrderId = "00000000-0000-0000-0000-000000000999")))

        f.reconciler.reconcile()

        f.verifyCount(1)
        f.assertRetained()
    }

    @Test fun `verification without a credit ledger preserves the recovery proof`() = runTest {
        val f = Fixture("pending")
        f.verifyReturns(Result.success(credited().copy(ledgerId = null)))

        f.reconciler.reconcile()

        f.verifyCount(1)
        f.assertRetained()
    }

    @Test fun `verification with a blank credit ledger preserves the recovery proof`() = runTest {
        val f = Fixture("pending")
        f.verifyReturns(Result.success(credited().copy(ledgerId = " \t ")))

        f.reconciler.reconcile()

        f.verifyCount(1)
        f.assertRetained()
    }

    @Test fun `successful result returned into a cancelled sweep cannot remove recovery proof`() = runTest {
        val f = Fixture("pending")
        coEvery { f.repo.verifyPayment(any(), any(), any(), any()) } coAnswers {
            currentCoroutineContext().cancel()
            Result.success(credited())
        }
        val sweep = launch { f.reconciler.reconcile() }

        runCurrent()

        assertTrue(sweep.isCancelled)
        f.verifyCount(1)
        f.assertRetained()
    }

    // Deliberate policy correction to the original unexecuted draft: the edge
    // marks paid before pool credit, so status alone cannot confirm completion.
    @Test fun `paid marker without SDK proof remains unresolved without inventing proof`() = runTest {
        val f = Fixture("paid", initialProof = null)

        f.reconciler.reconcile()

        coVerify(exactly = 0) { f.repo.verifyPayment(any(), any(), any(), any()) }
        f.assertRetained()
    }

    @Test fun `refunded order never replays a stored signature`() = runTest {
        val f = Fixture("refunded")

        f.reconciler.reconcile()

        coVerify(exactly = 0) { f.repo.verifyPayment(any(), any(), any(), any()) }
        f.assertCleared()
    }

    @Test fun `failed order never replays a stored signature`() = runTest {
        val f = Fixture("failed")

        f.reconciler.reconcile()

        coVerify(exactly = 0) { f.repo.verifyPayment(any(), any(), any(), any()) }
        f.assertCleared()
    }

    @Test fun `unknown future status preserves proof without guessing a verify policy`() = runTest {
        val f = Fixture("future_state")

        f.reconciler.reconcile()

        coVerify(exactly = 0) { f.repo.verifyPayment(any(), any(), any(), any()) }
        f.assertRetained()
        assertNotNull(f.storedProof)
    }

    @Test fun `unavailable status preserves proof without assuming that credit completed`() = runTest {
        val f = Fixture(null)

        f.reconciler.reconcile()

        coVerify(exactly = 0) { f.repo.verifyPayment(any(), any(), any(), any()) }
        f.assertRetained()
    }
}
