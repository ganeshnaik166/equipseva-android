package com.equipseva.app.core.data

import androidx.room.Room
import androidx.sqlite.db.SupportSQLiteOpenHelper
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.equipseva.app.core.data.entities.OutboxEntryEntity
import com.equipseva.app.core.data.secure.DbPassphraseStore
import com.equipseva.app.core.data.secure.KeystorePassphraseSealer
import java.io.File
import kotlinx.coroutines.runBlocking
import net.zetetic.database.sqlcipher.SQLiteNotADatabaseException
import net.zetetic.database.sqlcipher.SupportOpenHelperFactory
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

/**
 * WP22.T03 on a device, with real SQLCipher and the real Android Keystore (under a test-only
 * alias, so the app's own key is never touched): a database created with key A, the Keystore
 * key lost, and the database provided again must give an empty, working outbox instead of
 * "file is not a database" on every launch.
 */
@RunWith(AndroidJUnit4::class)
class DatabaseKeyLossRecoveryInstrumentedTest {
    private val context = InstrumentationRegistry.getInstrumentation().targetContext
    private val name = "t03-keyloss-test.db"
    private val dbFile get() = context.getDatabasePath(name)
    private val dir = File(context.filesDir, "t03-keyloss-test")
    private val alias = "equipseva.t03.instrumented-test.key"

    private fun store() = DbPassphraseStore(dir, KeystorePassphraseSealer(alias))
    private fun open(factory: SupportSQLiteOpenHelper.Factory) =
        Room.databaseBuilder(context, AppDatabase::class.java, name).openHelperFactory(factory).build()
    private fun entry() = OutboxEntryEntity(kind = "t03-test", payload = "{}", createdAt = 1L)
    private fun cleanUp() {
        databaseFilesToDelete(dbFile).forEach { it.delete() }
        dir.deleteRecursively()
        KeystorePassphraseSealer(alias).discardKey()
    }

    @Before fun setUp() {
        System.loadLibrary("sqlcipher")
        cleanUp()
        dir.mkdirs()
    }

    @After fun tearDown() = cleanUp()

    @Test
    fun lostKeystoreKey_providesAnEmptyWorkingOutbox() = runBlocking {
        val stash = File(dir, "photo-outbox")
        val (keyA, first) = passphraseForDatabase(store(), dbFile, stash) {}
        assertEquals(DatabaseFilesPrep.Unchanged, first)
        open(SupportOpenHelperFactory(keyA.copyOf())).apply {
            outboxDao().enqueue(entry())
            close()
        }
        assertTrue(dbFile.exists())

        // The Keystore key is lost (invalidated, or deleted by the system).
        KeystorePassphraseSealer(alias).discardKey()

        var recorded = 0
        val (keyB, prep) = passphraseForDatabase(store(), dbFile, stash) { recorded++ }
        assertEquals(DatabaseFilesPrep.DiscardedAfterKeyLoss, prep)
        assertEquals(1, recorded)
        assertFalse(keyA.contentEquals(keyB))
        val db = open(RecoveringOpenHelperFactory(keyB, onDiscard = { recorded++ }))
        assertEquals(emptyList<OutboxEntryEntity>(), db.outboxDao().nextBatch())
        db.outboxDao().enqueue(entry())
        db.close()
        assertEquals("the files were already discarded, so the open needed no second discard", 1, recorded)

        // The next launch unseals key B and keeps the new database.
        val (keyAgain, again) = passphraseForDatabase(store(), dbFile, stash) { recorded++ }
        assertEquals(DatabaseFilesPrep.Unchanged, again)
        assertTrue(keyB.contentEquals(keyAgain))
        val reopened = open(RecoveringOpenHelperFactory(keyAgain, onDiscard = { recorded++ }))
        assertEquals(1, reopened.outboxDao().nextBatch().size)
        reopened.close()
        assertEquals(1, recorded)
    }

    @Test
    fun aDatabaseAnOlderVersionLeftUnreadable_isHealedAtTheFirstOpen() = runBlocking {
        val keyA = ByteArray(32) { 1 }
        val keyB = ByteArray(32) { 2 }
        open(SupportOpenHelperFactory(keyA.copyOf())).apply {
            outboxDao().enqueue(entry())
            close()
        }

        // What the old code left behind: a new key next to the old database. Without the
        // wrapper the first query fails, on every launch.
        val broken = open(SupportOpenHelperFactory(keyB.copyOf()))
        try {
            broken.outboxDao().nextBatch()
            fail("an unreadable database opened")
        } catch (e: Exception) {
            assertTrue("$e", generateSequence<Throwable>(e) { it.cause }.any { it is SQLiteNotADatabaseException })
        } finally {
            broken.close()
        }

        var discards = 0
        val healed = open(RecoveringOpenHelperFactory(keyB, onDiscard = { discards++ }))
        assertEquals(emptyList<OutboxEntryEntity>(), healed.outboxDao().nextBatch())
        healed.outboxDao().enqueue(entry())
        healed.close()
        assertEquals(1, discards)

        val again = open(RecoveringOpenHelperFactory(keyB, onDiscard = { discards++ }))
        assertEquals("it stays healed", 1, again.outboxDao().nextBatch().size)
        again.close()
        assertEquals(1, discards)
    }
}
