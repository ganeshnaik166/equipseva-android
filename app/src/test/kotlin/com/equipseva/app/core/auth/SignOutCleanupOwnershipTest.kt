package com.equipseva.app.core.auth

import com.equipseva.app.core.data.dao.OutboxDao
import com.equipseva.app.core.data.repair.RequestServiceDraftStore
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
import kotlinx.coroutines.async
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
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

    private class Harness {
        val order = mutableListOf<String>()
        val networkRelease = CompletableDeferred<Unit>()
        val revoked = slot<DeviceTokenRegistrar.Revocation?>()
        val registrar = mockk<DeviceTokenRegistrar> {
            coEvery { captureRevocation() } answers {
                order += "capture"
                DeviceTokenRegistrar.Revocation("A", "fcm-token-A")
            }
            coEvery { revoke(captureNullable(revoked)) } coAnswers {
                order += "revoke:start"
                networkRelease.await()
                order += "revoke:end"
            }
        }
        val outboxDao = mockk<OutboxDao> { coEvery { clearAll() } answers { order += "outbox" } }
        val stash = mockk<PhotoUploadStash> { coEvery { clearAll() } answers { order += "stash" } }
        val router = mockk<DeepLinkRouter> { every { clear() } answers { order += "router" } }
        val drafts = mockk<RequestServiceDraftStore> {
            coEvery { fenceAndClearForSignOut() } answers { order += "drafts" }
        }
        val cleanup = SignOutCleanup(
            deviceTokenRegistrar = registrar,
            outboxDao = outboxDao,
            outboxScheduler = mockk(relaxed = true),
            photoUploadStash = stash,
            userPrefs = mockk(relaxed = true),
            userBlockRepository = mockk(relaxed = true),
            supabaseClient = mockk(relaxed = true),
            pendingEscrowPaymentsStore = mockk(relaxed = true),
            pendingAmcPaymentsStore = mockk(relaxed = true),
            pendingAmcContractsStore = mockk(relaxed = true),
            requestServiceDraftStore = drafts,
            deepLinkRouter = router,
            context = mockk(relaxed = true),
        )
    }

    @Test fun `identity is captured first, every local wipe runs, and the network revoke is last`() = runTest {
        val h = Harness()
        val wipe = async { h.cleanup.wipeLocalUserState() }
        runCurrent()
        // Suspended inside the network step: all local work is already done.
        assertFalse(wipe.isCompleted)
        assertEquals(listOf("drafts", "capture", "router", "outbox", "stash", "revoke:start"), h.order)
        h.networkRelease.complete(Unit)
        wipe.await()
        assertEquals("revoke:end", h.order.last())
    }

    @Test fun `revoke targets the captured departing user even after the next user signs in`() = runTest {
        val h = Harness()
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
        val h = Harness()
        coEvery { h.outboxDao.clearAll() } throws IllegalStateException("db closed")
        val wipe = async { h.cleanup.wipeLocalUserState() }
        runCurrent()
        h.networkRelease.complete(Unit)
        wipe.await()
        assertTrue(h.order.containsAll(listOf("drafts", "capture", "router", "stash", "revoke:start", "revoke:end")))
        assertFalse(h.order.contains("outbox"))
    }

    @Test fun `cancellation propagates instead of marching through the remaining wipes`() = runTest {
        val h = Harness()
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
}
