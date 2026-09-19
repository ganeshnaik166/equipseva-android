package com.equipseva.app.core.data

import org.junit.Assert.assertEquals
import org.junit.Test
import java.io.File

/**
 * Pins the wipe set used when the Keystore-sealed passphrase is lost and a
 * fresh one is minted. The regression target is a partial wipe: the `-wal`
 * and `-shm` sidecars carry pages encrypted with the OLD key, so deleting
 * only the main file leaves SQLCipher failing with "file is not a database"
 * exactly as before — a crash loop nobody can escape without clearing app
 * data.
 */
class DatabaseFilesToDeleteTest {

    @Test fun `the main file and both journal sidecars are wiped together`() {
        val names = databaseFilesToDelete(File("/data/data/com.equipseva.app/databases/equipseva.db"))
            .map { it.name }
        assertEquals(
            listOf("equipseva.db", "equipseva.db-wal", "equipseva.db-shm"),
            names,
        )
    }

    @Test fun `sidecars stay in the database directory`() {
        val dir = "/data/data/com.equipseva.app/databases"
        val parents = databaseFilesToDelete(File("$dir/equipseva.db")).map { it.parent }
        assertEquals(3, parents.size)
        parents.forEach { assertEquals(File(dir).path, File(it).path) }
    }
}
