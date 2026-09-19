package com.equipseva.app.core.auth

import com.equipseva.app.core.data.dao.OutboxDao
import com.equipseva.app.core.data.repair.DraftStoreFixture
import com.equipseva.app.core.payments.PendingAmcPaymentsStore
import com.equipseva.app.core.push.DeviceTokenRegistrar
import io.mockk.coEvery
import io.mockk.mockk
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.async
import kotlinx.coroutines.cancelAndJoin
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** Real cleanup and real draft fence; deterministic suspendable local-store boundaries. */
@OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)
class SignOutCleanupLocalBoundaryRegressionTest {
    private class Harness(scope: TestScope) {
        val draft = DraftStoreFixture(scope)
        val revoked = mutableListOf<DeviceTokenRegistrar.Revocation?>()
        val captures = mutableListOf<DeviceTokenRegistrar.Revocation?>()
        val outboxRows = mutableSetOf("A-row")
        val paymentMarkers = mutableSetOf("A-payment")
        var outboxGate: CompletableDeferred<Unit>? = null
        val outboxEntered = CompletableDeferred<Unit>()
        val registrar = mockk<DeviceTokenRegistrar> {
            coEvery { captureRevocation() } answers {
                draft.identity?.ownerId?.let { DeviceTokenRegistrar.Revocation(it, "token-$it") }
                    .also { captures += it }
            }
            coEvery { revoke(any()) } answers { revoked += firstArg<DeviceTokenRegistrar.Revocation?>() }
        }
        val outbox = mockk<OutboxDao> {
            coEvery { clearAll() } coAnswers {
                outboxEntered.complete(Unit)
                outboxGate?.await()
                outboxRows.clear()
            }
        }
        val pendingPayments = mockk<PendingAmcPaymentsStore> {
            coEvery { clearAll() } answers { paymentMarkers.clear() }
        }
        val cleanup = SignOutCleanup(
            deviceTokenRegistrar = registrar,
            outboxDao = outbox,
            outboxScheduler = mockk(relaxed = true),
            photoUploadStash = mockk(relaxed = true),
            userPrefs = mockk(relaxed = true),
            userBlockRepository = mockk(relaxed = true),
            supabaseClient = mockk(relaxed = true),
            pendingEscrowPaymentsStore = mockk(relaxed = true),
            pendingAmcPaymentsStore = pendingPayments,
            pendingAmcContractsStore = mockk(relaxed = true),
            requestServiceDraftStore = draft.store,
            deepLinkRouter = mockk(relaxed = true),
            context = mockk(relaxed = true),
        )
    }

    @Test fun `departing owner is captured before a delayed draft disk clear can observe B`() = runTest {
        val h = Harness(this)
        val gate = CompletableDeferred<Unit>()
        h.draft.disk.nextWriteGate = gate
        val wipe = async { h.cleanup.wipeLocalUserState() }
        try {
            runCurrent()
            assertTrue("the real draft fence retires A before waiting on disk", h.draft.store.activeSession.value == null)
            h.draft.signIn("B", "session-B")
            runCurrent()
            gate.complete(Unit)
            wipe.await()
            assertEquals(
                "A's sign-out must never capture B as the departing owner",
                listOf(DeviceTokenRegistrar.Revocation("A", "token-A")),
                h.captures,
            )
        } finally {
            gate.complete(Unit)
            wipe.cancelAndJoin()
        }
    }

    @Test fun `B's outbox row survives A's delayed draft cleanup`() = runTest {
        val h = Harness(this)
        val gate = CompletableDeferred<Unit>()
        h.draft.disk.nextWriteGate = gate
        val wipe = async { h.cleanup.wipeLocalUserState() }
        try {
            runCurrent()
            h.draft.signIn("B", "session-B")
            runCurrent()
            h.outboxRows += "B-row"
            gate.complete(Unit)
            wipe.await()
            assertTrue("A's resumed global cleanup erased B's new work", "B-row" in h.outboxRows)
        } finally {
            gate.complete(Unit)
            wipe.cancelAndJoin()
        }
    }

    @Test fun `B's payment marker survives A's suspended outbox clear`() = runTest {
        val h = Harness(this)
        val gate = CompletableDeferred<Unit>()
        h.outboxGate = gate
        val wipe = async { h.cleanup.wipeLocalUserState() }
        try {
            h.outboxEntered.await()
            assertEquals(listOf(DeviceTokenRegistrar.Revocation("A", "token-A")), h.captures)
            h.draft.signIn("B", "session-B")
            runCurrent()
            h.paymentMarkers += "B-payment"
            gate.complete(Unit)
            wipe.await()
            assertTrue("A's resumed local cleanup erased B's payment marker", "B-payment" in h.paymentMarkers)
        } finally {
            gate.complete(Unit)
            wipe.cancelAndJoin()
        }
    }

    @Test fun `ordinary A cleanup still clears A's local work and revokes A`() = runTest {
        val h = Harness(this)
        h.cleanup.wipeLocalUserState()
        assertTrue(h.outboxRows.isEmpty())
        assertTrue(h.paymentMarkers.isEmpty())
        assertEquals(listOf(DeviceTokenRegistrar.Revocation("A", "token-A")), h.revoked)
    }
}
