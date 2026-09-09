package com.equipseva.app.core.data.repair

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.testing.FakeAuthRepository
import com.equipseva.app.testing.TestSupabaseClient
import com.equipseva.app.testing.TestSupabaseClient.importSyntheticSession
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.status.SessionSource
import io.github.jan.supabase.auth.user.UserInfo
import io.github.jan.supabase.auth.user.UserSession
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.io.File

/**
 * INT-02 (claudedev-help M1 frozen slice) — the PRODUCTION `@Inject`
 * constructor of [RequestServiceDraftStore] against a REAL supabase-kt client.
 *
 * Why this exists: every other draft-store test injects a fake identity
 * lambda. The lambda production actually runs
 * (`supabase.auth.currentSessionOrNull()` → `user.id` →
 * [RequestServiceDraftStore.identityFromAccessToken] → fallback
 * `Identity(ownerId, null)`) had never executed in a test, and under Hilt the
 * relaxed `SupabaseClient` mock yields a blank user id, so a Hilt-injected
 * store never issues a lease and any "denied" assertion would pass for the
 * wrong reason. Here the client is the real Auth plugin
 * ([TestSupabaseClient]) holding a runtime-built session whose access token
 * carries the claims GoTrue would put there.
 *
 * Why ONE test method: the production constructor binds the store to the
 * process-wide `preferencesDataStore("request_service_draft")` delegate,
 * which is a single DataStore per JVM pinned to the first Context's
 * `filesDir`. Robolectric hands every test method a fresh `filesDir`, so a
 * second method would read a file the singleton no longer writes to. All
 * phases therefore share one Context and one delegate instance; each phase
 * is labelled in its assertion messages.
 *
 * Presence before absence: phase 1 proves the REAL preferences file receives
 * the owner id and the draft text before any phase asserts that a draft is
 * missing.
 *
 * NOT proven here: that GoTrue really issues a `session_id` claim (production
 * tokens are assumed to; the store degrades to "form usable, no persistence"
 * otherwise), the Hilt graph, Compose, or token refresh timing.
 */
@RunWith(RobolectricTestRunner::class)
@Config(application = android.app.Application::class, manifest = Config.NONE, sdk = [34])
@OptIn(ExperimentalCoroutinesApi::class)
class RequestServiceDraftIdentityIntegrationTest {

    private val context: Context = ApplicationProvider.getApplicationContext()
    private lateinit var harness: TestSupabaseClient.Harness
    private lateinit var auth: FakeAuthRepository

    /** Where the production delegate writes: `filesDir/datastore/<name>.preferences_pb`. */
    private val draftFile: File
        get() = File(context.filesDir, "datastore/request_service_draft.preferences_pb")

    @Before fun setUp() {
        // The production scope is Dispatchers.Main.immediate; Main must be the
        // test dispatcher BEFORE the store is constructed.
        Dispatchers.setMain(StandardTestDispatcher())
        harness = TestSupabaseClient.build()
        auth = FakeAuthRepository()
    }

    @After fun tearDown() {
        runBlocking { harness.close() }
        Dispatchers.resetMain()
    }

    private fun fileText(): String =
        if (draftFile.exists()) draftFile.readBytes().toString(Charsets.UTF_8) else ""

    @Test fun `production identity path keys the lease on the JWT session claim and disables persistence without it`() = runTest {
        val store = RequestServiceDraftStore(context, auth, harness.client)

        // ---- Phase 1 (FLOOR): valid token with sub == user id and a session_id.
        harness.client.importSyntheticSession(UID_A, sessionId = "sess-A")
        auth.setSession(AuthSession.SignedIn(UID_A, "a@test.invalid"))
        runCurrent()
        val leaseA = store.activeSession.value
        assertNotNull("phase 1: a lease must be issued for a valid token", leaseA)
        assertEquals(
            "phase 1: identity must come from the JWT sub + session_id claims",
            RequestServiceDraftStore.Identity(UID_A, "sess-A"),
            leaseA!!.identity,
        )
        assertTrue("phase 1: the lease must be current", store.isCurrent(leaseA))

        // Presence proof on the REAL file: the production delegate wrote the
        // owner id and the draft text.
        store.saveDraft(leaseA, sampleRequestDraft(PHASE_ONE_ISSUE))
        assertTrue("phase 1: the production preferences file must exist at ${draftFile.path}", draftFile.exists())
        val afterSave = fileText()
        assertTrue("phase 1: file must contain the owner id", afterSave.contains(UID_A))
        assertTrue("phase 1: file must contain the draft text", afterSave.contains(PHASE_ONE_ISSUE))
        assertEquals("phase 1: the store must read the draft back", PHASE_ONE_ISSUE, store.loadDraft(leaseA)?.issue)

        // ---- Phase 2: token whose sub disagrees with the user record → parser
        // returns null → the constructor's fallback Identity(uid, null).
        store.fenceAndClearForSignOut()
        auth.setSession(AuthSession.SignedOut)
        runCurrent()
        assertNull("phase 2: sign-out must revoke the lease", store.activeSession.value)
        assertFalse("phase 2: the fence must have cleared A's draft from disk", fileText().contains(PHASE_ONE_ISSUE))

        harness.client.importSyntheticSession(UID_A, sessionId = "sess-B", tokenSub = UID_OTHER)
        auth.setSession(AuthSession.SignedIn(UID_A, "a2@test.invalid"))
        runCurrent()
        val leaseNoSession = store.activeSession.value
        assertNotNull("phase 2: a lease is still issued (form stays usable)", leaseNoSession)
        assertEquals(
            "phase 2: sub mismatch must fall back to Identity(uid, null)",
            RequestServiceDraftStore.Identity(UID_A, null),
            leaseNoSession!!.identity,
        )
        store.saveDraft(leaseNoSession, sampleRequestDraft(PHASE_TWO_ISSUE))
        assertFalse("phase 2: persistence must be disabled — file must not contain the text", fileText().contains(PHASE_TWO_ISSUE))
        assertNull("phase 2: nothing to load", store.loadDraft(leaseNoSession))

        // ---- Phase 3: token WITHOUT a session_id claim → same fallback via a
        // different parser reason; persistence stays disabled.
        auth.setSession(AuthSession.SignedOut)
        runCurrent()
        harness.client.importSyntheticSession(UID_A, sessionId = null)
        auth.setSession(AuthSession.SignedIn(UID_A, "a3@test.invalid"))
        runCurrent()
        val leaseNoClaim = store.activeSession.value
        assertNotNull("phase 3: a lease is issued for a token without session_id", leaseNoClaim)
        assertEquals(
            "phase 3: missing session_id must fall back to Identity(uid, null)",
            RequestServiceDraftStore.Identity(UID_A, null),
            leaseNoClaim!!.identity,
        )
        store.saveDraft(leaseNoClaim, sampleRequestDraft(PHASE_THREE_ISSUE))
        assertFalse("phase 3: persistence must be disabled", fileText().contains(PHASE_THREE_ISSUE))

        // ---- Phase 4: a fresh valid session for the same owner persists again
        // (the fallback was the token's fault, not the store's).
        auth.setSession(AuthSession.SignedOut)
        runCurrent()
        harness.client.importSyntheticSession(UID_A, sessionId = "sess-D")
        auth.setSession(AuthSession.SignedIn(UID_A, "a4@test.invalid"))
        runCurrent()
        val leaseD = store.activeSession.value
        assertEquals(
            "phase 4: a valid token re-enables a session-keyed identity",
            RequestServiceDraftStore.Identity(UID_A, "sess-D"),
            leaseD?.identity,
        )
        store.saveDraft(leaseD!!, sampleRequestDraft(PHASE_FOUR_ISSUE))
        assertTrue("phase 4: persistence resumes — file must contain the new text", fileText().contains(PHASE_FOUR_ISSUE))
        assertFalse("phase 4: earlier no-persistence texts never reached disk", fileText().contains(PHASE_TWO_ISSUE) || fileText().contains(PHASE_THREE_ISSUE))

        // ---- Phase 5: blank user id on the SDK session → no identity → no lease,
        // while the SignedIn emission provably reached the store.
        store.fenceAndClearForSignOut()
        auth.setSession(AuthSession.SignedOut)
        runCurrent()
        harness.client.auth.importSession(
            UserSession(
                accessToken = TestSupabaseClient.jwt(TestSupabaseClient.claims(UID_A, "sess-E")),
                refreshToken = "refresh-placeholder",
                expiresIn = 3600,
                tokenType = "bearer",
                user = UserInfo(aud = "authenticated", id = ""),
            ),
            autoRefresh = false,
            source = SessionSource.External,
        )
        auth.setSession(AuthSession.SignedIn(UID_A, "a5@test.invalid"))
        runCurrent()
        assertEquals(
            "phase 5: the SignedIn emission was delivered",
            AuthSession.SignedIn(UID_A, "a5@test.invalid"),
            auth.sessionState.first(),
        )
        assertNull("phase 5: a blank SDK user id must never yield a lease", store.activeSession.value)
        assertFalse("phase 5: the fence removed phase 4's draft", fileText().contains(PHASE_FOUR_ISSUE))

        store.fenceAndClearForSignOut()
    }

    private companion object {
        const val UID_A = "10000000-0000-0000-0000-00000000000a"
        const val UID_OTHER = "10000000-0000-0000-0000-00000000000b"
        const val PHASE_ONE_ISSUE = "identity phase one issue text"
        const val PHASE_TWO_ISSUE = "identity phase two issue text"
        const val PHASE_THREE_ISSUE = "identity phase three issue text"
        const val PHASE_FOUR_ISSUE = "identity phase four issue text"
    }
}
