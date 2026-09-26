package com.equipseva.app.core.data.repair

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.auth.LocalSessionOwnership
import com.equipseva.app.testing.FakeAuthRepository
import java.io.File
import java.io.IOException
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.async
import kotlinx.coroutines.cancelAndJoin
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeout
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/** Ticketed sign-out over a real per-test Preferences file; only timing/failure hooks are synthetic. */
@RunWith(RobolectricTestRunner::class)
@Config(application = android.app.Application::class, manifest = Config.NONE, sdk = [34])
@OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)
class RequestServiceDraftTicketedDiskTest {
    @get:Rule val files = TemporaryFolder()

    private enum class Point { BeforeAdmission, AfterTransform }
    private class Pause(val point: Point) {
        val entered = CompletableDeferred<Unit>()
        val release = CompletableDeferred<Unit>()
    }

    /** Calls the production transform inside the real DataStore transaction. */
    private class Barriers(private val actual: DataStore<Preferences>) : DataStore<Preferences> {
        override val data: Flow<Preferences> = actual.data
        private val lock = Any()
        private var next: Pause? = null
        val pauses = mutableListOf<Pause>()
        var afterTransformFailure: IOException? = null

        fun pause(point: Point): Pause = Pause(point).also {
            synchronized(lock) { next = it; pauses += it }
        }

        override suspend fun updateData(transform: suspend (Preferences) -> Preferences): Preferences {
            val pause = synchronized(lock) { next.also { next = null } }
            if (pause?.point == Point.BeforeAdmission) {
                pause.entered.complete(Unit)
                pause.release.await()
            }
            return actual.updateData { current ->
                val changed = transform(current)
                if (pause?.point == Point.AfterTransform) {
                    pause.entered.complete(Unit)
                    pause.release.await()
                }
                afterTransformFailure?.let { afterTransformFailure = null; throw it }
                changed
            }
        }
    }

    private class Fixture(scope: TestScope, val file: File) {
        val auth = FakeAuthRepository(AuthSession.SignedIn("A", "a@test.invalid"))
        @Volatile var raw = LocalSessionOwnership.Identity("A", "session-A")
        val ownership = LocalSessionOwnership(auth, { raw }, scope.backgroundScope)
        private val diskJob = SupervisorJob()
        private val actual = PreferenceDataStoreFactory.create(
            scope = CoroutineScope(diskJob + Dispatchers.IO), produceFile = { file },
        )
        val barriers = Barriers(actual)
        val store = RequestServiceDraftStore(
            dataStore = barriers,
            authRepository = auth,
            currentIdentity = { RequestServiceDraftStore.Identity(raw.ownerId, raw.sessionId) },
            scope = scope.backgroundScope,
            nowMillis = { 1_000_000L },
        )

        fun lease() = requireNotNull(store.activeSession.value)
        fun ticket() = requireNotNull(ownership.capture())
        fun signIn(owner: String, session: String) {
            raw = LocalSessionOwnership.Identity(owner, session)
            auth.setSession(AuthSession.SignedIn(owner, "$session@test.invalid"))
        }

        suspend fun seedA() {
            real { store.saveDraft(lease(), sampleRequestDraft("A persisted draft")) }
            real { actual.edit { it[EXTRA] = "keep installation preference" } }
            val before = rawPrefs()
            assertEquals("A", before[OWNER])
            assertEquals("session-A", before[SESSION])
            assertTrue(checkNotNull(before[JSON]).contains("A persisted draft"))
            assertTrue("presence control: a real preferences file must exist", file.isFile)
        }

        suspend fun rawPrefs(): Preferences = real { actual.data.first() }

        /** A new delegate after the writer closes proves bytes survive process-style reopening. */
        suspend fun diskReread(): Preferences {
            real { diskJob.cancelAndJoin() }
            val readerJob = SupervisorJob()
            val reader = PreferenceDataStoreFactory.create(
                scope = CoroutineScope(readerJob + Dispatchers.IO), produceFile = { file },
            )
            return try { real { reader.data.first() } }
            finally { real { readerJob.cancelAndJoin() } }
        }

        suspend fun close() = withContext(NonCancellable + Dispatchers.IO) {
            withTimeout(30_000) {
                barriers.pauses.forEach { it.release.complete(Unit) }
                diskJob.cancelAndJoin()
            }
        }
    }

    private fun TestScope.fixture() = Fixture(this, File(files.newFolder(), "draft.preferences_pb"))

    @Test fun `ordinary A ticketed clear removes persisted draft but leaves other preferences after reopen`() = runTest {
        val f = fixture()
        try {
            runCurrent()
            f.seedA()
            val oldLease = f.lease()
            val handle = requireNotNull(f.store.fenceForSignOut(f.ticket(), f.ownership))
            assertNull("draft lease retires before disk edit", f.store.activeSession.value)
            real { f.store.clearFencedForSignOut(handle) }
            val disk = f.diskReread()
            assertNull(disk[JSON])
            assertNull(disk[OWNER])
            assertNull(disk[SESSION])
            assertEquals("keep installation preference", disk[EXTRA])
            assertFalse(f.store.isCurrent(oldLease))
        } finally { f.close() }
    }

    @Test fun `B draft committed on file before stale A clear admission survives reopen`() = runTest {
        val f = fixture()
        try {
            runCurrent()
            f.seedA()
            val handle = requireNotNull(f.store.fenceForSignOut(f.ticket(), f.ownership))
            val pause = f.barriers.pause(Point.BeforeAdmission)
            val clear = async { real { f.store.clearFencedForSignOut(handle) } }
            runCurrent()
            real { pause.entered.await() }
            f.signIn("B", "session-B")
            runCurrent()
            val bDraft = sampleRequestDraft("B committed draft")
            real { f.store.saveDraft(f.lease(), bDraft) }
            assertEquals("B", f.rawPrefs()[OWNER])
            pause.release.complete(Unit)
            clear.await()
            val disk = f.diskReread()
            assertEquals("B", disk[OWNER])
            assertEquals("session-B", disk[SESSION])
            assertTrue(checkNotNull(disk[JSON]).contains("B committed draft"))
            assertFalse(checkNotNull(disk[JSON]).contains("A persisted draft"))
        } finally { f.close() }
    }

    @Test fun `cancellation after real edit transform rolls back A clear on disk`() = runTest {
        val f = fixture()
        try {
            runCurrent()
            f.seedA()
            val handle = requireNotNull(f.store.fenceForSignOut(f.ticket(), f.ownership))
            val pause = f.barriers.pause(Point.AfterTransform)
            var cancelled = false
            val clear = launch {
                try { real { f.store.clearFencedForSignOut(handle) } }
                catch (_: CancellationException) { cancelled = true }
            }
            runCurrent()
            real { pause.entered.await() }
            clear.cancel(CancellationException("caller cancelled after transform"))
            pause.release.complete(Unit)
            clear.join()
            assertTrue("caller must see cancellation", cancelled)
            assertNull("A draft lease remains fenced despite disk rollback", f.store.activeSession.value)
            val disk = f.diskReread()
            assertEquals("A", disk[OWNER])
            assertTrue(checkNotNull(disk[JSON]).contains("A persisted draft"))
        } finally { f.close() }
    }

    @Test fun `failed real edit after transform rolls back disk while leaving A fenced`() = runTest {
        val f = fixture()
        try {
            runCurrent()
            f.seedA()
            val handle = requireNotNull(f.store.fenceForSignOut(f.ticket(), f.ownership))
            f.barriers.afterTransformFailure = IOException("synthetic file edit failure")
            var failed = false
            try { real { f.store.clearFencedForSignOut(handle) } }
            catch (error: IOException) {
                failed = true
                assertEquals("synthetic file edit failure", error.message)
            }
            assertTrue("the edit failure must reach cleanup", failed)
            assertNull("failed disk edit must not restore A lease", f.store.activeSession.value)
            val disk = f.diskReread()
            assertEquals("A", disk[OWNER])
            assertTrue(checkNotNull(disk[JSON]).contains("A persisted draft"))
            assertEquals("keep installation preference", disk[EXTRA])
        } finally { f.close() }
    }

    private companion object {
        val JSON = stringPreferencesKey("draft_json")
        val OWNER = stringPreferencesKey("draft_owner_id")
        val SESSION = stringPreferencesKey("draft_session_id")
        val EXTRA = stringPreferencesKey("unrelated_device_preference")

        suspend fun <T> real(block: suspend () -> T): T = withContext(Dispatchers.IO) {
            withTimeout(30_000) { block() }
        }
    }
}
