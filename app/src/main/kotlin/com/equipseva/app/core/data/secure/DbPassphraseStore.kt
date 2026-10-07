package com.equipseva.app.core.data.secure

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyPermanentlyInvalidatedException
import android.security.keystore.KeyProperties
import android.util.Base64
import java.io.File
import java.io.FileOutputStream
import java.nio.file.Files
import java.nio.file.StandardCopyOption
import java.security.GeneralSecurityException
import java.security.KeyStore
import java.security.KeyStoreException
import java.security.ProviderException
import java.security.SecureRandom
import javax.crypto.AEADBadTagException
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Generates a random 32-byte passphrase once per install and seals it under an
 * AES-256/GCM key held in the Android Keystore. The wrapped passphrase is
 * written to app-private storage; the raw key material never leaves the TEE /
 * StrongBox on devices that support it.
 *
 * When the sealed copy can never be unwrapped again (key invalidated or
 * unreadable, corrupt file) the Keystore key is discarded, a new passphrase is
 * minted under a fresh key, and the caller must discard the encrypted Room DB —
 * it is a cache + outbox, not canonical state — and then [Passphrase.commit] the
 * new one. [Passphrase.mintedFresh] is how the caller learns that it has to.
 *
 * Any failure that is not clearly permanent is retried once. One that still
 * looks like the Keystore being busy or restarting is thrown without touching
 * anything, so it never costs the user their queued offline changes; once
 * [MAX_TRANSIENT_STRIKES] attempts in a row (app launches or background work
 * that needs the database) failed that way, it is treated as permanent. If the
 * Keystore cannot seal a new passphrase either, the attempt throws and the
 * next one tries again: nothing can be stored without a working Keystore.
 *
 * `Passphrase(mintedFresh)` is ported from PR #1877 (commit e51e948d).
 */
class DbPassphraseStore internal constructor(
    private val dir: File,
    private val sealer: PassphraseSealer,
) {

    constructor(context: Context) : this(context.filesDir, KeystorePassphraseSealer())

    /**
     * [bytes] plus whether they were minted now rather than unwrapped from
     * the sealed copy. The flag travels with the passphrase so a caller
     * cannot take the bytes and silently miss the obligation to discard a
     * database the old key encrypted.
     */
    class Passphrase internal constructor(
        val bytes: ByteArray,
        val mintedFresh: Boolean,
        private val persist: () -> Unit = {},
    ) {
        /**
         * Stores a freshly minted passphrase (a no-op otherwise). Call it only once the
         * database files the old key encrypted are gone: a crash before it leaves the old
         * sealed copy in place, so the next launch mints and discards again instead of
         * pairing a new key with an old database.
         */
        fun commit() = persist()
    }

    fun getOrCreate(): Passphrase {
        val sealedFile = File(dir, SEALED_FILE)
        val strikesFile = File(dir, STRIKES_FILE)
        val hadSealedCopy = sealedFile.exists()
        if (hadSealedCopy) {
            val sealed = sealedFile.readBytes()
            var failure = runCatching { sealer.unseal(sealed) }
                .onSuccess { strikesFile.delete(); return Passphrase(it, mintedFresh = false) }
                .exceptionOrNull()!!
            if (!isPermanent(failure)) {
                failure = runCatching { sealer.unseal(sealed) }
                    .onSuccess { strikesFile.delete(); return Passphrase(it, mintedFresh = false) }
                    .exceptionOrNull()!!
            }
            if (isTransient(failure)) {
                val strikes = readStrikes(strikesFile) + 1
                if (strikes < MAX_TRANSIENT_STRIKES) {
                    strikesFile.writeText(strikes.toString())
                    throw failure
                }
            }
            // The old key can never unwrap this copy again, and a broken key entry would
            // fail the seal below too, so the new passphrase goes under a fresh key.
            sealer.discardKey()
        }
        // Either there was never a sealed copy, or it can never be unwrapped
        // again. Both leave a passphrase that cannot open an already-encrypted
        // database file, which is why the flag is set even on first run.
        val passphrase = ByteArray(PASSPHRASE_BYTES).also { SecureRandom().nextBytes(it) }
        val sealed = sealer.seal(passphrase)
        return Passphrase(passphrase, mintedFresh = true) {
            writeAtomically(sealedFile, sealed)
            strikesFile.delete()
        }
    }

    private fun readStrikes(file: File): Int =
        runCatching { file.readText().trim().toInt() }.getOrDefault(0).coerceAtLeast(0)

    /** The sealed copy decides whether the database is kept, so it is never left half-written. */
    private fun writeAtomically(target: File, bytes: ByteArray) {
        val tmp = File(target.parentFile, "${target.name}.tmp")
        FileOutputStream(tmp).use { out ->
            out.write(bytes)
            out.fd.sync()
        }
        Files.move(tmp.toPath(), target.toPath(), StandardCopyOption.ATOMIC_MOVE, StandardCopyOption.REPLACE_EXISTING)
    }

    internal companion object {
        const val SEALED_FILE = "db-passphrase.bin"
        const val STRIKES_FILE = "db-passphrase.strikes"
        const val MAX_TRANSIENT_STRIKES = 3
        private const val PASSPHRASE_BYTES = 32

        /** A failure that retrying can never fix: a wrong or invalidated key, or a corrupt file. */
        fun isPermanent(error: Throwable): Boolean =
            generateSequence(error) { it.cause }.take(8).any {
                it is AEADBadTagException || it is KeyPermanentlyInvalidatedException || it is CorruptSealedPassphrase
            }

        /**
         * The Keystore being busy or restarting: a KeyStoreException or ProviderException in the
         * chain with no permanent cause. Anything else that survives the retry (for example an
         * UnrecoverableKeyException) is treated as permanent, as before.
         */
        fun isTransient(error: Throwable): Boolean =
            !isPermanent(error) &&
                generateSequence(error) { it.cause }.take(8).any { it is KeyStoreException || it is ProviderException }
    }
}

/** The sealed passphrase file is unreadable (bad Base64, or too short for its header). */
class CorruptSealedPassphrase(message: String, cause: Throwable? = null) : GeneralSecurityException(message, cause)

/** Wraps and unwraps the passphrase; a seam so JVM tests can force each failure. */
interface PassphraseSealer {
    fun seal(plain: ByteArray): ByteArray
    fun unseal(sealed: ByteArray): ByteArray

    /** Deletes the wrapping key, so the next [seal] creates a fresh one. Never throws. */
    fun discardKey()
}

/** AES-256/GCM under an Android Keystore key; output is Base64 of [iv len][iv][ciphertext+tag]. */
internal class KeystorePassphraseSealer : PassphraseSealer {

    override fun seal(plain: ByteArray): ByteArray {
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, getOrCreateKey())
        val iv = cipher.iv
        val ct = cipher.doFinal(plain)
        // Format: [1-byte iv len][iv][ciphertext+tag]. Base64 for readability
        // in any future adb pulls (still encrypted).
        val raw = ByteArray(1 + iv.size + ct.size).apply {
            this[0] = iv.size.toByte()
            System.arraycopy(iv, 0, this, 1, iv.size)
            System.arraycopy(ct, 0, this, 1 + iv.size, ct.size)
        }
        return Base64.encode(raw, Base64.NO_WRAP)
    }

    override fun unseal(sealed: ByteArray): ByteArray {
        val raw = try {
            Base64.decode(sealed, Base64.NO_WRAP)
        } catch (e: IllegalArgumentException) {
            throw CorruptSealedPassphrase("sealed passphrase is not Base64", e)
        }
        if (raw.isEmpty()) throw CorruptSealedPassphrase("sealed passphrase is empty")
        val ivLen = raw[0].toInt() and 0xFF
        if (raw.size <= 1 + ivLen) throw CorruptSealedPassphrase("sealed passphrase is truncated")
        val iv = raw.copyOfRange(1, 1 + ivLen)
        val ct = raw.copyOfRange(1 + ivLen, raw.size)
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.DECRYPT_MODE, getOrCreateKey(), GCMParameterSpec(GCM_TAG_BITS, iv))
        return cipher.doFinal(ct)
    }

    override fun discardKey() {
        runCatching { KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }.deleteEntry(KEY_ALIAS) }
    }

    private fun getOrCreateKey(): SecretKey {
        val ks = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
        (ks.getKey(KEY_ALIAS, null) as? SecretKey)?.let { return it }

        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, ANDROID_KEYSTORE)
        val spec = KeyGenParameterSpec.Builder(
            KEY_ALIAS,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256)
            .setRandomizedEncryptionRequired(true)
            .build()
        generator.init(spec)
        return generator.generateKey()
    }

    private companion object {
        const val ANDROID_KEYSTORE = "AndroidKeyStore"
        const val KEY_ALIAS = "equipseva.db.passphrase.v1"
        const val TRANSFORMATION = "AES/GCM/NoPadding"
        const val GCM_TAG_BITS = 128
    }
}
