package com.equipseva.app.core.data.repair

import android.app.Application
import android.database.sqlite.SQLiteTransactionListener
import androidx.room.Room
import androidx.room.withTransaction
import androidx.sqlite.db.SupportSQLiteDatabase
import androidx.sqlite.db.SupportSQLiteOpenHelper
import androidx.sqlite.db.framework.FrameworkSQLiteOpenHelperFactory
import androidx.test.core.app.ApplicationProvider
import com.equipseva.app.core.data.AppDatabase
import com.equipseva.app.core.data.DatabaseModule
import com.equipseva.app.core.data.dao.RepairPhotoDeliveryDao
import com.equipseva.app.core.data.entities.RepairPhotoDeliveryEntity
import java.io.File
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import org.junit.After
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.SQLiteMode

/** Actual generated Room DAO over file SQLite. No worker, SQLCipher or file-I/O claim. */
@RunWith(RobolectricTestRunner::class)
@Config(application = Application::class, manifest = Config.NONE, sdk = [34])
@SQLiteMode(SQLiteMode.Mode.NATIVE)
class RepairPhotoDeliveryRoomQaTest {
    private val context = ApplicationProvider.getApplicationContext<Application>()
    // Robolectric already gives every test an isolated directory. Keep the basename
    // short so native SQLite's Windows journal paths stay below MAX_PATH.
    private val databaseName = "q.db"
    private val opened = mutableListOf<AppDatabase>()
    private var database = open()
    private val dao: RepairPhotoDeliveryDao get() = database.repairPhotoDeliveryDao()
    private val owner = id(1)
    private val session = id(2)
    private val job = id(3)

    @After fun close() {
        opened.forEach { it.close() }
        context.deleteDatabase(databaseName)
    }

    private fun open(observer: TransactionObserver? = null): AppDatabase = Room.databaseBuilder(context, AppDatabase::class.java, databaseName)
        .addMigrations(*DatabaseModule.APP_MIGRATIONS)
        .setJournalMode(androidx.room.RoomDatabase.JournalMode.WRITE_AHEAD_LOGGING)
        .apply { if (observer != null) openHelperFactory(observer.factory()) }
        .build().also { opened += it }

    private fun reopen() { database.close(); database = open() }
    private suspend fun activate(): PhotoDeliveryScope = requireNotNull(dao.activate(owner, session, null)).scope()
    private fun photo(n: Int = 10, kind: String = "photo_before", jobId: String = job) = PreparedRepairPhoto(
        operationId = id(n), jobId = jobId, evidenceKind = kind,
        objectPath = "$owner/$jobId/${id(n)}.jpg",
        preparedFilePath = File(context.filesDir, "${id(n)}.jpg").absolutePath,
        contentSha256 = "a".repeat(64), contentSizeBytes = 1024,
        mimeType = "image/jpeg", capturedAt = "2026-09-09T12:00:00Z",
        captureProvenance = "client_save_time", createdAt = 100,
    )
    private fun receipt(photo: PreparedRepairPhoto) = UploadedRepairPhotoReceipt(
        "repair-photos/${photo.objectPath}", photo.contentSha256, photo.contentSizeBytes, photo.mimeType,
    )
    private suspend fun claim(scope: PhotoDeliveryScope, now: Long = 100, token: Int = 1000) =
        requireNotNull(dao.claimNext(scope, now, 100, id(token)))
    private suspend fun uploaded(scope: PhotoDeliveryScope, photo: PreparedRepairPhoto): RepairPhotoDeliveryEntity {
        requireNotNull(dao.create(scope, photo))
        return requireNotNull(dao.markUploaded(claim(scope), receipt(photo), 101))
    }
    private suspend fun registered(scope: PhotoDeliveryScope, photo: PreparedRepairPhoto): RepairPhotoDeliveryEntity {
        uploaded(scope, photo)
        return requireNotNull(dao.markRegistered(claim(scope, 102, 1001), id(900), photo.objectPath, 103))
    }

    @Test fun `same intent replay and distinct captures preserve immutable identity across reopen`() = runBlocking {
        val scope = activate()
        val first = photo()
        val original = requireNotNull(dao.create(scope, first))
        assertEquals(original, dao.create(scope, first))
        assertNotNull(dao.create(scope, photo(11, "photo_after")))
        val mutations = listOf(
            first.copy(jobId = id(99)), first.copy(evidenceKind = "photo_after"),
            first.copy(objectPath = "$owner/$job/changed.jpg"),
            first.copy(preparedFilePath = File(context.filesDir, "other.jpg").absolutePath),
            first.copy(contentSha256 = "b".repeat(64)), first.copy(contentSizeBytes = 1025),
            first.copy(mimeType = "image/png"), first.copy(capturedAt = "2026-09-10T12:00:00Z"),
            first.copy(captureProvenance = "client_asserted"), first.copy(createdAt = 101),
        )
        mutations.forEach { assertNull(dao.create(scope, it)) }
        assertNull(dao.create(scope, photo(12).copy(objectPath = first.objectPath)))
        assertNull(dao.create(scope, photo(13).copy(preparedFilePath = first.preparedFilePath)))
        reopen()
        assertEquals(original, dao.get(scope, first.operationId))
        assertEquals(2, dao.list(scope).size)
    }

    @Test fun `invalid identity path receipt and format cannot create durable rows`() = runBlocking {
        val scope = activate()
        val p = photo()
        val invalid = listOf(
            p.copy(operationId = ""), p.copy(jobId = "bad"), p.copy(formatVersion = 2),
            p.copy(evidenceKind = "photo_issue"), p.copy(objectPath = "$owner/$job/../x.jpg"),
            p.copy(objectPath = "$owner/$job/.."), p.copy(objectPath = "repair-photos/${p.objectPath}"),
            p.copy(objectPath = "${id(99)}/$job/a.jpg"), p.copy(objectPath = "$owner/$job/a b.jpg"),
            p.copy(preparedFilePath = "relative.jpg"), p.copy(preparedFilePath = ""),
            p.copy(preparedFilePath = File(context.filesDir, "${p.operationId}-${id(99)}.jpg").absolutePath),
            p.copy(contentSha256 = "A".repeat(64)), p.copy(contentSha256 = "a".repeat(63)),
            p.copy(contentSizeBytes = 0), p.copy(contentSizeBytes = PhotoDeliveryPolicy.MAX_FILE_BYTES + 1),
            p.copy(mimeType = "application/pdf"), p.copy(capturedAt = "not-a-time"),
            p.copy(captureProvenance = "EXIF_verified"), p.copy(createdAt = -1),
        )
        invalid.forEach { assertNull(it.toString(), dao.create(scope, it)) }
        listOf(scope.copy(ownerId = ""), scope.copy(sessionId = ""), scope.copy(generation = 0))
            .forEach { assertNull(dao.create(it, p)) }
        assertTrue(dao.list(scope).isEmpty())
        reopen()
        assertTrue(dao.list(scope).isEmpty())
    }

    @Test fun `durable fence rejects old scopes and delayed activation across A B and new A`() = runBlocking {
        val scopeA = activate()
        val p = photo()
        dao.create(scopeA, p)
        val oldClaim = claim(scopeA)
        assertEquals(scopeA, requireNotNull(dao.activate(owner, session, 0)).scope())
        val stopped = requireNotNull(dao.deactivate(scopeA, 0))
        reopen()
        assertEquals(stopped, dao.fenceSnapshot())
        assertNull(dao.activate(owner, session, 0))
        val scopeB = requireNotNull(dao.activate(id(20), id(21), requireNotNull(dao.fenceSnapshot()).revision)).scope()
        val b = photo(22).copy(objectPath = "${scopeB.ownerId}/$job/${id(22)}.jpg")
        val bRow = requireNotNull(dao.create(scopeB, b))
        assertNull(dao.get(scopeA, p.operationId))
        assertTrue(dao.list(scopeA).isEmpty())
        assertNull(dao.create(scopeA, photo(23)))
        assertNull(dao.claimNext(scopeA, 150, 100, id(24)))
        assertNull(dao.markUploaded(oldClaim, receipt(p), 150))
        assertNull(dao.release(oldClaim, 150))
        assertNull(dao.recordRetry(oldClaim, 150, 10, PhotoDeliveryError.NETWORK))
        assertNull(dao.requestRemoval(scopeA, p.operationId, oldClaim.revision))
        assertNull(dao.retryNeedsAttention(scopeA, p.operationId, oldClaim.revision))
        assertFalse(dao.acknowledgeCleanup(oldClaim, 150))
        assertEquals(bRow, dao.get(scopeB, b.operationId))
        val currentB = requireNotNull(dao.activate(scopeB.ownerId, scopeB.sessionId, stopped.revision + 1))
        val newA = requireNotNull(dao.activate(owner, id(30), currentB.revision)).scope()
        reopen()
        val resumed = requireNotNull(dao.fenceSnapshot())
        assertEquals(newA, requireNotNull(dao.activate(owner, id(30), resumed.revision)).scope())
        assertTrue(newA.generation > scopeA.generation)
        assertTrue(dao.list(newA).isEmpty())
        assertNull(dao.create(newA, p)) // An old operation cannot be adopted even by the same UID.
        assertNotNull(dao.create(newA, photo(31)))
        assertNull(dao.activate(scopeB.ownerId, scopeB.sessionId, currentB.revision))
    }

    @Test fun `two Room connections racing one eligible operation yield one claim`() = runBlocking {
        val scope = activate()
        dao.create(scope, photo())
        val second = open().repairPhotoDeliveryDao()
        second.list(scope) // Open both connections before the barrier.
        val ready = CountDownLatch(2)
        val start = CountDownLatch(1)
        val results = withTimeout(20_000) {
            val contenders = listOf(dao, second).mapIndexed { i, target -> async(Dispatchers.IO) {
                ready.countDown()
                check(start.await(5, TimeUnit.SECONDS))
                target.claimNext(scope, 100, 100, id(1000 + i))
            } }
            check(ready.await(5, TimeUnit.SECONDS))
            start.countDown()
            contenders.awaitAll()
        }
        assertEquals(1, results.count { it != null })
        val winner = requireNotNull(results.single { it != null })
        assertEquals(winner.token, dao.get(scope, photo().operationId)?.claimToken)
        assertNull(second.claimNext(scope, 199, 100, id(1002)))
    }

    @Test fun `expiry exact boundary and clock reversal reject late holder including token reuse ABA`() = runBlocking {
        val scope = activate()
        val p = photo()
        dao.create(scope, p)
        val old = claim(scope)
        val original = dao.get(scope, p.operationId)
        assertNull(dao.markUploaded(old, receipt(p), 99))
        assertNull(dao.claimNext(scope, 99, 100, id(1001)))
        assertNull(dao.claimNext(scope, 199, 100, id(1001)))
        assertEquals(original, dao.get(scope, p.operationId))
        assertNull(dao.markUploaded(old, receipt(p), 200))
        val replacement = requireNotNull(dao.claimNext(scope, 200, 100, old.token))
        assertTrue(replacement.revision > old.revision)
        assertNull(dao.markUploaded(old, receipt(p), 150))
        assertNull(dao.release(old, 201))
        assertNull(dao.recordRetry(old, 201, 10, PhotoDeliveryError.NETWORK))
        assertNotNull(dao.markUploaded(replacement, receipt(p), 201))
    }

    @Test fun `all invalid claim coordinates are rejected without changing the full row`() = runBlocking {
        val scope = activate()
        val p = photo()
        dao.create(scope, p)
        val valid = claim(scope)
        val original = dao.get(scope, p.operationId)
        val invalid = listOf(
            valid.copy(operationId = id(999)), valid.copy(scope = scope.copy(ownerId = id(99))),
            valid.copy(scope = scope.copy(sessionId = id(99))), valid.copy(scope = scope.copy(generation = 99)),
            valid.copy(revision = valid.revision - 1), valid.copy(token = id(99)), valid.copy(token = ""),
            valid.copy(startedAt = 99), valid.copy(expiresAt = 201),
        )
        invalid.forEach {
            assertNull(dao.markUploaded(it, receipt(p), 101))
            assertNull(dao.markRegistered(it, id(900), p.objectPath, 101))
            assertNull(dao.recordRetry(it, 101, 10, PhotoDeliveryError.NETWORK))
            assertNull(dao.recordCleanupFailure(it, 101, 10))
            assertNull(dao.release(it, 101))
            assertFalse(dao.acknowledgeCleanup(it, 101))
            assertEquals(original, dao.get(scope, p.operationId))
        }
        assertNotNull(dao.markUploaded(valid, receipt(p), 101))
    }

    @Test fun `receipt mismatch and phase skips never advance or replace prepared bytes`() = runBlocking {
        val scope = activate()
        val p = photo()
        dao.create(scope, p)
        val lease = claim(scope)
        val original = dao.get(scope, p.operationId)
        val r = receipt(p)
        listOf(r.copy(storageUrl = p.objectPath), r.copy(sha256 = "b".repeat(64)),
            r.copy(sizeBytes = 1025), r.copy(mimeType = "image/png")).forEach {
            assertNull(dao.markUploaded(lease, it, 101))
            assertEquals(original, dao.get(scope, p.operationId))
        }
        assertNull(dao.markRegistered(lease, id(900), p.objectPath, 101))
        assertFalse(dao.acknowledgeCleanup(lease, 101))
        assertNotNull(dao.markUploaded(lease, r, 101))
    }

    @Test fun `outer transaction failure rolls uploaded checkpoint back and reopen keeps prior claim`() = runBlocking {
        val scope = activate()
        val p = photo()
        dao.create(scope, p)
        val lease = claim(scope)
        val original = dao.get(scope, p.operationId)
        try {
            database.withTransaction {
                assertNotNull(dao.markUploaded(lease, receipt(p), 101))
                throw IllegalStateException("qa_abort_after_checkpoint")
            }
        } catch (expected: IllegalStateException) {
            assertEquals("qa_abort_after_checkpoint", expected.message)
        }
        reopen()
        assertEquals(original, dao.get(scope, p.operationId))
        val result = requireNotNull(dao.markUploaded(lease, receipt(p), 102))
        reopen()
        assertEquals(result, dao.get(scope, p.operationId))
    }

    @Test fun `network cap preserves Uploaded receipt and explicit retry invalidates old callbacks`() = runBlocking {
        val scope = activate()
        val p = photo()
        val initial = uploaded(scope, p)
        var now = 110L
        var last: PhotoDeliveryClaim? = null
        repeat(PhotoDeliveryPolicy.MAX_ATTEMPTS) { index ->
            val lease = claim(scope, now, 1100 + index)
            last = lease
            val failed = requireNotNull(dao.recordRetry(lease, now + 1, 10, PhotoDeliveryError.NETWORK))
            assertEquals(index + 1, failed.attempts)
            assertEquals(initial.objectPath, failed.objectPath)
            assertEquals(initial.contentSha256, failed.contentSha256)
            assertNull(dao.claimNext(scope, now + 10, 100, id(1200 + index)))
            now += 20
        }
        val attention = requireNotNull(dao.get(scope, p.operationId))
        assertEquals(PhotoDeliveryPhase.NEEDS_ATTENTION, attention.phase)
        assertEquals(PhotoDeliveryPhase.UPLOADED, attention.resumePhase)
        assertEquals("NETWORK", attention.lastErrorCode)
        reopen()
        assertEquals(attention, dao.get(scope, p.operationId))
        assertNull(dao.claimNext(scope, 10_000, 100, id(1300)))
        assertNull(dao.retryNeedsAttention(scope.copy(generation = 99), p.operationId, attention.revision))
        val retried = requireNotNull(dao.retryNeedsAttention(scope, p.operationId, attention.revision))
        assertEquals(PhotoDeliveryPhase.UPLOADED, retried.phase)
        assertEquals(0, retried.attempts)
        assertEquals(p.contentSha256, retried.contentSha256)
        assertNull(dao.release(requireNotNull(last), now))
        assertNull(dao.retryNeedsAttention(scope, p.operationId, attention.revision))
    }

    @Test fun `permanent receipt object and local-file failures require attention immediately`() = runBlocking {
        val scope = activate()
        listOf(PhotoDeliveryError.OBJECT_CONFLICT, PhotoDeliveryError.RECEIPT_INVALID,
            PhotoDeliveryError.LOCAL_FILE_MISSING).forEachIndexed { i, error ->
            val p = photo(50 + i)
            dao.create(scope, p)
            val lease = claim(scope, 100, 1400 + i)
            val result = requireNotNull(dao.recordRetry(lease, 101, 10, error))
            assertEquals(error.name, result.lastErrorCode)
            assertEquals(PhotoDeliveryPhase.NEEDS_ATTENTION, result.phase)
            assertEquals(PhotoDeliveryPhase.PREPARED, result.resumePhase)
        }
        reopen()
        assertTrue(dao.list(scope).all { it.phase == PhotoDeliveryPhase.NEEDS_ATTENTION })
    }

    @Test fun `auth-required pauses without spending transport retry budget`() = runBlocking {
        val scope = activate()
        dao.create(scope, photo())
        val result = requireNotNull(dao.recordRetry(claim(scope), 101, 10, PhotoDeliveryError.AUTH_REQUIRED))
        assertEquals(0, result.attempts)
        assertEquals(PhotoDeliveryPhase.NEEDS_ATTENTION, result.phase)
        assertEquals("AUTH_REQUIRED", result.lastErrorCode)
        assertNull(dao.claimNext(scope, 500, 100, id(1400)))
        reopen()
        assertEquals(result, dao.get(scope, photo().operationId))
    }

    @Test fun `registered cleanup cap and explicit retry retain ledger and never repeat delivery`() = runBlocking {
        val scope = activate()
        val p = photo()
        val committed = registered(scope, p)
        reopen()
        assertEquals(committed, dao.get(scope, p.operationId))
        var now = 110L
        repeat(PhotoDeliveryPolicy.MAX_ATTEMPTS) { i ->
            val lease = claim(scope, now, 1500 + i)
            assertNull(dao.markUploaded(lease, receipt(p), now + 1))
            assertNull(dao.markRegistered(lease, id(901), p.objectPath, now + 1))
            assertNull(dao.recordRetry(lease, now + 1, 10, PhotoDeliveryError.NETWORK))
            val result = requireNotNull(dao.recordCleanupFailure(lease, now + 1, 10))
            assertEquals(PhotoDeliveryPhase.REGISTERED, result.phase)
            assertEquals(committed.ledgerId, result.ledgerId)
            assertEquals(committed.contentSha256, result.contentSha256)
            now += 20
        }
        val attention = requireNotNull(dao.get(scope, p.operationId))
        assertEquals(PhotoCleanupState.NEEDS_ATTENTION, attention.cleanupState)
        assertNull(dao.claimNext(scope, now, 100, id(1600)))
        reopen()
        assertEquals(attention, dao.get(scope, p.operationId))
        val retry = requireNotNull(dao.retryNeedsAttention(scope, p.operationId, attention.revision))
        assertEquals(PhotoDeliveryPhase.REGISTERED, retry.phase)
        assertEquals(committed.ledgerId, retry.ledgerId)
        assertEquals(PhotoCleanupState.PENDING, retry.cleanupState)
        assertTrue(dao.acknowledgeCleanup(claim(scope, now, 1601), now + 1))
        reopen()
        assertNull(dao.get(scope, p.operationId))
        assertNull(dao.create(scope, p))
    }

    @Test fun `registration requires UUID and exact bucket-free path then stale registration is rejected`() = runBlocking {
        val scope = activate()
        val p = photo()
        uploaded(scope, p)
        val lease = claim(scope, 102, 1001)
        val original = dao.get(scope, p.operationId)
        assertNull(dao.markRegistered(lease, "", p.objectPath, 103))
        assertNull(dao.markRegistered(lease, id(900), "repair-photos/${p.objectPath}", 103))
        assertNull(dao.markRegistered(lease, id(900), "$owner/$job/other.jpg", 103))
        assertEquals(original, dao.get(scope, p.operationId))
        val result = requireNotNull(dao.markRegistered(lease, id(900), p.objectPath, 103))
        assertNull(dao.markRegistered(lease, id(901), p.objectPath, 104))
        assertEquals(result, dao.get(scope, p.operationId))
    }

    @Test fun `explicit removal invalidates claim and successful cleanup retires UUID without other-row mutation`() = runBlocking {
        val scope = activate()
        val p = photo()
        dao.create(scope, p)
        val otherJob = id(4)
        val other = requireNotNull(dao.create(scope, photo(11, jobId = otherJob)))
        assertEquals(otherJob, other.jobId)
        val old = claim(scope)
        assertEquals(other, dao.get(scope, other.operationId))
        val removed = requireNotNull(dao.requestRemoval(scope, p.operationId, old.revision))
        assertTrue(removed.removalRequested)
        assertEquals(other, dao.get(scope, other.operationId))
        assertNull(dao.markUploaded(old, receipt(p), 101))
        assertNull(dao.requestRemoval(scope, p.operationId, old.revision))
        val cleanup = claim(scope, 102, 1700)
        assertEquals(p.operationId, cleanup.operationId)
        assertEquals(other, dao.get(scope, other.operationId))
        assertTrue(dao.acknowledgeCleanup(cleanup, 103))
        assertFalse(dao.acknowledgeCleanup(cleanup, 104))
        assertEquals(other, dao.get(scope, other.operationId))
        reopen()
        assertNull(dao.create(scope, p))
        assertEquals(otherJob, dao.get(scope, other.operationId)?.jobId)
        assertEquals(other, dao.get(scope, other.operationId))
    }

    @Test fun `retirement insert failure rolls preceding row deletion back atomically`() = runBlocking {
        val scope = activate()
        val p = photo()
        registered(scope, p)
        val cleanup = claim(scope, 110, 1800)
        val original = dao.get(scope, p.operationId)
        database.openHelper.writableDatabase.execSQL(
            "CREATE TRIGGER qa_retirement_failure BEFORE INSERT ON repair_photo_delivery_retired " +
                "BEGIN SELECT RAISE(ABORT, 'qa_retirement_failure'); END",
        )
        val failure = runCatching { dao.acknowledgeCleanup(cleanup, 111) }
        assertTrue(failure.isFailure)
        assertEquals(original, dao.get(scope, p.operationId))
        database.openHelper.writableDatabase.execSQL("DROP TRIGGER qa_retirement_failure")
        reopen()
        assertEquals(original, dao.get(scope, p.operationId))
        assertTrue(dao.acknowledgeCleanup(cleanup, 112))
    }

    @Test fun `claim and retry duration overflow or invalid time leave full row unchanged`() = runBlocking {
        val scope = activate()
        val p = photo()
        dao.create(scope, p)
        val original = dao.get(scope, p.operationId)
        listOf(-1L to 1L, 100L to 0L, 100L to -1L,
            100L to PhotoDeliveryPolicy.MAX_CLAIM_MILLIS + 1,
            Long.MAX_VALUE to 1L).forEach { (now, duration) ->
            assertNull(dao.claimNext(scope, now, duration, id(1900)))
            assertEquals(original, dao.get(scope, p.operationId))
        }
        val lease = claim(scope)
        val held = dao.get(scope, p.operationId)
        listOf(0L, -1L, PhotoDeliveryPolicy.MAX_RETRY_DELAY_MILLIS + 1).forEach {
            assertNull(dao.recordRetry(lease, 101, it, PhotoDeliveryError.NETWORK))
            assertEquals(held, dao.get(scope, p.operationId))
        }
        assertNull(dao.recordRetry(lease, Long.MAX_VALUE, 1, PhotoDeliveryError.NETWORK))
        assertEquals(held, dao.get(scope, p.operationId))
    }

    @Test fun `release and new claim with same token cannot accept prior revision`() = runBlocking {
        val scope = activate()
        val p = photo()
        dao.create(scope, p)
        val first = claim(scope)
        requireNotNull(dao.release(first, 101))
        val next = requireNotNull(dao.claimNext(scope, 102, 100, first.token))
        assertTrue(next.revision > first.revision)
        assertNull(dao.markUploaded(first, receipt(p), 103))
        assertNull(dao.release(first, 103))
        assertNotNull(dao.markUploaded(next, receipt(p), 103))
    }

    @Test fun `invalid coordinates are denied in valid Uploaded and Registered cleanup phases`() = runBlocking {
        val scope = activate()
        val p = photo()
        uploaded(scope, p)
        val uploadLease = claim(scope, 102, 2000)
        val uploadedRow = dao.get(scope, p.operationId)
        invalidClaims(uploadLease).forEach {
            assertNull(dao.markRegistered(it, id(900), p.objectPath, 103))
            assertNull(dao.recordRetry(it, 103, 10, PhotoDeliveryError.NETWORK))
            assertNull(dao.release(it, 103))
            assertEquals(uploadedRow, dao.get(scope, p.operationId))
        }
        requireNotNull(dao.markRegistered(uploadLease, id(900), p.objectPath, 103))
        val cleanup = claim(scope, 104, 2001)
        val registeredRow = dao.get(scope, p.operationId)
        invalidClaims(cleanup).forEach {
            assertNull(dao.recordCleanupFailure(it, 105, 10))
            assertNull(dao.release(it, 105))
            assertFalse(dao.acknowledgeCleanup(it, 105))
            assertEquals(registeredRow, dao.get(scope, p.operationId))
        }
        assertTrue(dao.acknowledgeCleanup(cleanup, 105))
    }

    @Test fun `invalid cleanup claim cannot retire an explicitly removed Prepared operation`() = runBlocking {
        val scope = activate()
        val p = photo()
        val created = requireNotNull(dao.create(scope, p))
        requireNotNull(dao.requestRemoval(scope, p.operationId, created.revision))
        val cleanup = claim(scope)
        val row = dao.get(scope, p.operationId)
        invalidClaims(cleanup).forEach {
            assertFalse(dao.acknowledgeCleanup(it, 101))
            assertNull(dao.recordCleanupFailure(it, 101, 10))
            assertEquals(row, dao.get(scope, p.operationId))
        }
        assertTrue(dao.acknowledgeCleanup(cleanup, 101))
    }

    @Test fun `transition committed before fence invalidation remains historical and old callbacks stop`() = runBlocking {
        fenceOrdering(invalidateFirst = false)
    }

    @Test fun `fence invalidation committed before transition rejects old checkpoint`() = runBlocking {
        fenceOrdering(invalidateFirst = true)
    }

    private suspend fun fenceOrdering(invalidateFirst: Boolean) = kotlinx.coroutines.coroutineScope {
        val scope = activate()
        val p = photo()
        dao.create(scope, p)
        val lease = claim(scope)
        val observer = TransactionObserver()
        val secondDao = open(observer).repairPhotoDeliveryDao()
        secondDao.list(scope)
        withTimeout(20_000) {
            val transactionHeld = CompletableDeferred<Unit>()
            val allowCommit = CompletableDeferred<Unit>()
            val first = async(Dispatchers.IO) {
                database.withTransaction {
                    if (invalidateFirst) assertNotNull(dao.deactivate(scope, 0))
                    else assertNotNull(dao.markUploaded(lease, receipt(p), 101))
                    transactionHeld.complete(Unit)
                    allowCommit.await()
                }
            }
            transactionHeld.await()
            observer.armed.set(true)
            val second = async(Dispatchers.IO) {
                if (invalidateFirst) assertNull(secondDao.markUploaded(lease, receipt(p), 102))
                else assertNotNull(secondDao.deactivate(scope, 0))
            }
            observer.entered.await()
            assertFalse(observer.acquired.isCompleted)
            assertFalse(second.isCompleted)
            allowCommit.complete(Unit)
            first.await()
            second.await()
            assertTrue(observer.acquired.isCompleted)
        }
        assertNull(dao.get(scope, p.operationId))
        assertNull(dao.markUploaded(lease, receipt(p), 103))
        assertNull(dao.create(scope, photo(11)))
        database.openHelper.readableDatabase.query("SELECT phase FROM repair_photo_deliveries WHERE operationId = ?", arrayOf(p.operationId)).use {
            assertTrue(it.moveToFirst())
            assertEquals(if (invalidateFirst) PhotoDeliveryPhase.PREPARED else PhotoDeliveryPhase.UPLOADED, it.getString(0))
        }
    }

    @Test fun `revision and generation saturation fail closed without wraparound`() = runBlocking {
        val scope = activate()
        val p = photo()
        dao.create(scope, p)
        database.openHelper.writableDatabase.execSQL("UPDATE repair_photo_deliveries SET revision = ?", arrayOf(Long.MAX_VALUE))
        val row = dao.get(scope, p.operationId)
        assertNull(dao.claimNext(scope, 100, 100, id(2100)))
        assertNull(dao.requestRemoval(scope, p.operationId, Long.MAX_VALUE))
        assertEquals(row, dao.get(scope, p.operationId))
        database.openHelper.writableDatabase.execSQL("UPDATE repair_photo_delivery_fence SET generation = ?", arrayOf(Long.MAX_VALUE))
        val maximum = requireNotNull(dao.fenceSnapshot())
        assertNull(dao.deactivate(maximum.scope(), maximum.revision))
        assertNull(dao.activate(id(99), id(98), maximum.revision))
        assertEquals(maximum, dao.fenceSnapshot())
        database.openHelper.writableDatabase.execSQL("UPDATE repair_photo_delivery_fence SET generation=1, revision=?", arrayOf(Long.MAX_VALUE))
        val revisionMaximum = requireNotNull(dao.fenceSnapshot())
        assertNull(dao.deactivate(revisionMaximum.scope(), revisionMaximum.revision))
        assertNull(dao.activate(id(99), id(98), revisionMaximum.revision))
        assertEquals(revisionMaximum, dao.fenceSnapshot())
    }

    private fun invalidClaims(valid: PhotoDeliveryClaim) = listOf(
        valid.copy(operationId = id(999)), valid.copy(scope = valid.scope.copy(ownerId = id(99))),
        valid.copy(scope = valid.scope.copy(sessionId = id(99))), valid.copy(scope = valid.scope.copy(generation = 99)),
        valid.copy(revision = valid.revision - 1), valid.copy(token = id(99)), valid.copy(token = ""),
        valid.copy(startedAt = valid.startedAt - 1), valid.copy(expiresAt = valid.expiresAt + 1),
    )

    /** Observe actual second SQLite helper transaction entry, not coroutine scheduling. */
    private class TransactionObserver {
        val armed = AtomicBoolean(false)
        val entered = CompletableDeferred<Unit>()
        val acquired = CompletableDeferred<Unit>()

        private fun observe(begin: () -> Unit) {
            val watch = armed.compareAndSet(true, false)
            if (watch) entered.complete(Unit)
            begin()
            if (watch) acquired.complete(Unit)
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

        private fun wrap(actual: SupportSQLiteDatabase): SupportSQLiteDatabase = object : SupportSQLiteDatabase by actual {
            override fun beginTransaction() = observe { actual.beginTransaction() }
            override fun beginTransactionNonExclusive() = observe { actual.beginTransactionNonExclusive() }
            override fun beginTransactionWithListener(transactionListener: SQLiteTransactionListener) =
                observe { actual.beginTransactionWithListener(transactionListener) }
            override fun beginTransactionWithListenerNonExclusive(transactionListener: SQLiteTransactionListener) =
                observe { actual.beginTransactionWithListenerNonExclusive(transactionListener) }
        }
    }

    // Deliberately invalid coordinates probe the DAO's SQL authority checks, not a public copy API.
    private fun PhotoDeliveryClaim.copy(
        operationId: String = this.operationId,
        scope: PhotoDeliveryScope = this.scope,
        revision: Long = this.revision,
        token: String = this.token,
        startedAt: Long = this.startedAt,
        expiresAt: Long = this.expiresAt,
    ) = PhotoDeliveryClaim(operationId, scope, revision, token, startedAt, expiresAt)

    private fun id(value: Int): String = "00000000-0000-4000-8000-${value.toString().padStart(12, '0')}"
}
