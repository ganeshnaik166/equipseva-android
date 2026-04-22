package com.equipseva.app.core.data.prefs

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Thin wrapper over [EncryptedSharedPreferences] that exposes Flow-based reads
 * for StateFlow/combine compatibility in [UserPrefs]. The master key lives in
 * the Android Keystore under an AES256/GCM scheme; values are AEAD-sealed with
 * AES256/GCM and keys are SIV-encrypted (deterministic, so lookups work).
 *
 * If [EncryptedSharedPreferences] init throws (known OEM quirks on a few
 * Samsung + Xiaomi devices with reset/restored Keystores), we fall back to
 * plain SharedPreferences in the app-private sandbox. Prefs here are low-value
 * (role toggle, onboarding flag, favorites) — not payment or PII — so the
 * fallback is a pragmatic trade.
 */
@Singleton
class SecurePrefs @Inject constructor(@ApplicationContext context: Context) {

    private val prefs: SharedPreferences = try {
        val masterKey = MasterKey.Builder(context)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()
        EncryptedSharedPreferences.create(
            context,
            FILE_NAME,
            masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
        )
    } catch (t: Throwable) {
        Log.e(TAG, "EncryptedSharedPreferences init failed; using plain fallback.", t)
        context.getSharedPreferences(FALLBACK_FILE_NAME, Context.MODE_PRIVATE)
    }

    fun getString(key: String): String? = prefs.getString(key, null)

    fun putString(key: String, value: String?) {
        prefs.edit().apply {
            if (value == null) remove(key) else putString(key, value)
        }.apply()
    }

    fun getStringSet(key: String): Set<String> =
        prefs.getStringSet(key, emptySet()).orEmpty()

    fun putStringSet(key: String, value: Set<String>) {
        prefs.edit().putStringSet(key, value).apply()
    }

    fun stringFlow(key: String): Flow<String?> = callbackFlow {
        trySend(getString(key))
        val listener = SharedPreferences.OnSharedPreferenceChangeListener { _, changed ->
            if (changed == key) trySend(getString(key))
        }
        prefs.registerOnSharedPreferenceChangeListener(listener)
        awaitClose { prefs.unregisterOnSharedPreferenceChangeListener(listener) }
    }

    fun stringSetFlow(key: String): Flow<Set<String>> = callbackFlow {
        trySend(getStringSet(key))
        val listener = SharedPreferences.OnSharedPreferenceChangeListener { _, changed ->
            if (changed == key) trySend(getStringSet(key))
        }
        prefs.registerOnSharedPreferenceChangeListener(listener)
        awaitClose { prefs.unregisterOnSharedPreferenceChangeListener(listener) }
    }

    private companion object {
        const val TAG = "SecurePrefs"
        const val FILE_NAME = "equipseva_secure_prefs"
        const val FALLBACK_FILE_NAME = "equipseva_secure_prefs_plain"
    }
}

@Module
@InstallIn(SingletonComponent::class)
object SecurePrefsModule {
    @Provides
    @Singleton
    fun provideSecurePrefs(@ApplicationContext context: Context): SecurePrefs =
        SecurePrefs(context)
}
