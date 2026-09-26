package com.equipseva.app.core.auth

import com.equipseva.app.testing.FakeAuthRepository
import java.io.IOException
import java.util.concurrent.Executors
import java.util.concurrent.Future
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.*
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class LocalSessionOwnershipFailureTest {
    private enum class ProbeApi { Capture, Guard }

    private class Fixture(scope: TestScope) {
        val auth = FakeAuthRepository(AuthSession.SignedIn("A", "initial@test.invalid"))
        @Volatile var probeFailure: Exception? = null
        val reads = AtomicInteger()
        val owner = LocalSessionOwnership(
            authRepository = auth,
            currentIdentity = {
                reads.incrementAndGet()
                probeFailure?.let { throw it }
                LocalSessionOwnership.Identity("A", "session-A")
            },
            scope = scope.backgroundScope,
        )

        fun ticket() = requireNotNull(owner.capture())

        fun observeSameLoginAgain() {
            // A changed email delivers a real observation without changing the
            // identity pair. Restoring the raw probe alone must not mint a ticket.
            auth.setSession(AuthSession.SignedIn("A", "recovered@test.invalid"))
        }
    }

    @Test fun `capture probe exception invalidates old ticket until an agreeing auth observation`() = runTest {
        ordinaryProbeFailure(ProbeApi.Capture)
    }

    @Test fun `guard probe exception invalidates old ticket until an agreeing auth observation`() = runTest {
        ordinaryProbeFailure(ProbeApi.Guard)
    }

    private fun TestScope.ordinaryProbeFailure(api: ProbeApi) {
        val f = Fixture(this)
        runCurrent()
        val old = f.ticket()
        var mutations = 0
        assertTrue("The initial ticket must be usable", f.owner.withCurrent(old) { mutations++ })
        assertEquals(1, mutations)

        val readsBeforeFailure = f.reads.get()
        f.probeFailure = IOException("synthetic raw identity probe failure")
        when (api) {
            ProbeApi.Capture -> assertNull(f.owner.capture())
            ProbeApi.Guard -> assertFalse(f.owner.withCurrent(old) {
                mutations++
                fail("A failing identity probe must not admit the action")
            })
        }
        assertEquals("The failing probe must actually be called", readsBeforeFailure + 1, f.reads.get())
        assertEquals(1, mutations)

        f.probeFailure = null
        assertNull("Raw restoration alone cannot reissue a ticket", f.owner.capture())
        assertFalse("The original ticket stays invalid", f.owner.withCurrent(old) {
            fail("Raw restoration revived an invalid ticket")
        })

        f.observeSameLoginAgain()
        runCurrent()
        val recovered = f.ticket()
        assertNotSame("Recovery needs a newly issued object", old, recovered)
        assertTrue(recovered.generation > old.generation)
        assertFalse("A fresh observation never revives the original ticket", f.owner.withCurrent(old) {
            fail("Old ticket admitted after recovery")
        })
        assertTrue(f.owner.withCurrent(recovered) { mutations++ })
        assertEquals("Only initial and recovered work may run", 2, mutations)
    }

    @Test fun `capture probe cancellation propagates and leaves valid ownership usable`() = runTest {
        cancelledProbe(ProbeApi.Capture)
    }

    @Test fun `guard probe cancellation propagates without mutation and leaves valid ownership usable`() = runTest {
        cancelledProbe(ProbeApi.Guard)
    }

    private fun TestScope.cancelledProbe(api: ProbeApi) {
        val f = Fixture(this)
        runCurrent()
        val current = f.ticket()
        var admitted = 0
        assertTrue(f.owner.withCurrent(current) { admitted++ })
        val rows = mutableSetOf("marker-A", "exact-proof-A")
        val originalRows = rows.toSet()
        val cancellation = CancellationException("synthetic probe cancellation")
        val readsBeforeCancellation = f.reads.get()
        f.probeFailure = cancellation
        var caught: CancellationException? = null
        try {
            when (api) {
                ProbeApi.Capture -> f.owner.capture()
                ProbeApi.Guard -> f.owner.withCurrent(current) {
                    admitted++
                    rows.clear()
                    fail("A cancelled identity probe must not admit deletion")
                }
            }
        } catch (error: CancellationException) {
            caught = error
        }
        assertSame("The direct call must propagate the original cancellation", cancellation, caught)
        assertEquals(readsBeforeCancellation + 1, f.reads.get())
        assertEquals("Cancellation must not run the guarded action", 1, admitted)
        assertEquals(originalRows, rows)

        f.probeFailure = null
        assertSame("Cancellation alone is not a login boundary", current, f.owner.capture())
        assertTrue(f.owner.withCurrent(current) {
            admitted++
            rows.clear()
        })
        assertEquals("Later valid work remains usable", 2, admitted)
        assertTrue(rows.isEmpty())
    }

    @Test fun `throwing guarded action propagates original failure and releases monitor to another worker`() = runTest {
        val f = Fixture(this)
        runCurrent()
        val current = f.ticket()
        val entered = AtomicInteger()
        val failure = IOException("synthetic guarded action failure")
        var caught: IOException? = null
        try {
            f.owner.withCurrent(current) {
                entered.incrementAndGet()
                throw failure
            }
        } catch (error: IOException) {
            caught = error
        }
        assertEquals("The throwing action must really enter", 1, entered.get())
        assertSame("The direct guard call must preserve the original exception", failure, caught)

        val worker = Executors.newSingleThreadExecutor { task ->
            Thread(task, "ownership-after-guard-failure").apply { isDaemon = true }
        }
        var recovery: Future<Boolean>? = null
        val successfulMutations = AtomicInteger()
        try {
            recovery = worker.submit<Boolean> {
                assertSame("An action failure does not retire the login", current, f.owner.capture())
                f.owner.withCurrent(current) { successfulMutations.incrementAndGet() }
            }
            assertTrue("A different worker must acquire the released monitor", recovery.get(5, TimeUnit.SECONDS))
            assertEquals(1, successfulMutations.get())
        } finally {
            recovery?.cancel(true)
            worker.shutdownNow()
            assertTrue("The recovery worker must terminate", worker.awaitTermination(5, TimeUnit.SECONDS))
        }
    }
}
