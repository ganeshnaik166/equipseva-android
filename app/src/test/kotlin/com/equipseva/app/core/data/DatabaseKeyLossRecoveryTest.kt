package com.equipseva.app.core.data

import java.io.File
import org.junit.Assert.assertEquals
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

    @Test
    fun `the main file and both journal sidecars are wiped together`() {
        val names = databaseFilesToDelete(File("/data/data/com.equipseva.app/databases/equipseva.db"))
            .map { it.name }
        assertEquals(listOf("equipseva.db", "equipseva.db-wal", "equipseva.db-shm"), names)
    }
}
