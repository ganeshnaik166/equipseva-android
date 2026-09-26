package com.equipseva.app.core.auth

import android.app.Application
import android.database.sqlite.SQLiteTransactionListener
import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import androidx.room.Room
import androidx.sqlite.db.SupportSQLiteDatabase
import androidx.sqlite.db.SupportSQLiteOpenHelper
import androidx.sqlite.db.framework.FrameworkSQLiteOpenHelperFactory
import androidx.test.core.app.ApplicationProvider
import com.equipseva.app.core.data.AppDatabase
import com.equipseva.app.core.data.entities.OutboxEntryEntity
import com.equipseva.app.core.data.repair.DraftStoreFixture
import com.equipseva.app.core.payments.PendingAmcPaymentsStore
import com.equipseva.app.core.payments.VerifiableAmcPayment
import com.equipseva.app.core.push.DeviceTokenRegistrar
import com.equipseva.app.core.sync.OutboxSignOutCleaner
import io.mockk.coEvery
import io.mockk.mockk
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.async
import kotlinx.coroutines.cancelAndJoin
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeout
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.SQLiteMode
import java.io.File
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference

/** Real cleanup/draft fence, file-backed AMC store and generated Room outbox DAO. */
@RunWith(RobolectricTestRunner::class)
@Config(application = android.app.Application::class, manifest = Config.NONE, sdk = [34])
@SQLiteMode(SQLiteMode.Mode.NATIVE)
@OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)
class SignOutCleanupLocalBoundaryRegressionTest {
    @get:Rule val temporaryFolder = TemporaryFolder()

    private class Harness(scope: TestScope, file: File) {
        val draft = DraftStoreFixture(scope)
        val ownership = LocalSessionOwnership(
            draft.auth,
            {
                draft.identity?.let { identity ->
                    identity.sessionId?.let { LocalSessionOwnership.Identity(identity.ownerId, it) }
                }
            },
            scope.backgroundScope,
        )
        private val diskJob = SupervisorJob()
        val revoked = mutableListOf<DeviceTokenRegistrar.Revocation?>()
        val captures = mutableListOf<DeviceTokenRegistrar.Revocation?>()
        val outboxGate = AtomicReference<CountDownLatch?>()
        val outboxEntered = CompletableDeferred<Unit>()
        private val context = ApplicationProvider.getApplicationContext<Application>()
        private val databaseName = "cleanup.db"
        private val database = Room.databaseBuilder(context, AppDatabase::class.java, databaseName)
            .openHelperFactory(object : SupportSQLiteOpenHelper.Factory {
                override fun create(configuration: SupportSQLiteOpenHelper.Configuration): SupportSQLiteOpenHelper {
                    val actual = FrameworkSQLiteOpenHelperFactory().create(configuration)
                    return object : SupportSQLiteOpenHelper by actual {
                        override val writableDatabase: SupportSQLiteDatabase get() = wrap(actual.writableDatabase)
                        override val readableDatabase: SupportSQLiteDatabase get() = wrap(actual.readableDatabase)
                    }
                }
            }).build()
        val registrar = mockk<DeviceTokenRegistrar> {
            coEvery { captureRevocation(any()) } answers {
                firstArg<LocalSessionOwnership.Ticket?>()?.identity?.ownerId
                    ?.let { DeviceTokenRegistrar.Revocation(it, "token-$it") }
                    .also { captures += it }
            }
            coEvery { revoke(any()) } answers { revoked += firstArg<DeviceTokenRegistrar.Revocation?>() }
        }
        val pendingPayments = PendingAmcPaymentsStore(
            PreferenceDataStoreFactory.create(
                scope = CoroutineScope(diskJob + Dispatchers.IO),
                produceFile = { file },
            ),
            ownership,
        )
        val cleanup = SignOutCleanup(
            deviceTokenRegistrar = registrar,
            outboxSignOutCleaner = OutboxSignOutCleaner(database, ownership),
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
            localSessionOwnership = ownership,
        )

        suspend fun seed() = realIo {
            enqueue("A-row")
            assertEquals(setOf("A-row"), outboxRows())
            pendingPayments.add("A-payment")
            pendingPayments.recordVerifiable(proof("A-payment"))
            assertTrue("A marker must exist before testing removal", "A-payment" in pendingPayments.list())
            assertEquals(proof("A-payment"), pendingPayments.verifiable("A-payment"))
        }

        suspend fun close() = withContext(NonCancellable + Dispatchers.IO) {
            outboxGate.getAndSet(null)?.countDown()
            withTimeout(10_000) { diskJob.cancelAndJoin() }
            database.close()
            context.deleteDatabase(databaseName)
        }

        suspend fun enqueue(payload: String) = realIo {
            database.outboxDao().enqueue(OutboxEntryEntity(kind = "synthetic", payload = payload, createdAt = 1))
        }

        suspend fun outboxRows(): Set<String> = realIo {
            database.outboxDao().nextBatch().map { it.payload }.toSet()
        }

        private fun begin(action: () -> Unit) {
            outboxGate.getAndSet(null)?.let { gate ->
                outboxEntered.complete(Unit)
                check(gate.await(10, TimeUnit.SECONDS)) { "Outbox transaction test barrier timed out" }
            }
            action()
        }

        private fun wrap(actual: SupportSQLiteDatabase): SupportSQLiteDatabase = object : SupportSQLiteDatabase by actual {
            override fun beginTransaction() = begin { actual.beginTransaction() }
            override fun beginTransactionNonExclusive() = begin { actual.beginTransactionNonExclusive() }
            override fun beginTransactionWithListener(transactionListener: SQLiteTransactionListener) =
                begin { actual.beginTransactionWithListener(transactionListener) }
            override fun beginTransactionWithListenerNonExclusive(transactionListener: SQLiteTransactionListener) =
                begin { actual.beginTransactionWithListenerNonExclusive(transactionListener) }
        }
    }

    @Test fun `departing owner is captured before a delayed draft disk clear can observe B`() = runTest {
        withHarness { h ->
            val gate = CompletableDeferred<Unit>()
            h.draft.disk.nextWriteGate = gate
            val wipe = async { h.cleanup.wipeLocalUserState() }
            try {
                runCurrent()
                assertTrue("the real draft fence retires A before waiting on disk", h.draft.store.activeSession.value == null)
                assertEquals(
                    "token capture must finish before draft disk suspension",
                    listOf(DeviceTokenRegistrar.Revocation("A", "token-A")), h.captures,
                )
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
    }

    @Test fun `B's outbox row survives A's delayed draft cleanup`() = runTest {
        withHarness { h ->
            val gate = CompletableDeferred<Unit>()
            h.draft.disk.nextWriteGate = gate
            val wipe = async { h.cleanup.wipeLocalUserState() }
            try {
                runCurrent()
                h.draft.signIn("B", "session-B")
                runCurrent()
                h.enqueue("B-row")
                assertTrue("B's real row must exist before releasing A", "B-row" in h.outboxRows())
                gate.complete(Unit)
                wipe.await()
                assertTrue("A's resumed global cleanup erased B's new work", "B-row" in h.outboxRows())
            } finally {
                gate.complete(Unit)
                wipe.cancelAndJoin()
            }
        }
    }

    @Test fun `B's payment marker survives A's suspended outbox clear`() = runTest {
        withHarness { h ->
            val gate = CountDownLatch(1)
            h.outboxGate.set(gate)
            val wipe = async { h.cleanup.wipeLocalUserState() }
            try {
                realIo { h.outboxEntered.await() }
                assertEquals(listOf(DeviceTokenRegistrar.Revocation("A", "token-A")), h.captures)
                h.draft.signIn("B", "session-B")
                runCurrent()
                realIo {
                    h.pendingPayments.add("B-payment")
                    h.pendingPayments.recordVerifiable(proof("B-payment"))
                    assertTrue("B marker must commit before releasing A", "B-payment" in h.pendingPayments.list())
                    assertEquals(proof("B-payment"), h.pendingPayments.verifiable("B-payment"))
                }
                gate.countDown()
                wipe.await()
                realIo {
                    assertTrue("A's resumed local cleanup erased B's payment marker", "B-payment" in h.pendingPayments.list())
                    assertEquals("A must preserve B's exact recovery proof", proof("B-payment"), h.pendingPayments.verifiable("B-payment"))
                }
            } finally {
                gate.countDown()
                wipe.cancelAndJoin()
            }
        }
    }

    @Test fun `B's exact payment proof survives A's earlier suspended draft clear`() = runTest {
        withHarness { h ->
            val gate = CompletableDeferred<Unit>()
            h.draft.disk.nextWriteGate = gate
            val wipe = async { h.cleanup.wipeLocalUserState() }
            try {
                runCurrent()
                assertNull("A must be paused at the real draft fence", h.draft.store.activeSession.value)
                assertEquals("A token must be captured before the draft barrier",
                    listOf(DeviceTokenRegistrar.Revocation("A", "token-A")), h.captures)
                h.draft.signIn("B", "session-B")
                runCurrent()
                realIo {
                    h.pendingPayments.add("B-payment")
                    h.pendingPayments.recordVerifiable(proof("B-payment"))
                    assertTrue("B marker must commit before A resumes", "B-payment" in h.pendingPayments.list())
                    assertEquals(proof("B-payment"), h.pendingPayments.verifiable("B-payment"))
                }
                gate.complete(Unit)
                wipe.await()
                realIo {
                    assertTrue("Capture after the draft suspension would erase B", "B-payment" in h.pendingPayments.list())
                    assertEquals(proof("B-payment"), h.pendingPayments.verifiable("B-payment"))
                }
            } finally {
                gate.complete(Unit)
                wipe.cancelAndJoin()
            }
        }
    }

    @Test fun `ordinary A cleanup still clears A's local work and revokes A`() = runTest {
        withHarness { h ->
            h.cleanup.wipeLocalUserState()
            assertTrue(h.outboxRows().isEmpty())
            realIo {
                assertTrue(h.pendingPayments.list().isEmpty())
                assertNull(h.pendingPayments.verifiable("A-payment"))
            }
            assertEquals(listOf(DeviceTokenRegistrar.Revocation("A", "token-A")), h.revoked)
        }
    }

    private suspend fun TestScope.withHarness(block: suspend (Harness) -> Unit) {
        val h = Harness(this, File(temporaryFolder.newFolder(), "amc.preferences_pb"))
        try {
            h.seed()
            runCurrent()
            block(h)
        } finally {
            h.close()
        }
    }

    private companion object {
        fun proof(id: String) = VerifiableAmcPayment(id, "order-$id", "payment-$id", "synthetic-$id")

        suspend fun <T> realIo(block: suspend () -> T): T = withContext(Dispatchers.IO) {
            // Cold native Room opening approached ten seconds in the focused
            // run and exceeded it while full-suite lint/R8 competed for CPU.
            // Keep the disk work bounded without timing out before assertions.
            withTimeout(30_000) { block() }
        }
    }
}
