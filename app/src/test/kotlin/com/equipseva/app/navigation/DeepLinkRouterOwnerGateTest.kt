package com.equipseva.app.navigation

import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.testing.FakeAuthRepository
import kotlinx.coroutines.flow.toList
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * A3-02 — deep links must not replay across login boundaries. Pure JVM: the
 * router's session-aware core ([DeepLinkRouter.dispatchRoute]) is driven
 * directly, with a [FakeAuthRepository] standing in for auth.
 */
@OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)
class DeepLinkRouterOwnerGateTest {

    private val job = Routes.repairJobDetailRoute("RPR-00040")
    private val chat = Routes.chatRoute("11111111-2222-3333-4444-555555555555")

    private fun signedIn(id: String) = AuthSession.SignedIn(userId = id, email = null)

    @Test fun `link dispatched while signed out is dropped, not buffered for the next login`() = runTest {
        val auth = FakeAuthRepository(AuthSession.SignedOut)
        val logs = mutableListOf<String>()
        val router = DeepLinkRouter(auth, backgroundScope) { logs += it }
        runCurrent()
        router.dispatchRoute(job, recipientUserId = null)
        auth.setSession(signedIn("B"))
        runCurrent()
        val received = mutableListOf<DeepLinkRouter.Event>()
        backgroundScope.launch { router.events.toList(received) }
        runCurrent()
        assertTrue("B must not inherit the signed-out tap: $received", received.isEmpty())
        assertTrue(logs.any { it.contains("signed out") })
    }

    @Test fun `links dispatched while auth is still resolving are delivered in order to the first login`() = runTest {
        // Cold start from a tray tap: the SDK has not yet restored the session.
        val auth = FakeAuthRepository(AuthSession.Unknown)
        val router = DeepLinkRouter(auth, backgroundScope) {}
        runCurrent()
        router.dispatchRoute(job, recipientUserId = null)
        router.dispatchRoute(chat, recipientUserId = null)
        val received = mutableListOf<DeepLinkRouter.Event>()
        backgroundScope.launch { router.events.toList(received) }
        runCurrent()
        assertTrue("nothing may be delivered before an owner exists", received.isEmpty())
        auth.setSession(signedIn("A"))
        runCurrent()
        assertEquals(
            listOf(DeepLinkRouter.Event.OpenRoute(job, "A"), DeepLinkRouter.Event.OpenRoute(chat, "A")),
            received,
        )
    }

    @Test fun `pending links are discarded when auth resolves to signed out`() = runTest {
        val auth = FakeAuthRepository(AuthSession.Unknown)
        val router = DeepLinkRouter(auth, backgroundScope) {}
        runCurrent()
        router.dispatchRoute(job, recipientUserId = null)
        auth.setSession(AuthSession.SignedOut)
        runCurrent()
        auth.setSession(signedIn("A"))
        runCurrent()
        val received = mutableListOf<DeepLinkRouter.Event>()
        backgroundScope.launch { router.events.toList(received) }
        runCurrent()
        assertTrue(received.isEmpty())
    }

    @Test fun `events buffered under A are cleared by sign-out and never reach B or A's next login`() = runTest {
        val auth = FakeAuthRepository(signedIn("A"))
        val router = DeepLinkRouter(auth, backgroundScope) {}
        runCurrent()
        router.dispatchRoute(job, recipientUserId = null) // buffered: no MAIN collecting yet
        auth.setSession(AuthSession.SignedOut)
        runCurrent()
        auth.setSession(signedIn("B"))
        runCurrent()
        val received = mutableListOf<DeepLinkRouter.Event>()
        backgroundScope.launch { router.events.toList(received) }
        runCurrent()
        assertTrue("A's buffered tap must not surface for B: $received", received.isEmpty())
    }

    @Test fun `same user relogin does not replay a tap buffered under the previous login`() = runTest {
        // A → SignedOut → A (same user, new login) is the same boundary as A → B.
        // No MAIN is collecting yet (cold path), so the tap sits in the buffer.
        val auth = FakeAuthRepository(signedIn("A"))
        val router = DeepLinkRouter(auth, backgroundScope) {}
        runCurrent()
        router.dispatchRoute(chat, recipientUserId = null)
        auth.setSession(AuthSession.SignedOut)
        runCurrent()
        auth.setSession(signedIn("A"))
        runCurrent()
        val received = mutableListOf<DeepLinkRouter.Event>()
        backgroundScope.launch { router.events.toList(received) }
        runCurrent()
        assertTrue("A's previous-login tap must not replay into the new login: $received", received.isEmpty())
    }

    @Test fun `event is stamped with the dispatching owner and delivered to it`() = runTest {
        val auth = FakeAuthRepository(signedIn("A"))
        val router = DeepLinkRouter(auth, backgroundScope) {}
        runCurrent()
        val received = mutableListOf<DeepLinkRouter.Event>()
        backgroundScope.launch { router.events.toList(received) }
        router.dispatchRoute(job, recipientUserId = null)
        runCurrent()
        assertEquals(listOf(DeepLinkRouter.Event.OpenRoute(job, "A")), received)
    }

    @Test fun `a recipient stamped for another account is dropped, matching recipient passes`() = runTest {
        val auth = FakeAuthRepository(signedIn("A"))
        val logs = mutableListOf<String>()
        val router = DeepLinkRouter(auth, backgroundScope) { logs += it }
        runCurrent()
        val received = mutableListOf<DeepLinkRouter.Event>()
        backgroundScope.launch { router.events.toList(received) }
        router.dispatchRoute(job, recipientUserId = "B")
        router.dispatchRoute(chat, recipientUserId = "A")
        runCurrent()
        assertEquals(listOf(DeepLinkRouter.Event.OpenRoute(chat, "A")), received)
        assertTrue(logs.any { it.contains("different account") })
    }

    @Test fun `clear drops both the pending queue and the buffered channel`() = runTest {
        val auth = FakeAuthRepository(AuthSession.Unknown)
        val router = DeepLinkRouter(auth, backgroundScope) {}
        runCurrent()
        router.dispatchRoute(job, recipientUserId = null) // pending
        auth.setSession(signedIn("A"))
        runCurrent()                                        // now buffered in the channel
        router.dispatchRoute(chat, recipientUserId = null) // buffered too
        router.clear()
        val received = mutableListOf<DeepLinkRouter.Event>()
        backgroundScope.launch { router.events.toList(received) }
        runCurrent()
        assertTrue(received.isEmpty())
    }
}
