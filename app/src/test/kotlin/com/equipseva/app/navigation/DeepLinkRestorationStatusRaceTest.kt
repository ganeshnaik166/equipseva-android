package com.equipseva.app.navigation

import android.app.Application
import android.content.Intent
import android.net.Uri
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.auth.LoginTicketSnapshot
import com.equipseva.app.core.auth.LoginTicketSource
import com.equipseva.app.core.data.engineers.Engineer
import com.equipseva.app.core.data.engineers.EngineerRepository
import com.equipseva.app.core.data.prefs.UserPrefs
import com.equipseva.app.testing.FakeAuthRepository
import io.mockk.coEvery
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import kotlinx.coroutines.withTimeoutOrNull
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Synthetic SDK status edges around A3's persisted-ticket witness. The witness may hold a tap
 * only during Initializing; delivery still requires the exact authenticated SDK ticket. The fake
 * provisional read models LoginTicketSource's second status check after it reads encrypted storage.
 */
@OptIn(ExperimentalCoroutinesApi::class)
@RunWith(RobolectricTestRunner::class)
@Config(application = Application::class, sdk = [35])
class DeepLinkRestorationStatusRaceTest {
    private val userA = "11111111-1111-4111-8111-111111111111"
    private val userB = "22222222-2222-4222-8222-222222222222"
    private val ticketA = LoginTicketSnapshot(userA, "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
    private val ticketA2 = LoginTicketSnapshot(userA, "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")
    private val route = Routes.repairJobDetailRoute("RPR-00027")
    private val hosts = mutableListOf<DeepLinkHost>()
    private val registrations = mutableListOf<AutoCloseable>()

    private enum class SdkStatus { Initializing, Authenticated, NotAuthenticated, RefreshFailure }

    @Before fun setUp() = Dispatchers.setMain(StandardTestDispatcher())

    @After fun tearDown() {
        registrations.forEach(AutoCloseable::close)
        hosts.forEach { it.viewModelScope.cancel() }
        Dispatchers.resetMain()
    }

    private inner class Harness {
        var status = SdkStatus.Initializing
        var sdkTicket: LoginTicketSnapshot? = null
        var storedWitness: LoginTicketSnapshot? = ticketA
        var onCurrentRead: (() -> Unit)? = null
        var onProvisionalRead: (() -> Unit)? = null
        var provisionalReads = 0

        val source = mockk<LoginTicketSource> {
            every { currentTicket() } answers {
                val snapshot = sdkTicket.takeIf { status == SdkStatus.Authenticated }
                val transition = onCurrentRead
                onCurrentRead = null
                transition?.invoke()
                snapshot
            }
            every { provisionalStoredTicketDuringInitializing() } answers {
                provisionalReads++
                val witness = storedWitness.takeIf { status == SdkStatus.Initializing }
                val transition = onProvisionalRead
                onProvisionalRead = null
                transition?.invoke()
                witness.takeIf { status == SdkStatus.Initializing }
            }
        }
        val router = DeepLinkRouter(source)

        fun finishRestore() {
            status = SdkStatus.Authenticated
            sdkTicket = ticketA
        }
    }

    @Test fun push_restoration_completing_inside_witness_read_still_delivers_once() = runTest {
        val h = Harness()
        val owner = DeepLinkRouter.LaunchOwner()
        h.router.beginActivity(owner)
        h.onProvisionalRead = h::finishRestore

        h.router.dispatchStartup(push(), owner)
        assertEquals(1, h.provisionalReads)
        val host = host(h, FakeAuthRepository(AuthSession.SignedIn(userA, null)))
        advanceUntilIdle()
        register(host, owner)

        assertEquals("A same-ticket push was lost as Initializing became Authenticated", route, host.nextRouteOrNull())
        assertNull("The push navigated twice", host.nextRouteOrNull())
    }

    @Test fun app_link_restoration_completing_inside_witness_read_still_delivers_once() = runTest {
        val h = Harness()
        val owner = DeepLinkRouter.LaunchOwner()
        h.router.beginActivity(owner)
        h.onProvisionalRead = h::finishRestore

        h.router.dispatchStartup(appLink(), owner)
        assertEquals(1, h.provisionalReads)
        val host = host(h, FakeAuthRepository(AuthSession.SignedIn(userA, null)))
        advanceUntilIdle()
        register(host, owner)

        assertEquals("A same-ticket App Link was lost as Initializing became Authenticated", route, host.nextRouteOrNull())
        assertNull("The App Link navigated twice", host.nextRouteOrNull())
    }

    @Test fun mounted_host_preserves_warm_tap_when_SDK_enters_Initializing_after_ticket_read() = runTest {
        val h = Harness()
        h.status = SdkStatus.Authenticated
        h.sdkTicket = ticketA
        val owner = DeepLinkRouter.LaunchOwner()
        h.router.beginActivity(owner)
        val auth = FakeAuthRepository(AuthSession.SignedIn(userA, null))
        val host = host(h, auth)
        advanceUntilIdle()
        register(host, owner)

        // The router reads a valid A ticket, then the SDK enters its ordinary
        // background restoration interval before the mounted host receives it.
        h.onCurrentRead = {
            h.status = SdkStatus.Initializing
            h.sdkTicket = null
            h.storedWitness = ticketA
        }
        h.router.dispatch(push(), owner)
        auth.setSession(AuthSession.Unknown)
        advanceUntilIdle()
        assertNull("A stored witness alone must never navigate", host.nextRouteOrNull())

        h.finishRestore()
        auth.setSession(AuthSession.SignedIn(userA, null))
        advanceUntilIdle()
        assertEquals("An exact A warm tap was lost in the SDK transition", route, host.nextRouteOrNull())
        assertNull("The warm tap navigated twice", host.nextRouteOrNull())
    }

    @Test fun same_UID_A1_to_A2_to_A1_cannot_replay_A1_buffered_host_event() = runTest {
        val h = Harness()
        h.status = SdkStatus.Authenticated
        h.sdkTicket = ticketA
        val owner = DeepLinkRouter.LaunchOwner()
        h.router.beginActivity(owner)
        val auth = FakeAuthRepository(AuthSession.SignedIn(userA, "a1@example.test"))
        val host = host(h, auth)
        advanceUntilIdle()
        register(host, owner)
        h.router.dispatch(push(), owner) // A1 event is buffered; no collector yet.

        // Distinct email values force FakeAuthRepository's StateFlow to emit
        // both same-UID SignedIn events. The SDK tickets name different logins.
        h.sdkTicket = ticketA2
        auth.setSession(AuthSession.SignedIn(userA, "a2@example.test"))
        advanceUntilIdle()
        h.sdkTicket = ticketA
        auth.setSession(AuthSession.SignedIn(userA, "a1-return@example.test"))
        advanceUntilIdle()

        assertNull("A1's buffered event replayed after an observed A2 login", host.nextRouteOrNull())
        val freshRoute = Routes.repairJobDetailRoute("RPR-00028")
        h.router.dispatch(push(freshRoute), owner)
        assertEquals("A fresh A1 tap must still work", freshRoute, host.nextRouteOrNull())
    }

    @Test fun held_tap_survives_SDK_restore_during_take() {
        val h = Harness()
        val owner = DeepLinkRouter.LaunchOwner()
        h.router.beginActivity(owner)
        h.router.dispatchStartup(push(), owner)
        h.onProvisionalRead = h::finishRestore

        val firstClaim = h.router.takeStartupFor(owner, userA)
        assertTrue("The take race did not cross the witness read", h.provisionalReads >= 2)
        val claimed = firstClaim ?: h.router.takeStartupFor(owner, userA)

        assertEquals("A held tap was consumed while the exact SDK ticket appeared", route, claimed?.route)
        assertNull("The held tap was claimed twice", h.router.takeStartupFor(owner, userA))
    }

    @Test fun newer_Activity_tap_survives_SDK_restore_during_old_owner_retirement() {
        val h = Harness()
        val oldOwner = DeepLinkRouter.LaunchOwner()
        val newOwner = DeepLinkRouter.LaunchOwner()
        h.router.beginActivity(oldOwner)
        h.router.beginActivity(newOwner)
        h.router.dispatchStartup(push(), newOwner)
        h.onProvisionalRead = h::finishRestore

        // A delayed old-B boundary cannot retire new Activity A's exact restoration handoff.
        h.router.retireStartupFor(oldOwner, userB)
        assertTrue("The retire race did not cross the witness read", h.provisionalReads >= 2)

        assertEquals(
            "A newer Activity's held tap was retired while its SDK ticket appeared",
            route,
            h.router.takeStartupFor(newOwner, userA)?.route,
        )
        assertNull(h.router.takeStartupFor(newOwner, userA))
    }

    @Test fun delayed_old_same_user_signout_cannot_retire_new_authenticated_login_tap() {
        val h = Harness()
        val owner = DeepLinkRouter.LaunchOwner()
        h.router.beginActivity(owner)
        // A1 was the observed login. Before its SignedOut callback reaches the
        // router, a fresh A2 login (same UID, different session ID) receives a tap.
        h.status = SdkStatus.Authenticated
        h.sdkTicket = ticketA
        h.sdkTicket = ticketA2
        h.router.dispatchStartup(push(), owner)

        h.router.retireStartupFor(owner, userA)

        assertEquals(
            "A1's delayed sign-out erased an exact A2 SDK launch",
            route,
            h.router.takeStartupFor(owner, userA)?.route,
        )
        assertNull(h.router.takeStartupFor(owner, userA))
    }

    @Test fun delayed_old_same_user_signout_cannot_retire_new_restoring_login_tap() {
        val h = Harness()
        val owner = DeepLinkRouter.LaunchOwner()
        h.router.beginActivity(owner)
        h.status = SdkStatus.Authenticated
        h.sdkTicket = ticketA
        // A2 is the encrypted stored login while the SDK restores it. The old
        // A1 SignedOut callback is delivered after this newer tap was captured.
        h.status = SdkStatus.Initializing
        h.sdkTicket = null
        h.storedWitness = ticketA2
        h.router.dispatchStartup(push(), owner)

        h.router.retireStartupFor(owner, userA)
        h.status = SdkStatus.Authenticated
        h.sdkTicket = ticketA2

        assertEquals(
            "A1's delayed sign-out erased an exact A2 restoration launch",
            route,
            h.router.takeStartupFor(owner, userA)?.route,
        )
        assertNull(h.router.takeStartupFor(owner, userA))
    }

    @Test fun cold_NotAuthenticated_before_any_host_retires_the_stored_tap() = runTest {
        assertColdTerminalStatusRetiresTap(SdkStatus.NotAuthenticated)
    }

    @Test fun cold_RefreshFailure_before_any_host_retires_the_stored_tap() = runTest {
        assertColdTerminalStatusRetiresTap(SdkStatus.RefreshFailure)
    }

    private suspend fun TestScope.assertColdTerminalStatusRetiresTap(terminal: SdkStatus) {
        val h = Harness()
        val owner = DeepLinkRouter.LaunchOwner()
        h.router.beginActivity(owner)
        h.router.dispatchStartup(push(), owner)
        assertEquals(1, h.provisionalReads)

        // No DeepLinkHost is mounted while Supabase settles to a terminal status. Both SDK
        // statuses map to SignedOut in SupabaseAuthRepository; a later identical ticket must not
        // resurrect a tap from before that observed logout/failure boundary.
        val auth = FakeAuthRepository(AuthSession.Unknown)
        h.status = terminal
        auth.setSession(AuthSession.SignedOut)
        // MainActivity observes SignedOut even when no DeepLinkHost has mounted. Both terminal
        // SDK statuses map to that boundary; it must retire this Activity's pending tap now.
        h.router.retireStartupForTerminalSession(owner)
        advanceUntilIdle()
        h.finishRestore()
        auth.setSession(AuthSession.SignedIn(userA, null))

        val host = host(h, auth)
        advanceUntilIdle()
        register(host, owner)
        assertNull("$terminal let a later exact ticket claim the old cold tap", host.nextRouteOrNull())
    }

    private fun push(targetRoute: String = route): Intent = Intent()
        .putExtra(DeepLinkRouter.EXTRA_ROUTE, targetRoute)
        .putExtra(DeepLinkRouter.EXTRA_RECIPIENT_USER_ID, userA)

    private fun appLink(): Intent = Intent().apply {
        data = Uri.parse("https://equipseva.com/job/RPR-00027")
    }

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
