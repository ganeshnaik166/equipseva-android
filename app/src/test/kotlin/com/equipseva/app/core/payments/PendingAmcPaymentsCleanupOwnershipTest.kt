package com.equipseva.app.core.payments

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.core.stringSetPreferencesKey
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.auth.LocalSessionOwnership
import com.equipseva.app.testing.FakeAuthRepository
import java.io.File
import java.io.IOException
import java.util.concurrent.atomic.AtomicInteger
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Deferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.async
import kotlinx.coroutines.cancelAndJoin
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeout
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/** Production mutation and real file serialization; the wrapper only supplies barriers. */
@RunWith(RobolectricTestRunner::class)
@Config(application = android.app.Application::class, manifest = Config.NONE, sdk = [34])
@OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)
class PendingAmcPaymentsCleanupOwnershipTest {
    @get:Rule val files = TemporaryFolder()

    private enum class Point { BeforeAdmission, AfterTransform }
    private class Pause(val point: Point) {
        val entered = CompletableDeferred<Unit>()
        val release = CompletableDeferred<Unit>()
    }

    private class Barriers(private val actual: DataStore<Preferences>) : DataStore<Preferences> {
        override val data: Flow<Preferences> = actual.data
        private val lock = Any()
        private var next: Pause? = null
        val calls = MutableStateFlow(0)
        val transforms = AtomicInteger()
        val pauses = mutableListOf<Pause>()
        var failure: IOException? = null
        var afterTransformFailure: IOException? = null
        fun pause(point: Point) = Pause(point).also { synchronized(lock) { next = it; pauses += it } }

        override suspend fun updateData(transform: suspend (Preferences) -> Preferences): Preferences {
            val pause = synchronized(lock) { next.also { next = null } }
            calls.value++
            failure?.let { failure = null; throw it }
            if (pause?.point == Point.BeforeAdmission) {
                pause.entered.complete(Unit)
                pause.release.await()
            }
            return actual.updateData { current ->
                transforms.incrementAndGet()
                // Invoke the REAL production edit transform; no test-side guard.
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

    private class Fixture(
        scope: TestScope,
        val file: File,
        initial: AuthSession = AuthSession.SignedIn("A", "a@test.invalid"),
    ) {
        val auth = FakeAuthRepository(initial)
        @Volatile var raw: LocalSessionOwnership.Identity? = identity("A")
        val owner = LocalSessionOwnership(auth, { raw }, scope.backgroundScope)
        private val diskJob = SupervisorJob()
        private val diskScope = CoroutineScope(diskJob + Dispatchers.IO)
        private val actual = PreferenceDataStoreFactory.create(scope = diskScope, produceFile = { file })
        val barriers = Barriers(actual)
        val store = PendingAmcPaymentsStore(barriers, owner)
        val work = mutableListOf<Job>()
        fun ticket() = requireNotNull(owner.capture())
        fun signIn(user: String, session: String = "session-$user") {
            raw = identity(user, session)
            auth.setSession(AuthSession.SignedIn(user, "$session@test.invalid"))
        }
        suspend fun record(proof: VerifiableAmcPayment) = real {
            store.add(proof.paymentOrderId)
            store.recordVerifiable(proof)
        }
        suspend fun rawPrefs(): Preferences = real { actual.data.first() }
        suspend fun seed(proof: VerifiableAmcPayment = proof("A")) {
            record(proof)
            real { actual.edit { it[EXTRA] = "keep-installation-data" } }
            assertProof(rawPrefs(), proof)
            assertTrue("The real preferences file must exist before any absence assertion", file.isFile)
        }
        suspend fun diskReread(): Preferences {
            real { diskJob.cancelAndJoin() }
            val readerJob = SupervisorJob()
            val reader = PreferenceDataStoreFactory.create(
                scope = CoroutineScope(readerJob + Dispatchers.IO), produceFile = { file },
            )
            return try { real { reader.data.first() } } finally { real { readerJob.cancelAndJoin() } }
        }
        suspend fun close() = withContext(NonCancellable + Dispatchers.Default) {
            withTimeout(5_000) {
                work.forEach { it.cancel() }
                barriers.pauses.forEach { it.release.complete(Unit) }
                work.forEach { it.join() }
                diskJob.cancelAndJoin()
            }
        }
    }

    private fun TestScope.fixture(initial: AuthSession = AuthSession.SignedIn("A", "a@test.invalid")) =
        Fixture(this, File(files.newFolder(), "pending.preferences_pb"), initial)
    private fun <T> TestScope.start(f: Fixture, block: suspend () -> T): Deferred<T> = async { block() }.also { f.work += it }

    @Test fun `ordinary current cleanup removes marker and proof together and preserves unrelated prefs`() = runTest {
        val f = fixture()
        try {
            runCurrent()
            f.seed()
            real { f.store.clearForSignOut(f.ticket()) }
            val disk = f.diskReread()
            assertNull(disk[MARKERS])
            assertNull(disk[PROOFS])
            assertEquals("keep-installation-data", disk[EXTRA])
        } finally { f.close() }
    }

    @Test fun `B committed before delayed transform keeps exact marker and proof on disk`() = runTest {
        val f = fixture()
        try {
            runCurrent(); f.seed()
            val ticket = f.ticket()
            val pause = f.barriers.pause(Point.BeforeAdmission)
            val clear = start(f) { real { f.store.clearForSignOut(ticket) } }
            real { pause.entered.await() }
            f.signIn("B"); runCurrent()
            val b = proof("B")
            f.record(b)
            assertProof(f.rawPrefs(), b)
            pause.release.complete(Unit)
            clear.await()
            assertEquals(b, real { f.store.verifiable(b.paymentOrderId) })
            // Fresh work still writes after the stale operation completed.
            val fresh = proof("B-later")
            f.record(fresh)
            val disk = f.diskReread()
            assertProof(disk, b)
            assertProof(disk, fresh)
        } finally { f.close() }
    }

    @Test fun `same payment id newer B proof survives old A cleanup instead of id subtraction`() = runTest {
        val f = fixture()
        try {
            runCurrent(); f.seed(proof("A", "shared-order"))
            val ticket = f.ticket()
            val pause = f.barriers.pause(Point.BeforeAdmission)
            val clear = start(f) { real { f.store.clearForSignOut(ticket) } }
            real { pause.entered.await() }
            f.signIn("B"); runCurrent()
            val replacement = proof("B-new-revision", "shared-order")
            f.record(replacement)
            pause.release.complete(Unit)
            clear.await()
            val disk = f.diskReread()
            assertEquals(setOf("shared-order"), disk[MARKERS])
            assertEquals(setOf(encodeVerifiableAmcPayment(replacement)), disk[PROOFS])
        } finally { f.close() }
    }

    @Test fun `same owner fresh login and observed ABA both reject departing cleanup`() = runTest {
        for (aba in listOf(false, true)) {
            val f = fixture()
            try {
                runCurrent(); f.seed()
                val ticket = f.ticket()
                val pause = f.barriers.pause(Point.BeforeAdmission)
                val clear = start(f) { real { f.store.clearForSignOut(ticket) } }
                real { pause.entered.await() }
                if (aba) { f.signIn("B"); runCurrent() }
                f.signIn("A", if (aba) "session-A" else "session-A2"); runCurrent()
                val fresh = proof("A-fresh")
                f.record(fresh)
                pause.release.complete(Unit)
                clear.await()
                assertProof(f.diskReread(), fresh)
            } finally { f.close() }
        }
    }

    @Test fun `raw replacement before observer dispatch is checked inside actual transform`() = runTest {
        val f = fixture()
        try {
            runCurrent(); f.seed()
            val ticket = f.ticket()
            val pause = f.barriers.pause(Point.BeforeAdmission)
            val clear = start(f) { real { f.store.clearForSignOut(ticket) } }
            real { pause.entered.await() }
            f.raw = identity("B") // Keep the full auth observer on A deliberately.
            val b = proof("B")
            f.record(b)
            pause.release.complete(Unit)
            clear.await()
            assertProof(f.diskReread(), b)
        } finally { f.close() }
    }

    @Test fun `B write queues behind already transformed A clear and commits afterward`() = runTest {
        val f = fixture()
        try {
            runCurrent(); f.seed(proof("A", "shared-order"))
            val ticket = f.ticket()
            val pause = f.barriers.pause(Point.AfterTransform)
            val clear = start(f) { real { f.store.clearForSignOut(ticket) } }
            real { pause.entered.await() }
            val admittedTransforms = f.barriers.transforms.get()
            val previousCalls = f.barriers.calls.value
            f.signIn("B"); runCurrent()
            val b = proof("B-after-A-transform", "shared-order")
            val bWrite = start(f) { f.record(b) }
            real { f.barriers.calls.first { it > previousCalls } }
            assertFalse("B updateData is waiting on the same real delegate", bWrite.isCompleted)
            assertEquals("B transform cannot run before A commit", admittedTransforms, f.barriers.transforms.get())
            pause.release.complete(Unit)
            clear.await(); bWrite.await()
            val disk = f.diskReread()
            assertEquals(setOf("shared-order"), disk[MARKERS])
            assertEquals(setOf(encodeVerifiableAmcPayment(b)), disk[PROOFS])
        } finally { f.close() }
    }

    @Test fun `null foreign forged retired stale and malformed identity tickets retain both keys`() = runTest {
        for (kind in listOf("null", "foreign", "forged", "retired", "stale", "malformed")) {
            val f = fixture()
            try {
                runCurrent(); f.seed()
                val issued = f.ticket()
                val ticket = when (kind) {
                    "null" -> null
                    "foreign" -> {
                        val otherOwner = LocalSessionOwnership(f.auth, { f.raw }, backgroundScope)
                        runCurrent()
                        requireNotNull(otherOwner.capture()).also { assertNotSame(issued, it) }
                    }
                    "forged" -> LocalSessionOwnership.Ticket(issued.identity, issued.generation)
                    "retired" -> issued.also { f.owner.retire(it) }
                    "stale" -> issued.also { f.signIn("B"); runCurrent() }
                    else -> issued.also { f.raw = identity("A", " ") }
                }
                val before = f.rawPrefs()
                real { f.store.clearForSignOut(ticket) }
                val after = f.diskReread()
                assertEquals("$kind ticket must preserve markers", before[MARKERS], after[MARKERS])
                assertEquals("$kind ticket must preserve exact proofs", before[PROOFS], after[PROOFS])
            } finally { f.close() }
        }
    }

    @Test fun `initial Unknown cannot authorize deletion from a cached raw login`() = runTest {
        val f = fixture(AuthSession.Unknown)
        try {
            runCurrent(); f.seed()
            real { f.store.clearForSignOut(f.owner.capture()) }
            assertProof(f.diskReread(), proof("A"))
        } finally { f.close() }
    }

    @Test fun `cancellation before admission and after transform preserves committed proof and allows fresh writes`() = runTest {
        for (point in Point.entries) {
            val f = fixture()
            var fresh: Fixture? = null
            try {
                runCurrent(); f.seed()
                val before = f.rawPrefs()
                val ticket = f.ticket()
                val pause = f.barriers.pause(point)
                val clear = start(f) { real { f.store.clearForSignOut(ticket) } }
                real { pause.entered.await() }
                real { clear.cancelAndJoin() }
                assertTrue("Cancellation must propagate from $point", clear.isCancelled)
                pause.release.complete(Unit)
                assertProof(f.rawPrefs(), proof("A"))

                // Close the cancelled writer and read disk before any new write
                // can conceal a lost original marker or exact proof.
                val cancelledDisk = f.diskReread()
                assertProof(cancelledDisk, proof("A"))
                assertEquals("Cancellation at $point preserves exact markers", before[MARKERS], cancelledDisk[MARKERS])
                assertEquals("Cancellation at $point preserves exact proofs", before[PROOFS], cancelledDisk[PROOFS])
                assertEquals(before[EXTRA], cancelledDisk[EXTRA])

                val replacement = Fixture(this, f.file).also { fresh = it }
                replacement.signIn("B"); runCurrent()
                val b = proof("B-after-cancel")
                replacement.record(b)
                val afterFreshWrite = replacement.diskReread()
                assertProof(afterFreshWrite, b)
                assertProof(afterFreshWrite, proof("A"))
                assertEquals(before[EXTRA], afterFreshWrite[EXTRA])
            } finally {
                try { fresh?.close() } finally { f.close() }
            }
        }
    }

    @Test fun `DataStore failure propagates without proof loss and current retry still clears`() = runTest {
        val f = fixture()
        try {
            runCurrent(); f.seed()
            val failure = IOException("synthetic disk failure")
            f.barriers.failure = failure
            var caught: IOException? = null
            try { real { f.store.clearForSignOut(f.ticket()) } } catch (error: IOException) { caught = error }
            assertPropagatedIOException(failure, caught)
            assertProof(f.rawPrefs(), proof("A"))
            real { f.store.clearForSignOut(f.ticket()) }
            val disk = f.diskReread()
            assertNull(disk[MARKERS]); assertNull(disk[PROOFS])
        } finally { f.close() }
    }

    @Test fun `failure after production transform preserves disk proof and recreated current retry clears`() = runTest {
        val f = fixture()
        var retry: Fixture? = null
        try {
            runCurrent(); f.seed()
            val before = f.rawPrefs()
            val transformsBefore = f.barriers.transforms.get()
            val failure = IOException("synthetic failure after transform before commit")
            f.barriers.afterTransformFailure = failure
            var caught: IOException? = null
            try { real { f.store.clearForSignOut(f.ticket()) } } catch (error: IOException) { caught = error }
            assertPropagatedIOException(failure, caught)
            assertEquals("The real production transform ran before failure", transformsBefore + 1, f.barriers.transforms.get())
            val disk = f.diskReread()
            assertEquals("Failed commit preserves marker bytes", before[MARKERS], disk[MARKERS])
            assertEquals("Failed commit preserves exact proof bytes", before[PROOFS], disk[PROOFS])
            assertEquals(before[EXTRA], disk[EXTRA])

            // The first delegate is closed for the fresh on-disk read. Recreate
            // against that same file to prove a current retry remains usable.
            val current = Fixture(this, f.file).also { retry = it }
            runCurrent()
            real { current.store.clearForSignOut(current.ticket()) }
            val afterRetry = current.diskReread()
            assertNull(afterRetry[MARKERS])
            assertNull(afterRetry[PROOFS])
            assertEquals(before[EXTRA], afterRetry[EXTRA])
        } finally {
            retry?.close()
            f.close()
        }
    }

    companion object {
        private val MARKERS = stringSetPreferencesKey("pending_amc_payment_orders")
        private val PROOFS = stringSetPreferencesKey("pending_amc_verifiable_payments")
        private val EXTRA = stringPreferencesKey("unrelated-installation-setting")
        private fun identity(user: String, session: String = "session-$user") = LocalSessionOwnership.Identity(user, session)
        private fun proof(revision: String, order: String = "order-$revision") = VerifiableAmcPayment(
            order, "razorpay-order-$revision", "razorpay-payment-$revision", "synthetic-signature-$revision",
        )
        private fun assertProof(prefs: Preferences, proof: VerifiableAmcPayment) {
            assertTrue("Marker absent for ${proof.paymentOrderId}", proof.paymentOrderId in prefs[MARKERS].orEmpty())
            assertTrue("Exact proof absent for ${proof.paymentOrderId}", encodeVerifiableAmcPayment(proof) in prefs[PROOFS].orEmpty())
        }
        private fun assertPropagatedIOException(injected: IOException, actual: IOException?) {
            assertNotNull("DataStore IOException must propagate", actual)
            val propagated = requireNotNull(actual)
            assertEquals(injected.javaClass, propagated.javaClass)
            assertEquals(injected.message, propagated.message)
            // Coroutine stack-trace recovery may copy this standard exception
            // across withContext and retain the original as its cause.
            assertTrue("Recovered IOException must retain the injected failure",
                generateSequence(propagated as Throwable) { it.cause }.take(8).any { it === injected })
        }
        // Real time, not runTest virtual time, bounds disk scheduling and shutdown.
        private suspend fun <T> real(block: suspend () -> T): T = withContext(Dispatchers.Default) {
            withTimeout(5_000) { block() }
        }
    }
}
