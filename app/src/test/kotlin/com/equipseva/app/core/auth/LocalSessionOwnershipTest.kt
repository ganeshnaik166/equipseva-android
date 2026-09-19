package com.equipseva.app.core.auth

import com.equipseva.app.testing.FakeAuthRepository
import java.util.Base64
import java.util.Collections
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.TimeoutException
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.*
import org.junit.Test

@OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)
class LocalSessionOwnershipTest {
    private class Fixture(
        scope: TestScope,
        initial: AuthSession = signedIn("A"),
        identity: LocalSessionOwnership.Identity? = identity("A"),
    ) {
        val auth = FakeAuthRepository(initial)
        @Volatile var raw = identity
        val owner = LocalSessionOwnership(auth, { raw }, scope.backgroundScope)
        fun observe(id: LocalSessionOwnership.Identity) {
            raw = id
            auth.setSession(AuthSession.SignedIn(id.ownerId, "${id.sessionId}@test.invalid"))
        }
        fun ticket() = requireNotNull(owner.capture())
    }

    @Test fun `agreeing signed in identity issues a usable ticket`() = runTest {
        val f = Fixture(this)
        runCurrent()
        val ticket = f.ticket()
        assertEquals(identity("A"), ticket.identity)
        var ran = false
        assertTrue(f.owner.withCurrent(ticket) { ran = true })
        assertTrue(ran)
    }

    @Test fun `initial Unknown and SignedOut cannot mint from cached SDK identity`() = runTest {
        for (initial in listOf(AuthSession.Unknown, AuthSession.SignedOut)) {
            val f = Fixture(this, initial)
            runCurrent()
            assertNull("$initial must not promote a cached raw login", f.owner.capture())
            assertFalse(f.owner.withCurrent(null) { fail("No ticket may mutate") })
        }
    }

    @Test fun `repeated capture and same session email or token refresh preserve exact ticket`() = runTest {
        val f = Fixture(this)
        runCurrent()
        val ticket = f.ticket()
        assertSame(ticket, f.owner.capture())
        f.raw = identity("A").copy()
        f.auth.setSession(AuthSession.SignedIn("A", "refreshed@test.invalid"))
        runCurrent()
        assertSame(ticket, f.owner.capture())
        assertTrue(f.owner.withCurrent(ticket) {})
    }

    @Test fun `established Unknown retains only a matching raw login`() = runTest {
        val f = Fixture(this)
        runCurrent()
        val ticket = f.ticket()
        f.auth.setSession(AuthSession.Unknown)
        runCurrent()
        assertSame(ticket, f.owner.capture())
        assertTrue(f.owner.withCurrent(ticket) {})
        f.raw = null
        assertNull(f.owner.capture())
        f.raw = identity("A")
        assertFalse("Missing raw identity permanently retires the old ticket", f.owner.withCurrent(ticket) { fail("Retired ticket action ran") })
        assertNull("Unknown cannot re-establish it", f.owner.capture())
    }

    @Test fun `invalid raw identifiers and disagreeing observed user issue nothing`() = runTest {
        val identities = listOf(null, identity(""), identity(" "), identity("A", ""), identity("A", " \t"), identity("B"))
        identities.forEach { raw ->
            val f = Fixture(this, identity = raw)
            runCurrent()
            assertNull("Invalid or foreign raw identity $raw", f.owner.capture())
        }
        val blankObserved = Fixture(this, AuthSession.SignedIn(" ", null))
        runCurrent()
        assertNull(blankObserved.owner.capture())
    }

    @Test fun `capture sees raw B before observer and never revives original A`() = runTest {
        val f = Fixture(this)
        runCurrent()
        val old = f.ticket()
        f.raw = identity("B")
        assertNull("A raw probe may revoke but cannot mint replacement B", f.owner.capture())
        f.raw = identity("A")
        assertFalse(f.owner.withCurrent(old) { fail("Old A revived") })
        assertNull("No new observation has re-established A", f.owner.capture())
        f.observe(identity("B"))
        runCurrent()
        assertTrue(f.owner.withCurrent(f.ticket()) {})
    }

    @Test fun `guard observes raw ABA and permanently invalidates old ticket`() = runTest {
        val f = Fixture(this)
        runCurrent()
        val old = f.ticket()
        f.raw = identity("B")
        assertFalse(f.owner.withCurrent(old) { fail("Foreign raw login admitted") })
        f.raw = identity("A")
        assertFalse(f.owner.withCurrent(old) { fail("Raw ABA revived old A") })
        assertNull(f.owner.capture())
    }

    @Test fun `null and malformed raw identity invalidate a previously issued ticket`() = runTest {
        for (bad in listOf(null, identity("A", ""), identity("", "session-A"))) {
            val f = Fixture(this)
            runCurrent()
            val old = f.ticket()
            f.raw = bad
            assertFalse(f.owner.withCurrent(old) { fail("Invalid identity admitted") })
            f.raw = identity("A")
            assertFalse(f.owner.withCurrent(old) { fail("Rejected ticket action ran") })
        }
    }

    @Test fun `observed A B A has a new generation even when final identity matches`() = runTest {
        val f = Fixture(this)
        runCurrent()
        val old = f.ticket()
        f.observe(identity("B"))
        runCurrent()
        val b = f.ticket()
        f.observe(identity("A"))
        runCurrent()
        val fresh = f.ticket()
        assertTrue(fresh.generation > b.generation && b.generation > old.generation)
        assertFalse(f.owner.withCurrent(old) { fail("Rejected ticket action ran") })
        assertFalse(f.owner.withCurrent(b) { fail("Rejected ticket action ran") })
        assertTrue(f.owner.withCurrent(fresh) {})
    }

    @Test fun `same user with new session id rejects old work before observer catches up`() = runTest {
        val f = Fixture(this)
        runCurrent()
        val old = f.ticket()
        f.raw = identity("A", "session-A2")
        assertFalse(f.owner.withCurrent(old) { fail("Rejected ticket action ran") })
        assertNull(f.owner.capture())
        f.observe(identity("A", "session-A2"))
        runCurrent()
        val fresh = f.ticket()
        assertTrue(fresh.generation > old.generation)
        assertTrue(f.owner.withCurrent(fresh) {})
    }

    @Test fun `SignedOut invalidates cached login and observed relogin creates new ticket`() = runTest {
        val f = Fixture(this)
        runCurrent()
        val old = f.ticket()
        f.auth.setSession(AuthSession.SignedOut)
        runCurrent()
        assertNull(f.owner.capture())
        assertFalse(f.owner.withCurrent(old) { fail("Rejected ticket action ran") })
        f.observe(identity("A"))
        runCurrent()
        val fresh = f.ticket()
        assertNotSame(old, fresh)
        assertTrue(fresh.generation > old.generation)
        assertTrue(f.owner.withCurrent(fresh) {})
    }

    @Test fun `explicit retirement blocks cached identity through Unknown and logout reemit`() = runTest {
        val f = Fixture(this)
        runCurrent()
        val old = f.ticket()
        assertTrue(f.owner.retire(old))
        assertFalse(f.owner.retire(old))
        assertFalse(f.owner.withCurrent(old) { fail("Rejected ticket action ran") })
        f.raw = null
        assertNull("Missing or malformed raw identity cannot rearm explicit retirement", f.owner.capture())
        f.raw = identity("A")
        for (event in listOf(AuthSession.Unknown, AuthSession.SignedOut, signedIn("A"))) {
            f.auth.setSession(event)
            runCurrent()
            assertNull("Retired cached login must remain blocked after $event", f.owner.capture())
        }
        f.observe(identity("A", "session-A2"))
        runCurrent()
        assertTrue(f.owner.withCurrent(f.ticket()) {})
    }

    @Test fun `retiring stale A cannot retire current B and distinct identity clears retirement cache`() = runTest {
        val f = Fixture(this)
        runCurrent()
        val a = f.ticket()
        f.owner.retire(a)
        f.observe(identity("B"))
        runCurrent()
        val b = f.ticket()
        assertFalse(f.owner.retire(a))
        assertSame(b, f.owner.capture())
        assertTrue(f.owner.withCurrent(b) {})
        f.observe(identity("A"))
        runCurrent()
        val newA = f.ticket()
        assertNotSame(a, newA)
        assertTrue(f.owner.withCurrent(newA) {})
        assertFalse(f.owner.withCurrent(a) { fail("Rejected ticket action ran") })
    }

    @Test fun `another issuer and equal looking constructed tickets cannot mutate`() = runTest {
        val f = Fixture(this)
        val other = Fixture(this)
        runCurrent()
        val current = f.ticket()
        val forged = LocalSessionOwnership.Ticket(current.identity, current.generation)
        for (bad in listOf(null, other.ticket(), forged)) {
            assertFalse(f.owner.withCurrent(bad) { fail("Unissued ticket admitted") })
        }
        assertFalse(f.owner.retire(forged))
        assertTrue(f.owner.withCurrent(current) {})
    }

    @Test fun `concurrent captures return one issued object without invalidating each other`() = runTest {
        val f = Fixture(this)
        runCurrent()
        val current = f.ticket()
        val executor = Executors.newFixedThreadPool(4)
        try {
            val captures = (1..12).map { executor.submit<LocalSessionOwnership.Ticket?> { f.owner.capture() } }
            captures.forEach { assertSame(current, it.get(5, TimeUnit.SECONDS)) }
            assertTrue(f.owner.withCurrent(current) {})
        } finally {
            executor.shutdownNow()
            assertTrue(executor.awaitTermination(5, TimeUnit.SECONDS))
        }
    }

    @Test fun `retirement serializes after admitted non suspending mutation`() = runTest {
        val f = Fixture(this)
        runCurrent()
        val ticket = f.ticket()
        val entered = CountDownLatch(1)
        val release = CountDownLatch(1)
        val retireEntered = CountDownLatch(1)
        val order = Collections.synchronizedList(mutableListOf<String>())
        val executor = Executors.newFixedThreadPool(2)
        try {
            val write = executor.submit<Boolean> { f.owner.withCurrent(ticket) {
                order += "mutation-enter"
                entered.countDown()
                assertTrue(release.await(5, TimeUnit.SECONDS))
                order += "mutation-end"
            } }
            assertTrue(entered.await(5, TimeUnit.SECONDS))
            val retirement = executor.submit<Boolean> {
                retireEntered.countDown()
                f.owner.retire(ticket).also { order += "retire-end" }
            }
            assertTrue(retireEntered.await(5, TimeUnit.SECONDS))
            assertFalse("Retirement cannot pass an admitted mutation", retirement.isDone)
            try {
                retirement.get(150, TimeUnit.MILLISECONDS)
                fail("Retirement completed while the mutation still held ownership")
            } catch (_: TimeoutException) {
                // Bounded proof that retirement remains blocked, not a single
                // scheduler-sensitive isDone read immediately after a latch.
            }
            release.countDown()
            assertTrue(write.get(5, TimeUnit.SECONDS))
            assertTrue(retirement.get(5, TimeUnit.SECONDS))
            assertEquals(listOf("mutation-enter", "mutation-end", "retire-end"), order)
            assertFalse(f.owner.withCurrent(ticket) { fail("Rejected ticket action ran") })
        } finally {
            release.countDown()
            executor.shutdownNow()
            assertTrue(executor.awaitTermination(5, TimeUnit.SECONDS))
        }
    }

    @Test fun `parser requires exact string sub and stable string session id`() {
        assertEquals(identity("A"), LocalSessionOwnership.identityFromAccessToken("A", token("""{"sub":"A","session_id":"session-A","iat":1}""")))
        assertEquals(identity("A"), LocalSessionOwnership.identityFromAccessToken("A", token("""{"sub":"A","session_id":"session-A","iat":999}""")))
    }

    @Test fun `parser rejects malformed missing null numeric boolean object array and foreign claims`() {
        val claims = listOf(
            "{}", "null", "[]", "not-json",
            """{"sub":"A"}""", """{"session_id":"session-A"}""",
            """{"sub":"B","session_id":"session-A"}""",
            """{"sub":1,"session_id":"session-A"}""", """{"sub":true,"session_id":"session-A"}""",
            """{"sub":null,"session_id":"session-A"}""", """{"sub":{},"session_id":"session-A"}""",
            """{"sub":[],"session_id":"session-A"}""",
            """{"sub":"A","session_id":null}""", """{"sub":"A","session_id":7}""",
            """{"sub":"A","session_id":false}""", """{"sub":"A","session_id":{}}""",
            """{"sub":"A","session_id":[]}""", """{"sub":"A","session_id":""}""",
            """{"sub":"A","session_id":"  "}""",
        )
        claims.forEach { assertNull(it, LocalSessionOwnership.identityFromAccessToken("A", token(it))) }
        listOf("", "x", "a.b", "a.b.c.d", "a.%%%25.c").forEach {
            assertNull(LocalSessionOwnership.identityFromAccessToken("A", it))
        }
        for (owner in listOf(null, "", " ", "B")) {
            assertNull(LocalSessionOwnership.identityFromAccessToken(owner, token("""{"sub":"A","session_id":"session-A"}""")))
        }
        // Numeric/boolean claims cannot be accepted through contentOrNull.
        assertNull(LocalSessionOwnership.identityFromAccessToken("1", token("""{"sub":1,"session_id":"s"}""")))
        assertNull(LocalSessionOwnership.identityFromAccessToken("true", token("""{"sub":true,"session_id":"s"}""")))
    }

    companion object {
        private fun signedIn(owner: String) = AuthSession.SignedIn(owner, "$owner@test.invalid")
        private fun identity(owner: String, session: String = "session-$owner") = LocalSessionOwnership.Identity(owner, session)
        private fun token(json: String) = "e30.${Base64.getUrlEncoder().withoutPadding().encodeToString(json.toByteArray(Charsets.UTF_8))}.synthetic"
    }
}
