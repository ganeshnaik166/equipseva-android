package com.equipseva.app.core.sync

import android.app.Application
import android.database.sqlite.SQLiteTransactionListener
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.room.withTransaction
import androidx.sqlite.db.SupportSQLiteDatabase
import androidx.sqlite.db.SupportSQLiteOpenHelper
import androidx.sqlite.db.framework.FrameworkSQLiteOpenHelperFactory
import androidx.test.core.app.ApplicationProvider
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.auth.LocalSessionOwnership
import com.equipseva.app.core.data.AppDatabase
import com.equipseva.app.core.data.DatabaseModule
import com.equipseva.app.core.data.entities.OutboxEntryEntity
import com.equipseva.app.testing.FakeAuthRepository
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.async
import kotlinx.coroutines.cancel
import kotlinx.coroutines.cancelAndJoin
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeout
import org.junit.After
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.SQLiteMode

/** Generated DAO and real file SQLite; deletion safety, not row confidentiality or SQLCipher. */
@RunWith(RobolectricTestRunner::class)
@Config(application = Application::class, manifest = Config.NONE, sdk = [34])
@SQLiteMode(SQLiteMode.Mode.NATIVE)
class OutboxSignOutCleanerTest {
    private val context = ApplicationProvider.getApplicationContext<Application>()
    private val name = "ob.db"
    private val opened = mutableListOf<AppDatabase>()
    private val sessions = mutableListOf<Session>()
    private var database = open()

    private class Session(initial: AuthSession = AuthSession.SignedIn("A", "initial@test.invalid")) {
        val auth = FakeAuthRepository(initial)
        @Volatile var raw: LocalSessionOwnership.Identity? = identity("A")
        val scope = CoroutineScope(SupervisorJob() + Dispatchers.Unconfined)
        val ownership = LocalSessionOwnership(auth, { raw }, scope)
        fun ticket() = requireNotNull(ownership.capture())
        fun signIn(user: String, session: String = "session-$user") {
            raw = identity(user, session)
            auth.setSession(AuthSession.SignedIn(user, "$session@test.invalid"))
            assertEquals(raw, ticket().identity)
        }
        fun signOut() { raw = null; auth.setSession(AuthSession.SignedOut) }
    }

    private fun session(initial: AuthSession = AuthSession.SignedIn("A", "initial@test.invalid")) =
        Session(initial).also { sessions += it }

    private fun open(observer: Transactions? = null): AppDatabase =
        Room.databaseBuilder(context, AppDatabase::class.java, name)
            .addMigrations(*DatabaseModule.APP_MIGRATIONS)
            .setJournalMode(RoomDatabase.JournalMode.WRITE_AHEAD_LOGGING)
            .apply { if (observer != null) openHelperFactory(observer.factory()) }
            .build().also { opened += it }

    private fun reopen() {
        opened.forEach { it.close() }
        opened.clear()
        database = open()
    }

    @After fun close() {
        sessions.forEach { it.scope.cancel() }
        opened.forEach { it.close() }
        context.deleteDatabase(name)
    }

    private suspend fun put(label: String, db: AppDatabase = database): OutboxEntryEntity {
        val row = OutboxEntryEntity(kind = "synthetic-$label", payload = "{\"marker\":\"$label\"}", createdAt = 123,
            attempts = 2, lastError = "synthetic retry")
        return row.copy(id = db.outboxDao().enqueue(row))
    }

    private suspend fun rows(db: AppDatabase = database) = db.outboxDao().nextBatch(100)
    private suspend fun clear(s: Session, ticket: LocalSessionOwnership.Ticket?, db: AppDatabase = database) =
        OutboxSignOutCleaner(db, s.ownership).clearForSignOut(ticket)

    @Test fun `B commit ahead of blocked actual A transaction survives stale cleanup and reopen`() = roomTest {
        val s = session()
        val ticket = s.ticket()
        val a = put("A")
        val transactions = Transactions()
        val delayed = open(transactions)
        rows(delayed) // Finish Room opening before arming the mutation observer.
        val held = CompletableDeferred<Unit>()
        val release = CompletableDeferred<Unit>()
        val b = CompletableDeferred<OutboxEntryEntity>()
        val writer = async(Dispatchers.IO) {
            database.withTransaction {
                b.complete(put("B"))
                held.complete(Unit)
                release.await()
            }
        }
        var cleanup: Job? = null
        try {
            held.await()
            transactions.armed.set(true)
            val deleting = async(Dispatchers.IO) { clear(s, ticket, delayed) }.also { cleanup = it }
            transactions.entered.await()
            assertFalse("SQLite admission is blocked by the first writer", transactions.acquired.isCompleted)
            assertSame("A is still current while its actual begin is blocked", ticket, s.ownership.capture())
            s.signIn("B")
            release.complete(Unit)
            writer.await()
            deleting.await()
            assertTrue(transactions.acquired.isCompleted)
            reopen()
            assertEquals(listOf(a, b.await()).sortedBy { it.id }, rows().sortedBy { it.id })
        } finally {
            release.complete(Unit)
            finish(writer, cleanup)
        }
    }

    @Test fun `A admitted deletion commits before queued B enqueue and persisted B survives`() = roomTest {
        val s = session()
        put("A")
        val first = Transactions(holdEnd = true)
        val deletingDb = open(first)
        rows(deletingDb)
        val second = Transactions()
        val writingDb = open(second)
        rows(writingDb)
        first.armed.set(true)
        val deleting = async(Dispatchers.IO) { clear(s, s.ticket(), deletingDb) }
        var writer: Job? = null
        try {
            first.beforeEnd.await()
            assertEquals("The actual DELETE ran inside the held transaction", 0, first.rowsBeforeEnd)
            s.signIn("B")
            second.armed.set(true)
            val enqueue = async(Dispatchers.IO) { put("B-after-delete", writingDb) }.also { writer = it }
            second.entered.await()
            assertFalse("B must queue behind A's real write transaction", second.acquired.isCompleted)
            first.releaseEnd.countDown()
            deleting.await()
            val b = enqueue.await()
            assertTrue(second.acquired.isCompleted)
            reopen()
            assertEquals(listOf(b), rows())
        } finally {
            first.releaseEnd.countDown()
            finish(deleting, writer)
        }
    }

    @Test fun `ordinary current deletion persists and a fresh B enqueue remains usable`() = roomTest {
        val s = session()
        put("A")
        clear(s, s.ticket())
        reopen()
        assertTrue(rows().isEmpty())
        s.signIn("B")
        val b = put("fresh-B")
        reopen()
        assertEquals(listOf(b), rows())
    }

    @Test fun `null signed-out and initially unknown ownership cannot delete committed rows`() = roomTest {
        val original = put("recovery")
        val current = session()
        clear(current, null)
        assertEquals(listOf(original), rows())
        val departing = current.ticket()
        current.signOut()
        clear(current, departing)
        assertEquals(listOf(original), rows())
        val unknown = session(AuthSession.Unknown)
        assertNull(unknown.ownership.capture())
        clear(unknown, unknown.ownership.capture())
        reopen()
        assertEquals(listOf(original), rows())
    }

    @Test fun `replacement observed ABA and same user new session all reject the old exact ticket`() = roomTest {
        val original = put("newer-work")
        for (boundary in listOf("B", "ABA", "new-session")) {
            val s = session()
            val old = s.ticket()
            when (boundary) {
                "B" -> s.signIn("B")
                "ABA" -> { s.signOut(); s.signIn("A") }
                else -> s.signIn("A", "second-session-A")
            }
            assertNotSame(old, s.ticket())
            clear(s, old)
            assertEquals("Stale $boundary deletion lost a committed row", listOf(original), rows())
        }
        reopen()
        assertEquals(listOf(original), rows())
    }

    @Test fun `raw replacement without auth observation denies cleanup and cannot revive old ticket`() = roomTest {
        val s = session()
        val old = s.ticket()
        val original = put("raw-B")
        s.raw = identity("B")
        clear(s, old)
        assertEquals(listOf(original), rows())
        s.raw = identity("A")
        clear(s, old)
        assertNull(s.ownership.capture())
        reopen()
        assertEquals(listOf(original), rows())
    }

    @Test fun `cancellation while actual SQLite admission is blocked preserves disk before fresh B write`() = roomTest {
        val s = session()
        val ticket = s.ticket()
        val original = put("A-before-cancel")
        val transactions = Transactions()
        val delayed = open(transactions)
        rows(delayed)
        val held = CompletableDeferred<Unit>()
        val release = CompletableDeferred<Unit>()
        val holder = async(Dispatchers.IO) {
            database.withTransaction { held.complete(Unit); release.await() }
        }
        var cleanup: Job? = null
        try {
            held.await()
            transactions.armed.set(true)
            val deleting = async(Dispatchers.IO) { clear(s, ticket, delayed) }.also { cleanup = it }
            transactions.entered.await()
            assertFalse(transactions.acquired.isCompleted)
            deleting.cancel()
            release.complete(Unit)
            holder.await()
            deleting.join()
            assertTrue(deleting.isCancelled)
            transactions.ended.await() // A cancelled caller alone does not prove its SQLite work has drained.
            reopen()
            assertEquals("Cancelled cleanup must not delete on late admission", listOf(original), rows())
            s.signIn("B")
            val b = put("B-after-cancellation")
            reopen()
            assertEquals(listOf(original, b).sortedBy { it.id }, rows().sortedBy { it.id })
        } finally {
            release.complete(Unit)
            finish(holder, cleanup)
        }
    }

    @Test fun `cancellation after real delete rolls back before disk reread and current retry succeeds`() = roomTest {
        val s = session()
        val original = put("A-rollback")
        val transactions = Transactions(cancelCommit = true)
        val cancellingDb = open(transactions)
        rows(cancellingDb)
        transactions.armed.set(true)
        var caught: CancellationException? = null
        try { clear(s, s.ticket(), cancellingDb) } catch (error: CancellationException) { caught = error }
        assertNotNull("Cancellation must propagate", caught)
        assertTrue("The mutation reached the commit boundary", transactions.cancelledCommit.get())
        assertEquals("Actual deletion preceded injected cancellation", 0, transactions.rowsBeforeCancel)
        reopen()
        assertEquals(listOf(original), rows())
        clear(s, s.ticket())
        reopen()
        assertTrue(rows().isEmpty())
    }

    @Test fun `real SQLite delete failure rolls back persisted rows and retry succeeds`() = roomTest {
        val s = session()
        val original = put("A-storage-failure")
        database.openHelper.writableDatabase.execSQL(
            "CREATE TRIGGER outbox_test_failure AFTER DELETE ON outbox " +
                "BEGIN SELECT RAISE(ABORT, 'synthetic_outbox_failure'); END",
        )
        var caught: Exception? = null
        try { clear(s, s.ticket()) } catch (error: Exception) { caught = error }
        assertNotNull("SQLite failure must propagate", caught)
        assertTrue(generateSequence(caught as Throwable?) { it.cause }.take(8)
            .any { it.message.orEmpty().contains("synthetic_outbox_failure") })
        reopen()
        assertEquals(listOf(original), rows())
        database.openHelper.writableDatabase.execSQL("DROP TRIGGER outbox_test_failure")
        clear(s, s.ticket())
        reopen()
        assertTrue(rows().isEmpty())
    }

    /** Delegates all SQL; observes actual SQLite transaction calls, including nested Room queries. */
    private class Transactions(private val holdEnd: Boolean = false, private val cancelCommit: Boolean = false) {
        val armed = AtomicBoolean(false)
        val entered = CompletableDeferred<Unit>()
        val acquired = CompletableDeferred<Unit>()
        val ended = CompletableDeferred<Unit>()
        val beforeEnd = CompletableDeferred<Unit>()
        val releaseEnd = CountDownLatch(1)
        val cancelledCommit = AtomicBoolean(false)
        @Volatile var rowsBeforeEnd = -1
        @Volatile var rowsBeforeCancel = -1
        private val depth = ThreadLocal<Int>()

        private fun begin(action: () -> Unit) {
            val watched = armed.compareAndSet(true, false)
            if (watched) entered.complete(Unit)
            action()
            if (watched) { depth.set(1); acquired.complete(Unit) }
            else depth.get()?.let { depth.set(it + 1) }
        }

        fun factory() = object : SupportSQLiteOpenHelper.Factory {
            override fun create(configuration: SupportSQLiteOpenHelper.Configuration): SupportSQLiteOpenHelper {
                val actual = FrameworkSQLiteOpenHelperFactory().create(configuration)
                return object : SupportSQLiteOpenHelper by actual {
                    override val writableDatabase: SupportSQLiteDatabase get() = wrap(actual.writableDatabase)
                    override val readableDatabase: SupportSQLiteDatabase get() = wrap(actual.readableDatabase)
                }
            }
        }

        private fun count(actual: SupportSQLiteDatabase): Int = actual.query("SELECT COUNT(*) FROM outbox").use {
            check(it.moveToFirst()); it.getInt(0)
        }

        private fun wrap(actual: SupportSQLiteDatabase): SupportSQLiteDatabase = object : SupportSQLiteDatabase by actual {
            override fun beginTransaction() = begin { actual.beginTransaction() }
            override fun beginTransactionNonExclusive() = begin { actual.beginTransactionNonExclusive() }
            override fun beginTransactionWithListener(transactionListener: SQLiteTransactionListener) =
                begin { actual.beginTransactionWithListener(transactionListener) }
            override fun beginTransactionWithListenerNonExclusive(transactionListener: SQLiteTransactionListener) =
                begin { actual.beginTransactionWithListenerNonExclusive(transactionListener) }

            override fun setTransactionSuccessful() {
                if (depth.get() == 1 && cancelCommit && cancelledCommit.compareAndSet(false, true)) {
                    rowsBeforeCancel = count(actual)
                    throw CancellationException("synthetic cancellation before actual SQLite commit")
                }
                actual.setTransactionSuccessful()
            }

            override fun endTransaction() {
                val activeDepth = depth.get()
                try {
                    if (activeDepth == 1 && holdEnd) {
                        rowsBeforeEnd = count(actual)
                        beforeEnd.complete(Unit)
                        check(releaseEnd.await(15, TimeUnit.SECONDS)) { "Timed out releasing real SQLite transaction" }
                    }
                } finally {
                    try { actual.endTransaction() } finally {
                        if (activeDepth == null || activeDepth == 1) {
                            depth.remove()
                            if (activeDepth == 1) ended.complete(Unit)
                        }
                        else depth.set(activeDepth - 1)
                    }
                }
            }
        }
    }

    private fun roomTest(block: suspend CoroutineScope.() -> Unit) = runBlocking {
        withTimeout(20_000) { block() }
    }

    private suspend fun finish(vararg jobs: Job?) = withContext(NonCancellable + Dispatchers.IO) {
        withTimeout(20_000) { jobs.filterNotNull().forEach { it.cancelAndJoin() } }
    }

    companion object {
        private fun identity(user: String, session: String = "session-$user") =
            LocalSessionOwnership.Identity(user, session)
    }
}
