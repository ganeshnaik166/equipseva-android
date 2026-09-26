package com.equipseva.app.core.push

import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.auth.LocalSessionOwnership
import com.equipseva.app.core.data.dao.DeviceTokenDao
import com.equipseva.app.core.data.entities.DeviceTokenEntity
import com.equipseva.app.testing.FakeAuthRepository
import com.equipseva.app.testing.TestSupabaseClient
import com.equipseva.app.testing.TestSupabaseClient.importSyntheticSession
import io.github.jan.supabase.auth.Auth
import io.github.jan.supabase.auth.MemoryCodeVerifierCache
import io.github.jan.supabase.auth.MemorySessionManager
import io.github.jan.supabase.createSupabaseClient
import io.github.jan.supabase.logging.LogLevel
import io.github.jan.supabase.postgrest.Postgrest
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.client.request.HttpRequestData
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpMethod
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.async
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.withContext
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotSame
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** The cached FCM token is installation-scoped; only the departing ticket owns a revoke. */
@OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)
class DeviceTokenCaptureOwnershipTest {
    private class HoldingTokenDao : DeviceTokenDao {
        var row: DeviceTokenEntity? = DeviceTokenEntity(token = "fcm-A", registeredAt = 1L)
        var currentCalls = 0
        var entered: CompletableDeferred<Unit>? = null
        var release: CompletableDeferred<Unit>? = null
        var readFailure: Exception? = null
        var ignoreCancellation = false

        override suspend fun current(): DeviceTokenEntity? {
            currentCalls++
            entered?.complete(Unit)
            val gate = release
            if (gate != null) {
                if (ignoreCancellation) withContext(NonCancellable) { gate.await() } else gate.await()
            }
            readFailure?.let { throw it }
            return row
        }

        override suspend fun upsert(entity: DeviceTokenEntity) { row = entity }
        override suspend fun clear() { row = null }
    }

    @OptIn(io.github.jan.supabase.annotations.SupabaseInternal::class)
    private class Harness(scope: TestScope) {
        val auth = FakeAuthRepository(AuthSession.SignedIn(A, "a@test.invalid"))
        var raw = LocalSessionOwnership.Identity(A, "login-A")
        val ownership = LocalSessionOwnership(auth, { raw }, scope.backgroundScope)
        val dao = HoldingTokenDao()
        val requests = mutableListOf<HttpRequestData>()
        var deleteFailure: Exception? = null
        val client = createSupabaseClient(TestSupabaseClient.HOST, TestSupabaseClient.ANON_KEY) {
            defaultLogLevel = LogLevel.NONE
            httpEngine = MockEngine { request ->
                requests += request
                if (request.method == HttpMethod.Delete) deleteFailure?.let { throw it }
                respond("", HttpStatusCode.NoContent, headersOf(HttpHeaders.ContentType, "application/json"))
            }
            install(Auth) {
                sessionManager = MemorySessionManager()
                codeVerifierCache = MemoryCodeVerifierCache()
                autoLoadFromStorage = false
                alwaysAutoRefresh = false
                autoSaveToStorage = false
                enableLifecycleCallbacks = false
                autoSetupPlatform = false
            }
            install(Postgrest)
        }
        val registrar = DeviceTokenRegistrar(dao, client, ownership)

        suspend fun signIn(user: String, session: String) {
            raw = LocalSessionOwnership.Identity(user, session)
            client.importSyntheticSession(user, sessionId = session)
            auth.setSession(AuthSession.SignedIn(user, "$session@test.invalid"))
        }
    }

    @Test fun `fresh A ticket captures and revokes only A while retaining installation token`() = runTest {
        val h = Harness(this)
        try {
            h.signIn(A, "login-A")
            runCurrent()
            val ticket = requireNotNull(h.ownership.capture())
            val capture = h.registrar.captureRevocation(ticket)
            assertEquals(DeviceTokenRegistrar.Revocation(A, "fcm-A"), capture)
            h.registrar.revoke(capture)
            assertEquals(DeviceTokenEntity(token = "fcm-A", registeredAt = 1L), h.dao.current())
            val deletion = h.requests.single()
            assertEquals(HttpMethod.Delete, deletion.method)
            assertEquals("eq.$A", deletion.url.parameters["user_id"])
            assertEquals("eq.fcm-A", deletion.url.parameters["token"])
        } finally {
            h.client.close()
        }
    }

    @Test fun `null and stale A tickets never read B's cached token`() = runTest {
        val h = Harness(this)
        try {
            h.signIn(A, "login-A")
            runCurrent()
            val oldA = requireNotNull(h.ownership.capture())
            h.signIn(B, "login-B")
            runCurrent()
            h.dao.row = DeviceTokenEntity(token = "fcm-B", registeredAt = 2L)
            assertNull(h.registrar.captureRevocation(null))
            assertNull(h.registrar.captureRevocation(oldA))
            assertEquals("a rejected ticket must not enter the suspending DAO", 0, h.dao.currentCalls)
            assertEquals(DeviceTokenRegistrar.Revocation(B, "fcm-B"),
                h.registrar.captureRevocation(requireNotNull(h.ownership.capture())))
        } finally {
            h.client.close()
        }
    }

    @Test fun `held A token read cannot publish B after a direct account replacement`() = runTest {
        val h = Harness(this)
        try {
            h.signIn(A, "login-A")
            runCurrent()
            val oldA = requireNotNull(h.ownership.capture())
            h.dao.entered = CompletableDeferred()
            h.dao.release = CompletableDeferred()
            h.dao.ignoreCancellation = true
            val pending = async { h.registrar.captureRevocation(oldA) }
            h.dao.entered!!.await()
            h.signIn(B, "login-B")
            runCurrent()
            h.dao.row = DeviceTokenEntity(token = "fcm-B", registeredAt = 2L)
            h.dao.release!!.complete(Unit)
            assertNull("a late noncooperative read must not publish B under A", pending.await())
            assertEquals(DeviceTokenRegistrar.Revocation(B, "fcm-B"),
                h.registrar.captureRevocation(requireNotNull(h.ownership.capture())))
        } finally {
            h.dao.release?.complete(Unit)
            h.client.close()
        }
    }

    @Test fun `held A token read cannot publish same owner after a new login session`() = runTest {
        val h = Harness(this)
        try {
            h.signIn(A, "login-A")
            runCurrent()
            val oldA = requireNotNull(h.ownership.capture())
            h.dao.entered = CompletableDeferred()
            h.dao.release = CompletableDeferred()
            val pending = async { h.registrar.captureRevocation(oldA) }
            h.dao.entered!!.await()
            h.signIn(A, "new-login-A")
            runCurrent()
            h.dao.release!!.complete(Unit)
            assertNull("matching user ID must not revive the prior ticket", pending.await())
            val currentA = requireNotNull(h.ownership.capture())
            assertNotSame(oldA, currentA)
            assertEquals(DeviceTokenRegistrar.Revocation(A, "fcm-A"), h.registrar.captureRevocation(currentA))
        } finally {
            h.dao.release?.complete(Unit)
            h.client.close()
        }
    }

    @Test fun `observed A B A never revives first A ticket`() = runTest {
        val h = Harness(this)
        try {
            h.signIn(A, "login-A")
            runCurrent()
            val oldA = requireNotNull(h.ownership.capture())
            h.signIn(B, "login-B")
            runCurrent()
            h.signIn(A, "login-A")
            runCurrent()
            assertNull(h.registrar.captureRevocation(oldA))
            val freshA = requireNotNull(h.ownership.capture())
            assertNotSame(oldA, freshA)
            assertEquals(DeviceTokenRegistrar.Revocation(A, "fcm-A"), h.registrar.captureRevocation(freshA))
        } finally {
            h.client.close()
        }
    }

    @Test fun `DAO cancellation propagates instead of becoming an absent token`() = runTest {
        val h = Harness(this)
        try {
            h.signIn(A, "login-A")
            runCurrent()
            h.dao.readFailure = CancellationException("token read cancelled")
            val ticket = requireNotNull(h.ownership.capture())
            var escaped = false
            try {
                h.registrar.captureRevocation(ticket)
            } catch (cancelled: CancellationException) {
                escaped = true
                assertEquals("token read cancelled", cancelled.message)
            }
            assertTrue("caller cancellation must escape token capture", escaped)
            assertTrue(h.requests.isEmpty())
        } finally {
            h.client.close()
        }
    }

    @Test fun `remote revoke cancellation propagates instead of being swallowed by network best effort`() = runTest {
        val h = Harness(this)
        try {
            h.signIn(A, "login-A")
            runCurrent()
            val capture = h.registrar.captureRevocation(requireNotNull(h.ownership.capture()))
            assertEquals(DeviceTokenRegistrar.Revocation(A, "fcm-A"), capture)
            h.deleteFailure = CancellationException("remote revoke cancelled")
            var escaped = false
            try {
                h.registrar.revoke(capture)
            } catch (cancelled: CancellationException) {
                escaped = true
                assertEquals("remote revoke cancelled", cancelled.message)
            }
            assertTrue("network cancellation must escape revoke", escaped)
            assertEquals(HttpMethod.Delete, h.requests.single().method)
        } finally {
            h.client.close()
        }
    }

    @Test fun `empty or failed installation-token read has no remote revoke`() = runTest {
        val h = Harness(this)
        try {
            h.signIn(A, "login-A")
            runCurrent()
            val ticket = requireNotNull(h.ownership.capture())
            h.dao.row = DeviceTokenEntity(token = "", registeredAt = 1L)
            assertNull(h.registrar.captureRevocation(ticket))
            h.dao.readFailure = IllegalStateException("disk closed")
            assertNull(h.registrar.captureRevocation(ticket))
            assertFalse(h.requests.any { it.method == HttpMethod.Delete })
        } finally {
            h.client.close()
        }
    }

    private companion object {
        const val A = "11111111-1111-4111-8111-111111111111"
        const val B = "22222222-2222-4222-8222-222222222222"
    }
}
