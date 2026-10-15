package com.equipseva.app.core.data

import android.content.Context
import androidx.sqlite.db.SupportSQLiteDatabase
import androidx.sqlite.db.SupportSQLiteOpenHelper
import androidx.test.core.app.ApplicationProvider
import io.mockk.mockk
import java.io.File
import net.zetetic.database.sqlcipher.SQLiteNotADatabaseException
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertSame
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * WP22.T03 follow-up: a database this passphrase cannot read (what an older app version left
 * behind after losing its Keystore key) is discarded once at the first open, the loss is
 * recorded, and a new database is opened. The real SQLCipher behaviour is checked on a device by
 * DatabaseKeyLossRecoveryInstrumentedTest; these fakes pin the wrapper's own rules.
 */
@RunWith(RobolectricTestRunner::class)
@Config(application = android.app.Application::class)
class RecoveringOpenHelperFactoryTest {
    private val context: Context = ApplicationProvider.getApplicationContext()
    private val name = "recovering-test.db"
    private val dbFile get() = context.getDatabasePath(name)
    private val passphrase = ByteArray(32) { (it + 1).toByte() }
    private val opened: SupportSQLiteDatabase = mockk(relaxed = true)

    private val config = SupportSQLiteOpenHelper.Configuration.builder(context)
        .name(name)
        .callback(object : SupportSQLiteOpenHelper.Callback(1) {
            override fun onCreate(db: SupportSQLiteDatabase) = Unit
            override fun onUpgrade(db: SupportSQLiteDatabase, oldVersion: Int, newVersion: Int) = Unit
        })
        .build()

    /** One fake helper per create(); each opens with the next outcome. SQLCipher-like, it zeroes its key. */
    private inner class FakeFactory(vararg outcomes: Throwable?) : SupportSQLiteOpenHelper.Factory {
        val keys = mutableListOf<ByteArray>()
        val walSettings = mutableListOf<Boolean>()
        private val queue = ArrayDeque(outcomes.toList())
        override fun create(configuration: SupportSQLiteOpenHelper.Configuration): SupportSQLiteOpenHelper {
            val key = keys.last()
            val outcome = queue.removeFirstOrNull()
            return object : SupportSQLiteOpenHelper {
                override val databaseName: String? = configuration.name
                override val writableDatabase: SupportSQLiteDatabase get() = open()
                override val readableDatabase: SupportSQLiteDatabase get() = open()
                override fun setWriteAheadLoggingEnabled(enabled: Boolean) { walSettings += enabled }
                override fun close() = Unit
                private fun open(): SupportSQLiteDatabase {
                    key.fill(0)
                    outcome?.let { throw it }
                    return opened
                }
            }
        }
    }

    private fun factory(fake: FakeFactory, onDiscard: () -> Unit) =
        RecoveringOpenHelperFactory(passphrase, onDiscard) { key -> fake.keys += key; fake }

    private fun writeOldDatabase() {
        dbFile.parentFile!!.mkdirs()
        listOf(dbFile, File("${dbFile.path}-wal"), File("${dbFile.path}-shm")).forEach { it.writeBytes(ByteArray(64) { 7 }) }
    }
    private fun existing() = listOf(dbFile, File("${dbFile.path}-wal"), File("${dbFile.path}-shm")).filter { it.exists() }.map { it.name }

    @Before fun clean() { listOf(dbFile, File("${dbFile.path}-wal"), File("${dbFile.path}-shm")).forEach { it.delete() } }

    @Test
    fun `a database the key cannot read is discarded once, recorded first, and a new one opens`() {
        writeOldDatabase()
        val fake = FakeFactory(SQLiteNotADatabaseException("file is not a database"), null)
        val seenAtDiscard = mutableListOf<List<String>>()
        val helper = factory(fake) { seenAtDiscard += existing() }.create(config)
        helper.setWriteAheadLoggingEnabled(true)

        assertSame(opened, helper.writableDatabase)
        assertEquals(listOf(listOf("recovering-test.db", "recovering-test.db-wal", "recovering-test.db-shm")), seenAtDiscard)
        assertEquals(emptyList<String>(), existing())
        assertEquals("the new helper keeps the WAL setting", listOf(true, true), fake.walSettings)
        assertEquals(2, fake.keys.size)
        assertArrayEquals("the reopen gets the real key although the first open zeroed its copy", passphrase, ByteArray(32) { (it + 1).toByte() })
        assertTrue(fake.keys.all { it.all { b -> b == 0.toByte() } })
    }

    @Test
    fun `the reopen is given the passphrase, not the array SQLCipher zeroed`() {
        val keysSeen = mutableListOf<ByteArray>()
        val fake = FakeFactory(SQLiteNotADatabaseException("file is not a database"), null)
        val helper = RecoveringOpenHelperFactory(passphrase, onDiscard = {}) { key -> keysSeen += key.copyOf(); fake.keys += key; fake }
            .create(config)
        helper.readableDatabase
        assertEquals(2, keysSeen.size)
        keysSeen.forEach { assertArrayEquals(passphrase, it) }
    }

    @Test
    fun `a second failure is passed on, never looped`() {
        writeOldDatabase()
        var discards = 0
        val again = SQLiteNotADatabaseException("still not a database")
        val helper = factory(FakeFactory(SQLiteNotADatabaseException("file is not a database"), again)) { discards++ }.create(config)
        assertSame(again, assertThrows(SQLiteNotADatabaseException::class.java) { helper.writableDatabase })
        assertThrows(SQLiteNotADatabaseException::class.java) { helper.writableDatabase }
        assertEquals(1, discards)
    }

    @Test
    fun `other errors and healthy opens discard nothing`() {
        writeOldDatabase()
        var discards = 0
        val other = IllegalStateException("disk full")
        assertSame(other, assertThrows(IllegalStateException::class.java) {
            factory(FakeFactory(other)) { discards++ }.create(config).writableDatabase
        })
        assertSame(opened, factory(FakeFactory(null)) { discards++ }.create(config).writableDatabase)
        assertEquals(0, discards)
        assertEquals(3, existing().size)
    }

    @Test
    fun `an in-memory database is never treated as a file to discard`() {
        val inMemory = SupportSQLiteOpenHelper.Configuration.builder(context).callback(config.callback).build()
        var discards = 0
        val helper = factory(FakeFactory(SQLiteNotADatabaseException("x"))) { discards++ }.create(inMemory)
        assertThrows(SQLiteNotADatabaseException::class.java) { helper.writableDatabase }
        assertEquals(0, discards)
    }
}
