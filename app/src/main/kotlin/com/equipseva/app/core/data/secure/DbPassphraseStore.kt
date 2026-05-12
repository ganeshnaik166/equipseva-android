package com.equipseva.app.core.data.secure

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import java.io.File
import java.security.KeyStore
import java.security.SecureRandom
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
 * On Keystore failure (OEM quirks, user wipe, restored backup) the caller
 * should wipe the encrypted Room DB and call [freshPassphrase] — the DB is a
 * cache + outbox, not canonical state.
 */
class DbPassphraseStore(private val context: Context) {

    fun getOrCreate(): ByteArray {
        val sealedFile = File(context.filesDir, SEALED_FILE)
        if (sealedFile.exists()) {
            runCatching { unseal(sealedFile.readBytes()) }
                .onSuccess { return it }
                .onFailure { sealedFile.delete() }
        }
        return freshPassphrase()
    }

    fun freshPassphrase(): ByteArray {
        val passphrase = ByteArray(PASSPHRASE_BYTES).also { SecureRandom().nextBytes(it) }
        val sealed = seal(passphrase)
        File(context.filesDir, SEALED_FILE).writeBytes(sealed)
        return passphrase
    }

    private fun seal(plain: ByteArray): ByteArray {
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

    private fun unseal(sealedB64: ByteArray): ByteArray {
        val raw = Base64.decode(sealedB64, Base64.NO_WRAP)
        val ivLen = raw[0].toInt() and 0xFF
        val iv = raw.copyOfRange(1, 1 + ivLen)
        val ct = raw.copyOfRange(1 + ivLen, raw.size)
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.DECRYPT_MODE, getOrCreateKey(), GCMParameterSpec(GCM_TAG_BITS, iv))
        return cipher.doFinal(ct)
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
        const val PASSPHRASE_BYTES = 32
        const val SEALED_FILE = "db-passphrase.bin"
    }
}
