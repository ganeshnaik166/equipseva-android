package com.equipseva.app.core.auth

import com.equipseva.app.core.data.repair.DraftStoreFixture
import com.equipseva.app.core.data.repair.sampleRequestDraft
import com.equipseva.app.core.push.DeviceTokenRegistrar
import io.mockk.coEvery
import io.mockk.mockk
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.async
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.*
import org.junit.Test

@OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)
class SignOutDraftFenceTest {
    @Test fun `draft lease is revoked before slow network cleanup begins`() = runTest {
        val fixture = DraftStoreFixture(this)
        val old = fixture.lease()
        fixture.store.saveDraft(old, sampleRequestDraft())
        val networkRelease = CompletableDeferred<Unit>()
        val registrar = mockk<DeviceTokenRegistrar> {
            coEvery { revoke() } coAnswers {
                assertFalse(fixture.store.isCurrent(old))
                networkRelease.await()
            }
        }
        val cleanup = SignOutCleanup(
            deviceTokenRegistrar = registrar,
            outboxDao = mockk(relaxed = true),
            outboxScheduler = mockk(relaxed = true),
            photoUploadStash = mockk(relaxed = true),
            userPrefs = mockk(relaxed = true),
            userBlockRepository = mockk(relaxed = true),
            supabaseClient = mockk(relaxed = true),
            pendingEscrowPaymentsStore = mockk(relaxed = true),
            pendingAmcPaymentsStore = mockk(relaxed = true),
            pendingAmcContractsStore = mockk(relaxed = true),
            requestServiceDraftStore = fixture.store,
        )
        val wipe = async { cleanup.wipeLocalUserState() }
        runCurrent()
        assertFalse(wipe.isCompleted)
        assertNull(fixture.store.activeSession.value)
        fixture.signIn("B", "session-B")
        runCurrent()
        val bDraft = sampleRequestDraft("B's request")
        fixture.store.saveDraft(fixture.lease(), bDraft)
        fixture.store.saveDraft(old, sampleRequestDraft("A's late callback"))
        networkRelease.complete(Unit)
        wipe.await()
        assertEquals(bDraft, fixture.store.loadDraft(fixture.lease()))
    }
}
