package com.equipseva.app.core.push

import com.equipseva.app.core.data.dao.DeviceTokenDao
import com.equipseva.app.core.data.entities.DeviceTokenEntity
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
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Deferred
import kotlinx.coroutines.async
import kotlinx.coroutines.cancelAndJoin
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Real registrar and SDK; only HTTP and Room's singleton-row storage are synthetic. */
class DeviceTokenRevocationBoundaryRegressionTest {
    private class MemoryTokenDao : DeviceTokenDao {
        var row: DeviceTokenEntity? = null
        override suspend fun current(): DeviceTokenEntity? = row
        override suspend fun upsert(entity: DeviceTokenEntity) { row = entity }
        override suspend fun clear() { row = null }
    }

    @OptIn(io.github.jan.supabase.annotations.SupabaseInternal::class)
    private class Harness(private val deletionStatus: HttpStatusCode = HttpStatusCode.NoContent) {
        val dao = MemoryTokenDao()
        val deleteEntered = CompletableDeferred<Unit>()
        val releaseDelete = CompletableDeferred<Unit>()
        val requests = mutableListOf<HttpRequestData>()
        val client = createSupabaseClient(TestSupabaseClient.HOST, TestSupabaseClient.ANON_KEY) {
            defaultLogLevel = LogLevel.NONE
            httpEngine = MockEngine { request ->
                requests += request
                if (request.method == HttpMethod.Delete && request.url.parameters["user_id"] == "eq.$A") {
                    deleteEntered.complete(Unit)
                    releaseDelete.await()
                    respond(
                        if (deletionStatus == HttpStatusCode.NoContent) "" else """{"message":"denied","code":"42501"}""",
                        deletionStatus,
                        headersOf(HttpHeaders.ContentType, "application/json"),
                    )
                } else {
                    respond("", HttpStatusCode.NoContent, headersOf(HttpHeaders.ContentType, "application/json"))
                }
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
        val registrar = DeviceTokenRegistrar(dao, client)
    }

    @Test fun `late A revoke cannot erase B's new local token registration`() = runTest {
        preserveReplacementRegistration("fcm-B", HttpStatusCode.NoContent)
    }

    @Test fun `same physical FCM token registered by B still survives A's delayed revoke`() = runTest {
        preserveReplacementRegistration("fcm-A", HttpStatusCode.NoContent)
    }

    @Test fun `failed late A revoke cannot erase B's local token registration`() = runTest {
        preserveReplacementRegistration("fcm-B", HttpStatusCode.Forbidden)
    }

    private suspend fun TestScope.preserveReplacementRegistration(newToken: String, status: HttpStatusCode) {
        val h = Harness(status)
        var pending: Deferred<Unit>? = null
        try {
            h.client.importSyntheticSession(A, sessionId = "login-A")
            h.dao.upsert(DeviceTokenEntity(token = "fcm-A", registeredAt = 1L))
            val captured = h.registrar.captureRevocation()
            assertEquals(DeviceTokenRegistrar.Revocation(A, "fcm-A"), captured)
            pending = async { h.registrar.revoke(captured) }
            h.deleteEntered.await()

            h.client.importSyntheticSession(B, sessionId = "login-B")
            h.registrar.register(newToken)
            val bRegistration = h.dao.current()
            assertEquals("fresh B registration is the positive control", newToken, bRegistration?.token)
            assertTrue("B registered remotely before A was released", h.requests.any { it.method == HttpMethod.Post })

            h.releaseDelete.complete(Unit)
            pending.await()
            assertEquals("A must not remove B's newer local registration", bRegistration, h.dao.current())
            assertEquals(
                "B's future sign-out must still be able to revoke its token",
                DeviceTokenRegistrar.Revocation(B, newToken),
                h.registrar.captureRevocation(),
            )
        } finally {
            h.releaseDelete.complete(Unit)
            pending?.cancelAndJoin()
            h.client.close()
        }
    }

    // Explicit cache policy change: this row describes the installation, not
    // an authenticated account. Firebase retains the underlying token too.
    @Test fun `ordinary revoke targets the captured remote owner and retains the installation cache`() = runTest {
        val h = Harness()
        try {
            h.client.importSyntheticSession(A)
            h.dao.upsert(DeviceTokenEntity(token = "fcm-A", registeredAt = 1L))
            val capture = h.registrar.captureRevocation()
            h.releaseDelete.complete(Unit)
            h.registrar.revoke(capture)
            assertEquals(DeviceTokenEntity(token = "fcm-A", registeredAt = 1L), h.dao.current())
            val deletion = h.requests.single()
            assertEquals(HttpMethod.Delete, deletion.method)
            assertEquals("eq.$A", deletion.url.parameters["user_id"])
            assertEquals("eq.fcm-A", deletion.url.parameters["token"])
        } finally {
            h.releaseDelete.complete(Unit)
            h.client.close()
        }
    }

    @Test fun `signed out capture cannot use a retained installation token to revoke an account`() = runTest {
        val h = Harness()
        try {
            val cached = DeviceTokenEntity(token = "fcm-installation", registeredAt = 2L)
            h.dao.upsert(cached)
            assertNull(h.registrar.captureRevocation())
            h.registrar.revoke(null)
            assertTrue(h.requests.isEmpty())
            assertEquals(cached, h.dao.current())
        } finally {
            h.releaseDelete.complete(Unit)
            h.client.close()
        }
    }

    private companion object {
        const val A = "11111111-1111-4111-8111-111111111111"
        const val B = "22222222-2222-4222-8222-222222222222"
    }
}
