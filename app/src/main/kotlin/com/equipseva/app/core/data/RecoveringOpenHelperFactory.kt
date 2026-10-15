package com.equipseva.app.core.data

import androidx.sqlite.db.SupportSQLiteDatabase
import androidx.sqlite.db.SupportSQLiteOpenHelper
import net.zetetic.database.sqlcipher.SQLiteNotADatabaseException
import net.zetetic.database.sqlcipher.SupportOpenHelperFactory

/**
 * Opens the database through SQLCipher and heals one state the passphrase checks cannot see
 * (WP22.T03): a database file this passphrase cannot read, which SQLCipher reports as "file is
 * not a database". An older app version left exactly that behind when its Keystore key was lost
 * (it stored a new passphrase but kept the old database), and every launch then failed on the
 * first query. On that error the database files are discarded once, [onDiscard] records the
 * loss, and a new database is opened with the same passphrase.
 *
 * Room opens the database lazily on its query threads, so this never runs on the main thread.
 * A second failure, or any other error, is passed on unchanged.
 */
internal class RecoveringOpenHelperFactory(
    passphrase: ByteArray,
    private val onDiscard: () -> Unit,
    private val factoryFor: (ByteArray) -> SupportSQLiteOpenHelper.Factory = { SupportOpenHelperFactory(it) },
) : SupportSQLiteOpenHelper.Factory {

    // SQLCipher's factory may clear the array it is given once the database is open, so every
    // helper gets its own copy and this one is kept for a possible second open.
    private val passphrase = passphrase.copyOf()

    override fun create(configuration: SupportSQLiteOpenHelper.Configuration): SupportSQLiteOpenHelper =
        RecoveringOpenHelper(configuration)

    private inner class RecoveringOpenHelper(
        private val configuration: SupportSQLiteOpenHelper.Configuration,
    ) : SupportSQLiteOpenHelper {
        private val lock = Any()
        private var helper: SupportSQLiteOpenHelper = factoryFor(passphrase.copyOf()).create(configuration)
        private var writeAheadLogging: Boolean? = null
        private var recovered = false

        override val databaseName: String?
            get() = synchronized(lock) { helper.databaseName }

        override val writableDatabase: SupportSQLiteDatabase
            get() = open { it.writableDatabase }

        override val readableDatabase: SupportSQLiteDatabase
            get() = open { it.readableDatabase }

        override fun setWriteAheadLoggingEnabled(enabled: Boolean) = synchronized(lock) {
            writeAheadLogging = enabled
            helper.setWriteAheadLoggingEnabled(enabled)
        }

        override fun close() = synchronized(lock) { helper.close() }

        private fun open(get: (SupportSQLiteOpenHelper) -> SupportSQLiteDatabase): SupportSQLiteDatabase =
            synchronized(lock) {
                try {
                    get(helper)
                } catch (e: SQLiteNotADatabaseException) {
                    val name = configuration.name
                    if (recovered || name == null) throw e
                    recovered = true
                    runCatching { helper.close() }
                    onDiscard()
                    databaseFilesToDelete(configuration.context.getDatabasePath(name)).forEach { it.delete() }
                    helper = factoryFor(passphrase.copyOf()).create(configuration)
                    writeAheadLogging?.let(helper::setWriteAheadLoggingEnabled)
                    get(helper)
                }
            }
    }
}
