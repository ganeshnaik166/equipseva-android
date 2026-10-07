package com.equipseva.app.core.data.secure

import android.security.keystore.KeyPermanentlyInvalidatedException
import java.io.File
import java.security.KeyStoreException
import java.security.ProviderException
import java.security.UnrecoverableKeyException
import javax.crypto.AEADBadTagException
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * WP22.T03 (SYNC-07): losing the Keystore key must not crash-loop the app, and a Keystore
 * hiccup must not throw away the encrypted database with its queued offline changes. A new
 * passphrase is stored only by [DbPassphraseStore.Passphrase.commit], which the caller runs
 * after the old database files are gone.
 */
@RunWith(RobolectricTestRunner::class)
@Config(application = android.app.Application::class)
class DbPassphraseStoreTest {
    @get:Rule val tmp = TemporaryFolder()

    /** Seals by prefixing a marker; unseal answers from [unsealScript] first, then decodes. */
    private class FakeSealer(vararg unsealScript: Throwable) : PassphraseSealer {
        val script = ArrayDeque(unsealScript.toList())
        var unsealCalls = 0
        override fun seal(plain: ByteArray): ByteArray = MARKER + plain
        override fun unseal(sealed: ByteArray): ByteArray {
            unsealCalls++
            script.removeFirstOrNull()?.let { throw it }
            require(sealed.size > MARKER.size && sealed.copyOfRange(0, MARKER.size).contentEquals(MARKER))
            return sealed.copyOfRange(MARKER.size, sealed.size)
        }
        companion object { val MARKER = "sealed:".toByteArray() }
    }

    private val sealedFile get() = File(tmp.root, DbPassphraseStore.SEALED_FILE)
    private val strikesFile get() = File(tmp.root, DbPassphraseStore.STRIKES_FILE)
    private val original = ByteArray(32) { it.toByte() }

    private fun sealOriginal() = sealedFile.writeBytes(FakeSealer.MARKER + original)
    private fun store(sealer: PassphraseSealer) = DbPassphraseStore(tmp.root, sealer)

    @Test
    fun `first run mints a passphrase and seals it on commit`() {
        val p = store(FakeSealer()).getOrCreate()
        assertTrue(p.mintedFresh)
        assertEquals(32, p.bytes.size)
        assertFalse("nothing is stored before commit", sealedFile.exists())
        p.commit()
        assertArrayEquals(FakeSealer.MARKER + p.bytes, sealedFile.readBytes())
    }

    @Test
    fun `a successful unseal returns the same bytes and is not fresh`() {
        sealOriginal()
        val p = store(FakeSealer()).getOrCreate()
        assertFalse(p.mintedFresh)
        assertArrayEquals(original, p.bytes)
        p.commit()
        assertArrayEquals(FakeSealer.MARKER + original, sealedFile.readBytes())
    }

    @Test
    fun `a permanent unseal failure mints a fresh passphrase and a new sealed file`() {
        listOf(
            AEADBadTagException("tag mismatch"),
            KeyPermanentlyInvalidatedException(),
            UnrecoverableKeyException("gone"),
            IllegalArgumentException("bad base-64"),
            ProviderException("keystore", KeyPermanentlyInvalidatedException()),
        ).forEach { failure ->
            sealOriginal()
            val sealer = FakeSealer(failure)
            val p = store(sealer).getOrCreate()
            assertTrue("$failure", p.mintedFresh)
            assertFalse("$failure", p.bytes.contentEquals(original))
            assertEquals("$failure is not retried", 1, sealer.unsealCalls)
            assertArrayEquals("$failure: the old copy stays until commit", FakeSealer.MARKER + original, sealedFile.readBytes())
            p.commit()
            assertArrayEquals("$failure", FakeSealer.MARKER + p.bytes, sealedFile.readBytes())
        }
    }

    @Test
    fun `a crash before commit mints again on the next launch`() {
        sealOriginal()
        val lost = store(FakeSealer(AEADBadTagException("tag"))).getOrCreate()
        assertTrue(lost.mintedFresh)
        // The process dies here, before the old database is discarded and before commit.
        val next = store(FakeSealer(AEADBadTagException("tag"))).getOrCreate()
        assertTrue("the next launch still knows the old database must go", next.mintedFresh)
    }

    @Test
    fun `a transient Keystore failure followed by success keeps the sealed file`() {
        listOf(KeyStoreException("busy"), ProviderException("keystore restarting")).forEach { failure ->
            sealOriginal()
            val sealer = FakeSealer(failure)
            val p = store(sealer).getOrCreate()
            assertFalse("$failure", p.mintedFresh)
            assertArrayEquals("$failure", original, p.bytes)
            assertArrayEquals("$failure", FakeSealer.MARKER + original, sealedFile.readBytes())
            assertEquals("$failure", 2, sealer.unsealCalls)
        }
    }

    @Test
    fun `a Keystore that stays down throws and keeps the database key, until the third launch`() {
        sealOriginal()
        repeat(DbPassphraseStore.MAX_TRANSIENT_STRIKES - 1) { launch ->
            assertThrows(ProviderException::class.java) {
                store(FakeSealer(ProviderException("down"), ProviderException("down"))).getOrCreate()
            }
            assertArrayEquals("launch $launch", FakeSealer.MARKER + original, sealedFile.readBytes())
            assertEquals("${launch + 1}", strikesFile.readText())
        }
        val p = store(FakeSealer(ProviderException("down"), ProviderException("down"))).getOrCreate()
        assertTrue(p.mintedFresh)
        p.commit()
        assertFalse(strikesFile.exists())
    }

    @Test
    fun `a good launch clears earlier strikes`() {
        sealOriginal()
        assertThrows(KeyStoreException::class.java) {
            store(FakeSealer(KeyStoreException("busy"), KeyStoreException("busy"))).getOrCreate()
        }
        assertTrue(strikesFile.exists())
        val p = store(FakeSealer()).getOrCreate()
        assertFalse(p.mintedFresh)
        assertFalse(strikesFile.exists())
    }

    @Test
    fun `the real sealer treats a corrupt or empty file as permanent before touching the Keystore`() {
        val sealer = KeystorePassphraseSealer()
        listOf("not base64 !!".toByteArray(), ByteArray(0), "AQ==".toByteArray()).forEach { bytes ->
            val error = runCatching { sealer.unseal(bytes) }.exceptionOrNull()
            assertTrue("${error?.javaClass}", error is IllegalArgumentException)
            assertFalse(DbPassphraseStore.isTransient(error!!))
        }
    }

    @Test
    fun `transient means a Keystore or provider failure with no permanent cause`() {
        assertTrue(DbPassphraseStore.isTransient(KeyStoreException("busy")))
        assertTrue(DbPassphraseStore.isTransient(ProviderException("restarting")))
        assertTrue(DbPassphraseStore.isTransient(RuntimeException("wrap", ProviderException("restarting"))))
        assertFalse(DbPassphraseStore.isTransient(ProviderException("x", AEADBadTagException("tag"))))
        assertFalse(DbPassphraseStore.isTransient(IllegalStateException("unknown")))
    }
}
