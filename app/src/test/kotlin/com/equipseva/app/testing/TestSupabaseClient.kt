package com.equipseva.app.testing

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.Auth
import io.github.jan.supabase.auth.MemoryCodeVerifierCache
import io.github.jan.supabase.auth.MemorySessionManager
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.status.SessionSource
import io.github.jan.supabase.auth.user.UserInfo
import io.github.jan.supabase.auth.user.UserSession
import io.github.jan.supabase.createSupabaseClient
import io.github.jan.supabase.logging.LogLevel
import io.github.jan.supabase.postgrest.Postgrest
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.client.engine.mock.toByteArray
import io.ktor.client.request.HttpRequestData
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import java.util.Base64

/**
 * A REAL supabase-kt 3.6.0 client (Auth + Postgrest plugins on the production
 * code path) whose only network is ktor's [MockEngine]. Built for the
 * claudedev-help M1 integration tests so the handler-to-wire contract
 * (URL path, bearer token, JSON body) and the production `@Inject` identity
 * path of [com.equipseva.app.core.data.repair.RequestServiceDraftStore] are
 * exercised against the SDK itself, not a relaxed mock that yields a blank
 * user id (see [TestSupabaseModule] for why that would prove nothing).
 *
 * Why each Auth setting is what it is (verified against the 3.6.0 bytecode):
 *  - `sessionManager` / `codeVerifierCache`: the defaults resolve an Android
 *    `Settings()` factory that needs an application Context registered by the
 *    SDK's androidx.startup initializer — absent in unit tests.
 *  - `enableLifecycleCallbacks = false` / `autoSetupPlatform = false`: the
 *    default reaches `ProcessLifecycleOwner` + `Dispatchers.Main`.
 *  - `autoLoadFromStorage` / `alwaysAutoRefresh` / `autoSaveToStorage = false`:
 *    no background coroutines; the imported session is the whole truth.
 *  - `defaultLogLevel = NONE`: Kermit's Android writer calls `android.util.Log`,
 *    which throws on the plain JVM.
 *  - No `accessToken` provider: `AuthImpl` refuses to coexist with one.
 *
 * Tokens are assembled at runtime from a JSON claims string — never a literal
 * `eyJ…` token, so the repository's secret scan stays quiet.
 */
object TestSupabaseClient {

    const val HOST = "unit.supabase.test"
    const val ANON_KEY = "anon-test-key"
    const val DEFAULT_SESSION_ID = "sess-0001"

    /** One captured HTTP request with its body decoded as UTF-8. */
    class Recorded(val request: HttpRequestData, val body: String)

    /**
     * The built client plus the recorder. Set [answer] per test to control what
     * the fake PostgREST returns; every request is appended to [recorded].
     */
    class Harness internal constructor(
        val client: SupabaseClient,
        val recorded: MutableList<Recorded>,
        private val answerRef: Array<(HttpRequestData) -> Pair<HttpStatusCode, String>>,
    ) {
        var answer: (HttpRequestData) -> Pair<HttpStatusCode, String>
            get() = answerRef[0]
            set(value) { answerRef[0] = value }

        suspend fun close() = client.close()
    }

    /**
     * Builds the harness. [answer] decides status + body for each request;
     * the default answers a quoted uuid the way PostgREST returns a
     * uuid-valued RPC. `httpEngine` is marked internal by the SDK; the
     * production module opts in the same way (SupabaseModule).
     */
    @OptIn(io.github.jan.supabase.annotations.SupabaseInternal::class)
    fun build(
        answer: (HttpRequestData) -> Pair<HttpStatusCode, String> = {
            HttpStatusCode.OK to "\"9b0c0d3e-0000-4000-8000-000000000001\""
        },
    ): Harness {
        val recorded = mutableListOf<Recorded>()
        val answerRef = arrayOf(answer)
        val client = createSupabaseClient(supabaseUrl = HOST, supabaseKey = ANON_KEY) {
            defaultLogLevel = LogLevel.NONE
            httpEngine = MockEngine { request ->
                val body = request.body.toByteArray().decodeToString()
                recorded += Recorded(request, body)
                val (status, responseBody) = answerRef[0](request)
                respond(responseBody, status, headersOf(HttpHeaders.ContentType, "application/json"))
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
        return Harness(client, recorded, answerRef)
    }

    /**
     * `header.payload.signature` with a base64url (unpadded) JSON payload —
     * exactly the shape `RequestServiceDraftStore.identityFromAccessToken`
     * parses. The header and signature segments are inert placeholders.
     */
    fun jwt(claimsJson: String): String =
        "hdr." + Base64.getUrlEncoder().withoutPadding().encodeToString(claimsJson.toByteArray(Charsets.UTF_8)) + ".sig"

    /** Claims for a GoTrue-shaped access token; pass `sessionId = null` to omit the claim. */
    fun claims(sub: String, sessionId: String? = DEFAULT_SESSION_ID): String =
        if (sessionId == null) {
            """{"sub":"$sub","aud":"authenticated","role":"authenticated"}"""
        } else {
            """{"sub":"$sub","aud":"authenticated","role":"authenticated","session_id":"$sessionId"}"""
        }

    /**
     * Imports a session for [userId]. The token's `sub` defaults to the same
     * id; pass [tokenSub] to model a token whose subject disagrees with the
     * user record, and `sessionId = null` for a token without `session_id`.
     * No HTTP call is made (unlike `importAuthToken(retrieveUser = true)`).
     */
    suspend fun SupabaseClient.importSyntheticSession(
        userId: String,
        sessionId: String? = DEFAULT_SESSION_ID,
        tokenSub: String = userId,
    ): String {
        val token = jwt(claims(tokenSub, sessionId))
        auth.importSession(
            UserSession(
                accessToken = token,
                refreshToken = "refresh-placeholder",
                expiresIn = 3600,
                tokenType = "bearer",
                user = UserInfo(aud = "authenticated", id = userId),
            ),
            autoRefresh = false,
            source = SessionSource.External,
        )
        return token
    }
}
