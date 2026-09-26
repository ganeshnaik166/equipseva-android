package com.equipseva.app.core.auth

import com.equipseva.app.core.sync.OutboxSignOutCleaner
import com.equipseva.app.core.data.repair.DraftStoreFixture
import com.equipseva.app.core.data.repair.sampleRequestDraft
import com.equipseva.app.core.push.DeviceTokenRegistrar
import com.equipseva.app.core.sync.handlers.PhotoUploadStash
import com.equipseva.app.navigation.DeepLinkRouter
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.mockk
import io.mockk.slot
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.async
import kotlinx.coroutines.cancel
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.TestScope
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * A4-01 / A4-02 — sign-out cleanup is OWNED and ORDERED:
 *  - the departing (user, token) is captured before any network I/O and is what
 *    the revoke deletes, even if the next user has signed in by then;
 *  - every local wipe completes BEFORE the network revoke is awaited, so a
 *    stalled revoke can no longer let the wipes land on the next login's data;
 *  - CancellationException propagates instead of being swallowed step by step.
 */
@OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)
class SignOutCleanupOwnershipTest {

    private class Harness(scope: TestScope) {
        val order = mutableListOf<String>()
        val networkRelease = CompletableDeferred<Unit>()
        val revoked = slot<DeviceTokenRegistrar.Revocation?>()
        val draftFixture = DraftStoreFixture(scope)
        val ownership = LocalSessionOwnership(
            draftFixture.auth,
            {
                draftFixture.identity?.let { identity ->
                    identity.sessionId?.let { LocalSessionOwnership.Identity(identity.ownerId, it) }
                }
            },
            scope.backgroundScope,
        )
        val registrar = mockk<DeviceTokenRegistrar> {
            coEvery { captureRevocation(any()) } answers {
                assertTrue("cleanup must pass the first exact ticket", firstArg<LocalSessionOwnership.Ticket?>() === ownership.capture())
                assertNull("draft must be fenced synchronously before token capture", draftFixture.store.activeSession.value)
                order += "capture"
                DeviceTokenRegistrar.Revocation("A", "fcm-token-A")
            }
            coEvery { revoke(captureNullable(revoked)) } coAnswers {
                order += "revoke:start"
                networkRelease.await()
                order += "revoke:end"
            }
        }
        val outboxCleaner = mockk<OutboxSignOutCleaner> { coEvery { clearForSignOut(any()) } answers { order += "outbox" } }
        val stash = mockk<PhotoUploadStash> { coEvery { clearAll() } answers { order += "stash" } }
        val router = mockk<DeepLinkRouter> { every { clear() } answers { order += "router" } }
        val cleanup = SignOutCleanup(
            deviceTokenRegistrar = registrar,
            outboxSignOutCleaner = outboxCleaner,
            outboxScheduler = mockk(relaxed = true),
            photoUploadStash = stash,
            userPrefs = mockk(relaxed = true),
            userBlockRepository = mockk(relaxed = true),
            supabaseClient = mockk(relaxed = true),
            pendingEscrowPaymentsStore = mockk(relaxed = true),
            pendingAmcPaymentsStore = mockk(relaxed = true),
            pendingAmcContractsStore = mockk(relaxed = true),
            requestServiceDraftStore = draftFixture.store,
            deepLinkRouter = router,
            localSessionOwnership = ownership,
            context = mockk(relaxed = true),
        )
    }

    @Test fun `identity is captured first, every local wipe runs, and the network revoke is last`() = runTest {
        val h = Harness(this)
        val wipe = async { h.cleanup.wipeLocalUserState() }
        runCurrent()
        // Suspended inside the network step: all local work is already done.
        assertFalse(wipe.isCompleted)
        assertEquals(listOf("capture", "router", "outbox", "stash", "revoke:start"), h.order)
        h.networkRelease.complete(Unit)
        wipe.await()
        assertEquals("revoke:end", h.order.last())
    }

    @Test fun `revoke targets the captured departing user even after the next user signs in`() = runTest {
        val h = Harness(this)
        val wipe = async { h.cleanup.wipeLocalUserState() }
        runCurrent()
        // "B signs in" here would previously have made revoke() read B as the live
        // user and delete B's device_tokens row. The captured pair is fixed at A.
        h.networkRelease.complete(Unit)
        wipe.await()
        assertEquals(DeviceTokenRegistrar.Revocation("A", "fcm-token-A"), h.revoked.captured)
        coVerify(exactly = 1) { h.registrar.revoke(any()) }
    }

    @Test fun `a step that throws is skipped but the rest still runs`() = runTest {
        val h = Harness(this)
        coEvery { h.outboxCleaner.clearForSignOut(any()) } throws IllegalStateException("db closed")
        val wipe = async { h.cleanup.wipeLocalUserState() }
        runCurrent()
        h.networkRelease.complete(Unit)
        wipe.await()
        assertTrue(h.order.containsAll(listOf("capture", "router", "stash", "revoke:start", "revoke:end")))
        assertFalse(h.order.contains("outbox"))
    }

    @Test fun `cancellation propagates instead of marching through the remaining wipes`() = runTest {
        val h = Harness(this)
        coEvery { h.stash.clearAll() } throws CancellationException("caller went away")
        var cancelled = false
        val wipe = async {
            try {
                h.cleanup.wipeLocalUserState()
            } catch (_: CancellationException) {
                cancelled = true
            }
        }
        runCurrent()
        wipe.await()
        assertTrue("CancellationException must escape bestEffort", cancelled)
        assertFalse("no network revoke after cancellation", h.order.contains("revoke:start"))
    }

    @Test fun `cancellation at A draft disk wait stops global wipes and preserves B's draft`() = runTest {
        val h = Harness(this)
        val diskGate = CompletableDeferred<Unit>()
        h.draftFixture.disk.nextWriteGate = diskGate
        var cancelled = false
        val wipe = launch {
            try {
                h.cleanup.wipeLocalUserState()
            } catch (_: CancellationException) {
                cancelled = true
            }
        }
        runCurrent()
        assertEquals(listOf("capture"), h.order)
        wipe.cancel(CancellationException("stop A cleanup"))
        diskGate.complete(Unit)
        wipe.join()
        assertTrue("draft-disk cancellation must reach the sign-out caller", cancelled)
        assertFalse("cancelled A must not enter later global cleanup", h.order.contains("router"))
        assertFalse("cancelled A must not revoke a token", h.order.contains("revoke:start"))

        h.draftFixture.signIn("B", "session-B")
        runCurrent()
        val bLease = h.draftFixture.lease()
        val bDraft = sampleRequestDraft("B after cancelled sign-out")
        h.draftFixture.store.saveDraft(bLease, bDraft)
        assertEquals(bDraft, h.draftFixture.store.loadDraft(bLease))
    }

    @Test fun `already cancelled signout with no current ticket cannot enter global wipes`() = runTest {
        val h = Harness(this)
        val ticket = requireNotNull(h.ownership.capture())
        assertTrue(h.ownership.retire(ticket))
        assertNull(h.ownership.capture())
        var cancelled = false
        val wipe = launch(start = CoroutineStart.UNDISPATCHED) {
            currentCoroutineContext().cancel(CancellationException("caller cancelled before cleanup"))
            try {
                h.cleanup.wipeLocalUserState()
            } catch (_: CancellationException) {
                cancelled = true
            }
        }
        wipe.join()
        assertTrue("an already-cancelled caller must exit cleanup", cancelled)
        assertTrue("no router, outbox or other global wipe may run", h.order.isEmpty())
    }

    @Test fun `cancelled stale A capture cannot continue into B's global cleanup`() = runTest {
        val h = Harness(this)
        val entered = CompletableDeferred<Unit>()
        val release = CompletableDeferred<Unit>()
        coEvery { h.registrar.captureRevocation(any()) } coAnswers {
            entered.complete(Unit)
            withContext(NonCancellable) { release.await() }
            DeviceTokenRegistrar.Revocation("A", "fcm-token-A")
        }
        var cancelled = false
        val wipe = launch {
            try {
                h.cleanup.wipeLocalUserState()
            } catch (_: CancellationException) {
                cancelled = true
            }
        }
        entered.await()
        h.draftFixture.signIn("B", "session-B")
        runCurrent()
        wipe.cancel(CancellationException("A caller cancelled after B login"))
        release.complete(Unit)
        wipe.join()
        assertTrue("cancelled A capture must escape", cancelled)
        assertFalse("late A must not clear B router", h.order.contains("router"))
        assertFalse("late A must not clear B outbox", h.order.contains("outbox"))
        assertFalse("late A must not revoke under B", h.order.contains("revoke:start"))
    }
}
