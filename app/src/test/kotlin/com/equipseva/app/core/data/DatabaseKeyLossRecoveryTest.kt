package com.equipseva.app.core.data

import com.equipseva.app.core.data.secure.DbPassphraseStore
import com.equipseva.app.core.data.secure.FakeSealer
import java.io.File
import javax.crypto.AEADBadTagException
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

/**
 * WP22.T03 (SYNC-07): when the database passphrase had to be minted fresh, the old encrypted
 * files (main, -wal, -shm) can never be opened again and must go before Room opens the
 * database; otherwise SQLCipher fails with "file is not a database" on every launch. The check
 * reads files only and never opens the database. (The real SQLCipher open after a lost key
 * needs the native library, so it is checked on a device, not here.)
 */
class DatabaseKeyLossRecoveryTest {
    @get:Rule val tmp = TemporaryFolder()

    private val db get() = File(tmp.root, "equipseva.db")
    private fun sidecars() = listOf(File(tmp.root, "equipseva.db-wal"), File(tmp.root, "equipseva.db-shm"))
    private fun existing() = (listOf(db) + sidecars()).filter { it.exists() }.map { it.name }

    private fun writeEncrypted() {
        db.writeBytes(ByteArray(4096) { (it * 31 + 7).toByte() })
        sidecars().forEach { it.writeBytes(ByteArray(64) { 1 }) }
    }

    private fun writePlain() {
        db.writeBytes("SQLite format 3".toByteArray() + ByteArray(4081))
        sidecars().forEach { it.writeBytes(ByteArray(64) { 1 }) }
    }

    @Test
    fun `a fresh passphrase discards the old encrypted files, recording the loss first`() {
        writeEncrypted()
        val seenBeforeDiscard = mutableListOf<List<String>>()
        assertEquals(
            DatabaseFilesPrep.DiscardedAfterKeyLoss,
            prepareDatabaseFiles(db, mintedFresh = true) { seenBeforeDiscard += existing() },
        )
        assertEquals(listOf(listOf("equipseva.db", "equipseva.db-wal", "equipseva.db-shm")), seenBeforeDiscard)
        assertEquals(emptyList<String>(), existing())
    }

    @Test
    fun `nothing is recorded when no database is discarded`() {
        var calls = 0
        writeEncrypted()
        prepareDatabaseFiles(db, mintedFresh = false) { calls++ }
        db.delete()
        prepareDatabaseFiles(db, mintedFresh = true) { calls++ }
        writePlain()
        prepareDatabaseFiles(db, mintedFresh = true) { calls++ }
        assertEquals(0, calls)
    }

    @Test
    fun `an unsealed passphrase keeps the encrypted files`() {
        writeEncrypted()
        assertEquals(DatabaseFilesPrep.Unchanged, prepareDatabaseFiles(db, mintedFresh = false))
        assertEquals(listOf("equipseva.db", "equipseva.db-wal", "equipseva.db-shm"), existing())
    }

    @Test
    fun `a first install with no database is not a reset`() {
        assertEquals(DatabaseFilesPrep.Unchanged, prepareDatabaseFiles(db, mintedFresh = true))
        assertEquals(emptyList<String>(), existing())
    }

    @Test
    fun `stray journal files without a database are cleared but are not a reset`() {
        sidecars().forEach { it.writeBytes(ByteArray(64) { 1 }) }
        assertEquals(DatabaseFilesPrep.Unchanged, prepareDatabaseFiles(db, mintedFresh = true))
        assertEquals(emptyList<String>(), existing())
    }

    @Test
    fun `a plain-text database from an old version is still replaced`() {
        writePlain()
        assertEquals(DatabaseFilesPrep.PlainTextRemoved, prepareDatabaseFiles(db, mintedFresh = false))
        assertEquals(emptyList<String>(), existing())
    }

    // ---- the order provideDatabase runs: unseal or mint, record, discard, then store ----

    private val sealedFile get() = File(tmp.root, DbPassphraseStore.SEALED_FILE)
    private val stash get() = File(tmp.root, "photo-outbox")
    private val original = ByteArray(32) { it.toByte() }

    private fun sealOriginal() = sealedFile.writeBytes(FakeSealer.MARKER + original)

    @Test
    fun `after a key loss the notice is recorded first, the old files go, and only then the new key is stored`() {
        sealOriginal()
        writeEncrypted()
        File(stash, "job-1.jpg").apply { parentFile!!.mkdirs(); writeBytes(ByteArray(10)) }
        val seenAtRecord = mutableListOf<Pair<List<String>, Boolean>>()

        val (bytes, prep) = passphraseForDatabase(
            store = DbPassphraseStore(tmp.root, FakeSealer(AEADBadTagException("tag"))),
            database = db,
            photoStash = stash,
            markReset = { seenAtRecord += existing() to sealedFile.readBytes().contentEquals(FakeSealer.MARKER + original) },
        )

        assertEquals(DatabaseFilesPrep.DiscardedAfterKeyLoss, prep)
        assertEquals(
            "recorded once, while the old database and the old sealed copy were both still there",
            listOf(listOf("equipseva.db", "equipseva.db-wal", "equipseva.db-shm") to true),
            seenAtRecord,
        )
        assertEquals(emptyList<String>(), existing())
        assertFalse("the orphaned photo stash goes with the outbox", stash.exists())
        assertArrayEquals("the new key is stored", FakeSealer.MARKER + bytes, sealedFile.readBytes())
    }

    @Test
    fun `a device an older version left with no sealed copy and a broken key recovers too`() {
        writeEncrypted()
        var records = 0
        val (bytes, prep) = passphraseForDatabase(
            DbPassphraseStore(tmp.root, FakeSealer(brokenKey = true)), db, stash,
        ) { records++ }
        assertEquals(DatabaseFilesPrep.DiscardedAfterKeyLoss, prep)
        assertEquals(1, records)
        assertEquals(emptyList<String>(), existing())
        assertArrayEquals(FakeSealer.MARKER + bytes, sealedFile.readBytes())
    }

    @Test
    fun `a healthy start changes nothing`() {
        sealOriginal()
        writeEncrypted()
        File(stash, "job-1.jpg").apply { parentFile!!.mkdirs(); writeBytes(ByteArray(10)) }
        var records = 0
        val (bytes, prep) = passphraseForDatabase(DbPassphraseStore(tmp.root, FakeSealer()), db, stash) { records++ }
        assertEquals(DatabaseFilesPrep.Unchanged, prep)
        assertArrayEquals(original, bytes)
        assertEquals(0, records)
        assertEquals(listOf("equipseva.db", "equipseva.db-wal", "equipseva.db-shm"), existing())
        assertTrue(File(stash, "job-1.jpg").exists())
        assertArrayEquals(FakeSealer.MARKER + original, sealedFile.readBytes())
    }

    @Test
    fun `a first install stores a key and records nothing`() {
        var records = 0
        val (bytes, prep) = passphraseForDatabase(DbPassphraseStore(tmp.root, FakeSealer()), db, stash) { records++ }
        assertEquals(DatabaseFilesPrep.Unchanged, prep)
        assertEquals(0, records)
        assertArrayEquals(FakeSealer.MARKER + bytes, sealedFile.readBytes())
    }

    @Test
    fun `the main file and both journal sidecars are wiped together`() {
        val names = databaseFilesToDelete(File("/data/data/com.equipseva.app/databases/equipseva.db"))
            .map { it.name }
        assertEquals(listOf("equipseva.db", "equipseva.db-wal", "equipseva.db-shm"), names)
    }
}
