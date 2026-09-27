package com.equipseva.app.core.auth

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import androidx.core.content.edit
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import dagger.hilt.android.qualifiers.ApplicationContext
import io.github.jan.supabase.auth.SessionManager
import io.github.jan.supabase.auth.user.UserSession
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.serialization.json.Json

/**
 * Custom [SessionManager] that wraps the Supabase access + refresh
 * token pair in Keystore-backed AES256/GCM EncryptedSharedPreferences.
 *
 * Without this override, supabase-kt's Android default falls back to
 * `SettingsSessionManager` over `multiplatform-settings`, which on
 * Android persists the session JSON in a plain `SharedPreferences`
 * file. On a rooted device or via debug-bridge access to the app
 * sandbox, those tokens are readable and grant persistent account
 * impersonation until the user explicitly signs out. See the
 * V21 security audit (round 2) for the original finding.
 *
 * Storage scheme:
 *   * Master key derived in Android Keystore (AES256/GCM scheme)
 *   * Values AEAD-sealed with AES256/GCM, keys SIV-encrypted (so
 *     lookups are deterministic across processes / cold-starts)
 *   * Single key `session_v1` holds the serialized [UserSession] JSON
 *     — a versioned key name so a future format migration can ship
 *     a new key alongside the old without colliding.
 *
 * Fallback behaviour: on a Keystore failure (rare OEM Keystore-reset
 * bugs on some Samsung/Xiaomi devices) the session is kept ONLY in
 * volatile memory for the lifetime of the process. The session is
 * NEVER persisted unencrypted on disk — better to make the user sign
 * in again on cold-start than to expose tokens. The fallback is
 * logged so on-device Keystore failures are observable.
 */
@Singleton
class EncryptedSessionManager @Inject constructor(@ApplicationContext context: Context) : SessionManager {

    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
        coerceInputValues = true
    }

    private val prefs: SharedPreferences? = try {
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
        Log.e(
            TAG,
            "EncryptedSharedPreferences for session storage failed to init; using volatile memory fallback. " +
                "Session will not survive process death.",
            t,
        )
        null
    }

    @Volatile
    private var memorySession: UserSession? = null

    private val storageLock = Any()

    /** Read-only ingress witness while SDK restoration is pending; never returns session tokens. */
    internal fun peekStoredLoginTicket(): LoginTicketSnapshot? = synchronized(storageLock) {
        try {
            val session = prefs?.getString(KEY, null)?.let { raw ->
                json.decodeFromString(UserSession.serializer(), raw)
            } ?: if (prefs == null) memorySession else null
            session?.let { parseLoginTicket(it.user?.id, it.accessToken) }
        } catch (_: Exception) {
            // A corrupt or temporarily unreadable encrypted value cannot witness a login.
            // loadSession retains the SDK's existing clear-on-decode-failure contract.
            null
        }
    }

    override suspend fun saveSession(session: UserSession) {
        synchronized(storageLock) {
            val encoded = runCatching {
                json.encodeToString(UserSession.serializer(), session)
            }.getOrNull()
            if (encoded == null) {
                Log.e(TAG, "Failed to serialize session; refusing to persist.")
                return
            }
            val p = prefs
            if (p != null) {
                p.edit { putString(KEY, encoded) }
            } else {
                memorySession = session
            }
        }
    }

    /**
     * supabase-kt >= 3.2 contract: return the stored session or THROW —
     * the SDK wraps every call in try/catch (`loadSessionOrNull`,
     * `AuthImpl.loadFromStorage`) and treats any exception as "no
     * session". Returning null is no longer part of the signature.
     *
     * A blob that fails to decode (e.g. a session persisted by an older
     * SDK whose wire shape changed) is cleared before throwing so the
     * next cold start does not repeat the failure; the user signs in
     * once more. Only [Exception]s are thrown — the SDK's catch clauses
     * are `catch (e: Exception)`, so an [Error] would escape them.
     */
    override suspend fun loadSession(): UserSession = synchronized(storageLock) {
        val p = prefs
            ?: return@synchronized memorySession ?: throw NoSuchElementException("No session in volatile memory")
        val raw = p.getString(KEY, null) ?: throw NoSuchElementException("No stored session")
        try {
            json.decodeFromString(UserSession.serializer(), raw)
        } catch (e: Exception) {
            Log.w(TAG, "Stored session failed to decode; clearing.", e)
            p.edit { remove(KEY) }
            throw IllegalStateException("Stored session failed to decode; cleared", e)
        }
    }

    override suspend fun deleteSession() {
        synchronized(storageLock) {
            prefs?.edit { remove(KEY) }
            memorySession = null
        }
    }

    private companion object {
        const val TAG = "EncryptedSessionManager"
        const val FILE_NAME = "equipseva_supabase_session"
        const val KEY = "session_v1"
    }
}
