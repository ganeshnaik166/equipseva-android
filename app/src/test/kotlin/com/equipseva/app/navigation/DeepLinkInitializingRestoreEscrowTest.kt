package com.equipseva.app.navigation

import android.app.Application
import android.content.Intent
import androidx.lifecycle.viewModelScope
import androidx.test.core.app.ApplicationProvider
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.auth.EncryptedSessionManager
import com.equipseva.app.core.auth.LoginTicketSnapshot
import com.equipseva.app.core.auth.LoginTicketSource
import com.equipseva.app.core.auth.parseLoginTicket
import com.equipseva.app.core.data.engineers.Engineer
import com.equipseva.app.core.data.engineers.EngineerRepository
import com.equipseva.app.core.data.prefs.UserPrefs
import com.equipseva.app.testing.FakeAuthRepository
import io.github.jan.supabase.auth.user.UserInfo
import io.github.jan.supabase.auth.user.UserSession
import io.mockk.coEvery
import io.mockk.every
import io.mockk.mockk
import java.util.Base64
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import kotlinx.coroutines.withTimeoutOrNull
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Synthetic A3-02 restoration contract. The store contains a session for A while the SDK ticket
 * is still null (Initializing). A stored ticket is only an ingress witness: navigation must wait
 * for the same authenticated SDK ticket and observed login. The exported push recipient is not
 * authorization for the destination object.
 *
 * Robolectric uses EncryptedSessionManager's volatile fallback because it has no Android
 * Keystore. These tests exercise the manager's stored-session API and the router/host race, not
 * the device encryption implementation. The current router does not read a persisted witness,
 * so the positive restoration assertions intentionally fail until that production seam exists.
 */
@OptIn(ExperimentalCoroutinesApi::class)
@RunWith(RobolectricTestRunner::class)
@Config(application = Application::class, sdk = [35])
class DeepLinkInitializingRestoreEscrowTest {
    private val userA = "11111111-1111-4111-8111-111111111111"
    private val userB = "22222222-2222-4222-8222-222222222222"
    private val ticketA = LoginTicketSnapshot(userA, "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
    private val ticketA2 = LoginTicketSnapshot(userA, "cccccccc-cccc-4ccc-8ccc-cccccccccccc")
    private val ticketB = LoginTicketSnapshot(userB, "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")
    private val accountA = AuthSession.SignedIn(userA, "a@example.test")
    private val accountB = AuthSession.SignedIn(userB, "b@example.test")
    private val routeOne = Routes.repairJobDetailRoute("RPR-00027")
    private val routeTwo = Routes.repairJobDetailRoute("RPR-00028")

    private lateinit var store: EncryptedSessionManager
    private val hosts = mutableListOf<DeepLinkHost>()
    private val registrations = mutableListOf<AutoCloseable>()

    @Before fun setUp() = runTest {
        Dispatchers.setMain(StandardTestDispatcher())
        store = EncryptedSessionManager(ApplicationProvider.getApplicationContext())
        store.deleteSession()
    }

    @After fun tearDown() = runTest {
        registrations.forEach(AutoCloseable::close)
        hosts.forEach { it.viewModelScope.cancel() }
        store.deleteSession()
        Dispatchers.resetMain()
    }

    private inner class Harness {
        var sdkTicket: LoginTicketSnapshot? = null
        // The production ingress-only witness seam can be stubbed from storedTicketOrNull() here.
        // currentTicket() must remain SDK-only, including throughout Initializing.
        val source = mockk<LoginTicketSource>(relaxed = true) {
            every { currentTicket() } answers { sdkTicket }
        }
        val router = DeepLinkRouter(source)
    }

    @Test fun cold_push_waits_for_the_same_restored_SDK_ticket_and_delivers_once() = runTest {
        saveStoredSession(ticketA)
        assertEquals(ticketA, storedTicketOrNull())
        val h = Harness()
        val owner = DeepLinkRouter.LaunchOwner()
        h.router.beginActivity(owner)
        h.router.dispatchStartup(push(routeOne), owner)

        val auth = FakeAuthRepository(AuthSession.Unknown)
        val host = host(h, auth)
        register(host, owner)
        advanceUntilIdle()
        assertNull("Initializing must not navigate from a stored JWT", host.nextRouteOrNull())

        h.sdkTicket = ticketA
        auth.setSession(accountA)
        advanceUntilIdle()
        assertEquals(routeOne, host.nextRouteOrNull())
        assertNull("One tap must navigate only once", host.nextRouteOrNull())
    }

    @Test fun warm_push_with_a_mounted_host_waits_for_the_same_SDK_restore() = runTest {
        saveStoredSession(ticketA)
        assertEquals(ticketA, storedTicketOrNull())
        val h = Harness()
        val owner = DeepLinkRouter.LaunchOwner()
        h.router.beginActivity(owner)
        val auth = FakeAuthRepository(AuthSession.Unknown)
        val host = host(h, auth)
        register(host, owner)
        advanceUntilIdle()

        h.router.dispatch(push(routeOne), owner)
        assertNull("Warm tap navigated while SDK was Initializing", host.nextRouteOrNull())
        h.sdkTicket = ticketA
        auth.setSession(accountA)
        advanceUntilIdle()
        assertEquals(routeOne, host.nextRouteOrNull())
        assertNull(host.nextRouteOrNull())
    }

    @Test fun observed_login_alone_cannot_release_a_tap_before_the_SDK_ticket_exists() = runTest {
        saveStoredSession(ticketA)
        val h = Harness()
        val owner = DeepLinkRouter.LaunchOwner()
        h.router.beginActivity(owner)
        h.router.dispatchStartup(push(routeOne), owner)
        val auth = FakeAuthRepository(AuthSession.Unknown)
        val host = host(h, auth)
        register(host, owner)
        advanceUntilIdle()

        auth.setSession(accountA)
        advanceUntilIdle()
        assertNull("An observed user ID alone released the stored tap", host.nextRouteOrNull())
        h.sdkTicket = ticketA
        // Re-registration must be able to claim a still-pending tap; a failed claim while the
        // SDK was null must not consume it. The normal SDK status path may also release it.
        register(host, owner)
        advanceUntilIdle()
        assertEquals(routeOne, host.nextRouteOrNull())
    }

    @Test fun different_account_restore_retires_A_even_if_A_appears_later() = runTest {
        saveStoredSession(ticketA)
        assertEquals(ticketA, storedTicketOrNull())
        val h = Harness()
        val owner = DeepLinkRouter.LaunchOwner()
        h.router.beginActivity(owner)
        h.router.dispatchStartup(push(routeOne), owner)
        val auth = FakeAuthRepository(AuthSession.Unknown)
        val host = host(h, auth)
        register(host, owner)
        advanceUntilIdle()

        h.sdkTicket = ticketB
        auth.setSession(accountB)
        advanceUntilIdle()
        assertNull("B inherited A's stored push", host.nextRouteOrNull())
        h.sdkTicket = ticketA
        auth.setSession(accountA)
        advanceUntilIdle()
        assertNull("A recovered a tap retired by the B login boundary", host.nextRouteOrNull())
    }

    @Test fun same_user_new_session_ID_cannot_claim_the_stored_A_tap() = runTest {
        saveStoredSession(ticketA)
        val h = Harness()
        val owner = DeepLinkRouter.LaunchOwner()
        h.router.beginActivity(owner)
        h.router.dispatchStartup(push(routeOne), owner)
        val auth = FakeAuthRepository(AuthSession.Unknown)
        val host = host(h, auth)
        register(host, owner)
        advanceUntilIdle()

        h.sdkTicket = ticketA2
        auth.setSession(accountA)
        advanceUntilIdle()
        assertNull("A's new login claimed the older session's tap", host.nextRouteOrNull())
    }

    @Test fun signed_out_restoration_retires_the_tap_even_if_A_later_returns() = runTest {
        saveStoredSession(ticketA)
        val h = Harness()
        val owner = DeepLinkRouter.LaunchOwner()
        h.router.beginActivity(owner)
        h.router.dispatchStartup(push(routeOne), owner)
        val auth = FakeAuthRepository(AuthSession.Unknown)
        val host = host(h, auth)
        register(host, owner)
        advanceUntilIdle()

        auth.setSession(AuthSession.SignedOut)
        advanceUntilIdle()
        h.sdkTicket = ticketA
        auth.setSession(accountA)
        advanceUntilIdle()
        assertNull("A later login inherited a tap from a signed-out restore", host.nextRouteOrNull())
    }

    @Test fun no_stored_session_does_not_escrow_a_signed_out_tap() = runTest {
        assertNull(storedTicketOrNull())
        val h = Harness()
        val owner = DeepLinkRouter.LaunchOwner()
        h.router.beginActivity(owner)
        h.router.dispatchStartup(push(routeOne), owner)
        val auth = FakeAuthRepository(AuthSession.SignedOut)
        val host = host(h, auth)
        register(host, owner)
        advanceUntilIdle()

        h.sdkTicket = ticketA
        auth.setSession(accountA)
        advanceUntilIdle()
        assertNull("A later sign-in claimed an unowned push", host.nextRouteOrNull())
        h.router.dispatch(push(routeTwo), owner)
        assertEquals("Fresh authenticated taps must still work", routeTwo, host.nextRouteOrNull())
    }

    @Test fun invalid_stored_ticket_does_not_escrow_a_later_matching_login() = runTest {
        store.saveSession(session(userA, "not-a-jwt"))
        assertNull(storedTicketOrNull())
        val h = Harness()
        val owner = DeepLinkRouter.LaunchOwner()
        h.router.beginActivity(owner)
        h.router.dispatchStartup(push(routeOne), owner)
        val auth = FakeAuthRepository(AuthSession.Unknown)
        val host = host(h, auth)
        register(host, owner)
        advanceUntilIdle()

        h.sdkTicket = ticketA
        auth.setSession(accountA)
        advanceUntilIdle()
        assertNull("Malformed stored identity claimed a later login", host.nextRouteOrNull())
    }

    @Test fun token_refresh_with_the_same_session_ID_preserves_the_escrow() = runTest {
        saveStoredSession(ticketA, nonce = "before-refresh")
        val firstToken = store.loadSession().accessToken
        val h = Harness()
        val owner = DeepLinkRouter.LaunchOwner()
        h.router.beginActivity(owner)
        h.router.dispatchStartup(push(routeOne), owner)

        saveStoredSession(ticketA, nonce = "after-refresh")
        assertFalse(firstToken == store.loadSession().accessToken)
        assertEquals(ticketA, storedTicketOrNull())
        h.sdkTicket = ticketA
        val host = host(h, FakeAuthRepository(accountA))
        advanceUntilIdle()
        register(host, owner)
        assertEquals("Token refresh changed the login owner", routeOne, host.nextRouteOrNull())
        assertNull(host.nextRouteOrNull())
    }

    @Test fun destroying_the_Activity_owner_retires_its_restoring_tap() = runTest {
        saveStoredSession(ticketA)
        val h = Harness()
        val oldOwner = DeepLinkRouter.LaunchOwner()
        val newOwner = DeepLinkRouter.LaunchOwner()
        h.router.beginActivity(oldOwner)
        h.router.dispatchStartup(push(routeOne), oldOwner)
        h.router.endActivity(oldOwner)

        h.sdkTicket = ticketA
        h.router.beginActivity(newOwner)
        val host = host(h, FakeAuthRepository(accountA))
        advanceUntilIdle()
        register(host, newOwner)
        assertNull("A destroyed Activity's tap reached its successor", host.nextRouteOrNull())
        h.router.dispatch(push(routeTwo), newOwner)
        assertEquals(routeTwo, host.nextRouteOrNull())
    }

    @Test fun a_newer_tap_replaces_the_older_restoring_tap() = runTest {
        saveStoredSession(ticketA)
        val h = Harness()
        val owner = DeepLinkRouter.LaunchOwner()
        h.router.beginActivity(owner)
        h.router.dispatchStartup(push(routeOne), owner)
        h.router.dispatchStartup(push(routeTwo), owner)

        h.sdkTicket = ticketA
        val host = host(h, FakeAuthRepository(accountA))
        advanceUntilIdle()
        register(host, owner)
        assertEquals("Older tap survived replacement", routeTwo, host.nextRouteOrNull())
        assertNull("Both taps navigated", host.nextRouteOrNull())
    }

    private suspend fun saveStoredSession(ticket: LoginTicketSnapshot, nonce: String = "initial") {
        store.saveSession(session(ticket.userId, jwt(ticket, nonce)))
    }

    private suspend fun storedTicketOrNull(): LoginTicketSnapshot? =
        store.loadSessionOrNull()?.let { parseLoginTicket(it.user?.id, it.accessToken) }

    private fun session(userId: String, accessToken: String) = UserSession(
        accessToken = accessToken,
        refreshToken = "synthetic-refresh-token",
        expiresIn = 3600,
        tokenType = "bearer",
        user = UserInfo(aud = "authenticated", id = userId),
    )

    private fun jwt(ticket: LoginTicketSnapshot, nonce: String): String {
        fun encoded(value: String): String = Base64.getUrlEncoder().withoutPadding()
            .encodeToString(value.toByteArray(Charsets.UTF_8))
        val header = """{"alg":"HS256","typ":"JWT"}"""
        val payload = """{"sub":"${ticket.userId}","session_id":"${ticket.sessionId}","nonce":"$nonce"}"""
        return "${encoded(header)}.${encoded(payload)}.${encoded("synthetic-signature")}"
    }

    private fun push(route: String): Intent = Intent()
        .putExtra(DeepLinkRouter.EXTRA_ROUTE, route)
        .putExtra(DeepLinkRouter.EXTRA_RECIPIENT_USER_ID, userA)

    private fun host(h: Harness, auth: FakeAuthRepository): DeepLinkHost {
        val prefs = mockk<UserPrefs> {
            every { activeRole } returns flowOf(null)
            every { lastScreen } returns flowOf(null)
        }
        val engineers = mockk<EngineerRepository> {
            coEvery { fetchByUserId(any()) } returns Result.success<Engineer?>(null)
        }
        return DeepLinkHost(h.router, prefs, auth, engineers, h.source).also { hosts += it }
    }

    private fun register(host: DeepLinkHost, owner: DeepLinkRouter.LaunchOwner) {
        registrations += host.registerRouterSink(owner)
    }

    private suspend fun DeepLinkHost.nextRouteOrNull(): String? = withTimeoutOrNull(50) {
        (events.first() as DeepLinkHost.VerifiedEvent.OpenRoute).route
    }
}
