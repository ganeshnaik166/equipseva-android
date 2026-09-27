package com.equipseva.app.core.auth

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import io.github.jan.supabase.auth.user.UserInfo
import io.github.jan.supabase.auth.user.UserSession
import java.util.Base64
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * RED contract for a read-only ingress witness. Robolectric uses this manager's volatile fallback;
 * device verification must separately cover Keystore-backed storage and its startup latency.
 */
@RunWith(RobolectricTestRunner::class)
@Config(application = android.app.Application::class, manifest = Config.NONE)
class EncryptedSessionTicketWitnessTest {
    private val userA = "11111111-1111-4111-8111-111111111111"
    private val userB = "22222222-2222-4222-8222-222222222222"
    private val loginA = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
    private val loginA2 = "cccccccc-cccc-4ccc-8ccc-cccccccccccc"

    @Test fun empty_and_deleted_storage_have_no_ticket() = runTest {
        val manager = manager()
        assertNull(manager.peekStoredLoginTicket())
        manager.saveSession(session(userA, jwt(userA, loginA)))
        manager.deleteSession()
        assertNull(manager.peekStoredLoginTicket())
    }

    @Test fun saved_session_yields_only_its_login_identity_without_consuming_it() = runTest {
        val manager = manager()
        val saved = session(userA, jwt(userA, loginA))
        manager.saveSession(saved)

        assertEquals(LoginTicketSnapshot(userA, loginA), manager.peekStoredLoginTicket())
        assertEquals(saved.accessToken, manager.loadSession().accessToken)
        assertEquals(saved.refreshToken, manager.loadSession().refreshToken)
    }

    @Test fun access_token_refresh_preserves_witness_but_new_login_does_not() = runTest {
        val manager = manager()
        manager.saveSession(session(userA, jwt(userA, loginA, "one")))
        val first = manager.peekStoredLoginTicket()
        manager.saveSession(session(userA, jwt(userA, loginA, "two")))
        assertEquals(first, manager.peekStoredLoginTicket())

        manager.saveSession(session(userA, jwt(userA, loginA2)))
        assertEquals(LoginTicketSnapshot(userA, loginA2), manager.peekStoredLoginTicket())
    }

    @Test fun malformed_or_mismatched_stored_claims_cannot_name_an_account() = runTest {
        val manager = manager()
        manager.saveSession(session(userA, "not.a.jwt"))
        assertNull(manager.peekStoredLoginTicket())
        manager.saveSession(session(userA, jwt(userB, loginA)))
        assertNull(manager.peekStoredLoginTicket())
        manager.saveSession(session(userA, jwt(userA, "invalid-session-id")))
        assertNull(manager.peekStoredLoginTicket())
    }

    private fun manager(): EncryptedSessionManager =
        EncryptedSessionManager(ApplicationProvider.getApplicationContext<Context>())

    private fun session(userId: String, accessToken: String): UserSession = UserSession(
        accessToken = accessToken,
        refreshToken = "synthetic-refresh-only",
        expiresIn = 3600,
        tokenType = "bearer",
        user = UserInfo(id = userId),
    )

    private fun jwt(subject: String, sessionId: String, nonce: String = "one"): String {
        fun encode(value: String): String = Base64.getUrlEncoder().withoutPadding()
            .encodeToString(value.toByteArray(Charsets.UTF_8))
        val header = """{"alg":"HS256"}"""
        val payload = """{"sub":"$subject","session_id":"$sessionId","nonce":"$nonce"}"""
        return "${encode(header)}.${encode(payload)}.${encode("signature")}"
    }
}
