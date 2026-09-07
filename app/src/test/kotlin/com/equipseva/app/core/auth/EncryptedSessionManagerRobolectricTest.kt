package com.equipseva.app.core.auth

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import io.github.jan.supabase.auth.user.UserSession
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * round3816 — pins the supabase-kt >= 3.2 [io.github.jan.supabase.auth.SessionManager]
 * contract that the 3.0.3 -> 3.6.0 upgrade changed under us: `loadSession()`
 * is non-null and must THROW when nothing is stored (the SDK treats the
 * exception as "no session" via `loadSessionOrNull`). A manager that
 * silently returns a stale/empty value here would either crash the SDK's
 * import path or resurrect a signed-out user.
 *
 * Robolectric has no AndroidKeyStore provider, so on the JVM the
 * Keystore-backed prefs fail to initialise and the manager runs on its
 * volatile-memory fallback. The assertions below hold for BOTH backends —
 * they test the interface contract, not the storage medium.
 */
@RunWith(RobolectricTestRunner::class)
@Config(application = android.app.Application::class, manifest = Config.NONE)
class EncryptedSessionManagerRobolectricTest {

    private val context: Context = ApplicationProvider.getApplicationContext()
    private lateinit var manager: EncryptedSessionManager

    @Before fun freshManager() = runTest {
        manager = EncryptedSessionManager(context)
        manager.deleteSession()
    }

    @Test fun `loadSession throws when nothing is stored`() = runTest {
        val thrown = runCatching { manager.loadSession() }.exceptionOrNull()
        assertTrue("loadSession must throw an Exception when nothing is stored", thrown is Exception)
    }

    @Test fun `loadSessionOrNull is null when nothing is stored`() = runTest {
        assertNull(manager.loadSessionOrNull())
    }

    @Test fun `saved session round-trips through loadSession`() = runTest {
        val session = sampleSession()
        manager.saveSession(session)
        val loaded = manager.loadSession()
        assertEquals(session.accessToken, loaded.accessToken)
        assertEquals(session.refreshToken, loaded.refreshToken)
        assertEquals(session.expiresIn, loaded.expiresIn)
        assertEquals(session.tokenType, loaded.tokenType)
    }

    @Test fun `deleteSession makes loadSession throw again`() = runTest {
        manager.saveSession(sampleSession())
        manager.deleteSession()
        assertNull(manager.loadSessionOrNull())
        val thrown = runCatching { manager.loadSession() }.exceptionOrNull()
        assertTrue("loadSession must throw an Exception when nothing is stored", thrown is Exception)
    }

    private fun sampleSession() = UserSession(
        accessToken = "access-token-r3816",
        refreshToken = "refresh-token-r3816",
        expiresIn = 3600,
        tokenType = "bearer",
    )
}
