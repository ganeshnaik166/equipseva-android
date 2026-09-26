package com.equipseva.app.core.data.repair

import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.testing.FakeAuthRepository
import java.io.File
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(application = android.app.Application::class, manifest = Config.NONE, sdk = [34])
@OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)
class RequestServiceDraftPersistenceTest {
    @get:Rule val temporaryFolder = TemporaryFolder()

    @Test fun `disk draft survives store recreation for the same login`() = runTest {
        val file = File(temporaryFolder.root, "draft.preferences_pb")
        val identity = RequestServiceDraftStore.Identity("hospital-a", "login-a")
        val expected = draft("retained serial and service details")
        val first = DiskStore(file, identity, backgroundScope)
        runCurrent()
        try {
            first.store.saveDraft(requireNotNull(first.store.activeSession.value), expected)
        } finally {
            first.close()
        }
        val recreated = DiskStore(file, identity, backgroundScope)
        runCurrent()
        try {
            assertEquals(expected, recreated.store.loadDraft(requireNotNull(recreated.store.activeSession.value)))
        } finally {
            recreated.close()
        }
    }

    @Test fun `different account cannot recover an old disk draft after recreation`() = runTest {
        val file = File(temporaryFolder.root, "draft.preferences_pb")
        val first = DiskStore(file, RequestServiceDraftStore.Identity("hospital-a", "login-a"), backgroundScope)
        runCurrent()
        try {
            first.store.saveDraft(requireNotNull(first.store.activeSession.value), draft("private A"))
        } finally {
            first.close()
        }
        val second = DiskStore(file, RequestServiceDraftStore.Identity("hospital-b", "login-b"), backgroundScope)
        runCurrent()
        try {
            val lease = requireNotNull(second.store.activeSession.value)
            assertNull(second.store.loadDraft(lease))
            val ownDraft = draft("private B")
            second.store.saveDraft(lease, ownDraft)
            assertEquals(ownDraft, second.store.loadDraft(lease))
        } finally {
            second.close()
        }
    }

    @Test fun `fresh login of same owner cannot revive previous login disk draft`() = runTest {
        val file = File(temporaryFolder.root, "draft.preferences_pb")
        val first = DiskStore(file, RequestServiceDraftStore.Identity("hospital-a", "old-login"), backgroundScope)
        runCurrent()
        try {
            first.store.saveDraft(requireNotNull(first.store.activeSession.value), draft("departed session"))
        } finally {
            first.close()
        }
        val nextLogin = DiskStore(file, RequestServiceDraftStore.Identity("hospital-a", "new-login"), backgroundScope)
        runCurrent()
        try {
            assertNull(nextLogin.store.loadDraft(requireNotNull(nextLogin.store.activeSession.value)))
        } finally {
            nextLogin.close()
        }
    }

    private class DiskStore(
        file: File,
        identity: RequestServiceDraftStore.Identity,
        authScope: CoroutineScope,
    ) {
        private val diskScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
        private val auth = FakeAuthRepository().apply {
            setSession(AuthSession.SignedIn(identity.ownerId, "test@example.invalid"))
        }
        val store = RequestServiceDraftStore(
            dataStore = PreferenceDataStoreFactory.create(scope = diskScope, produceFile = { file }),
            authRepository = auth,
            currentIdentity = { identity },
            scope = authScope,
        )

        suspend fun close() {
            diskScope.cancel()
            diskScope.coroutineContext[Job]?.join()
        }
    }

    private fun draft(issue: String) = RequestServiceFormDraft(
        category = "patient_monitoring", urgency = "scheduled", brand = "Example",
        model = "Monitor", serial = "TEST-SERIAL-1", siteAddress = "Test site",
        siteLocation = "Test ward", pickedDateMillis = 1_800_000_000_000L,
        siteLatitude = 17.0, siteLongitude = 78.0, issue = issue, budget = "1200",
        photoUris = listOf("hospital-a/issue-test.jpg"),
    )
}
