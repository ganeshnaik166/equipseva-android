package com.equipseva.app.core.auth

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.Auth
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.user.UserInfo
import io.github.jan.supabase.auth.user.UserSession
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkStatic
import io.mockk.unmockkStatic
import io.mockk.verify
import java.util.Base64
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test

class LoginTicketSourceTest {
    private val userA = "11111111-1111-4111-8111-111111111111"
    private val userB = "22222222-2222-4222-8222-222222222222"
    private val loginA = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
    private val loginB = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"

    private lateinit var client: SupabaseClient
    private lateinit var auth: Auth

    @Before fun setUp() {
        client = mockk()
        auth = mockk()
        mockkStatic("io.github.jan.supabase.auth.AuthKt")
        every { client.auth } returns auth
    }

    @After fun tearDown() {
        unmockkStatic("io.github.jan.supabase.auth.AuthKt")
    }

    @Test fun `one SDK session snapshot yields its matching login ticket`() {
        every { auth.currentSessionOrNull() } returns session(userA, jwt(userA, loginA))

        assertEquals(LoginTicketSnapshot(userA, loginA), LoginTicketSource(client).currentTicket())
        verify(exactly = 1) { auth.currentSessionOrNull() }
        verify(exactly = 0) { auth.currentUserOrNull() }
    }

    @Test fun `missing or initializing session has no ticket`() {
        every { auth.currentSessionOrNull() } returns null

        assertNull(LoginTicketSource(client).currentTicket())
        verify(exactly = 1) { auth.currentSessionOrNull() }
    }

    @Test fun `session without user has no ticket`() {
        every { auth.currentSessionOrNull() } returns session(null, jwt(userA, loginA))

        assertNull(LoginTicketSource(client).currentTicket())
    }

    @Test fun `session user must equal JWT subject`() {
        every { auth.currentSessionOrNull() } returns session(userA, jwt(userB, loginA))

        assertNull(LoginTicketSource(client).currentTicket())
    }

    @Test fun `refresh with a new access token preserves the same login ticket`() {
        val first = parseLoginTicket(userA, jwt(userA, loginA, "one"))
        val refreshed = parseLoginTicket(userA, jwt(userA, loginA, "two"))

        assertNotNull(first)
        assertEquals(first, refreshed)
    }

    @Test fun `same user new login has a different ticket`() {
        val first = parseLoginTicket(userA, jwt(userA, loginA))
        val nextLogin = parseLoginTicket(userA, jwt(userA, loginB))

        assertNotNull(first)
        assertNotNull(nextLogin)
        org.junit.Assert.assertNotEquals(first, nextLogin)
    }

    @Test fun `subject and session ID must each be canonical UUIDs`() {
        assertNull(parseLoginTicket("1-1-1-1-1", jwt("1-1-1-1-1", loginA)))
        assertNull(parseLoginTicket(userA, jwt(userA, "1-1-1-1-1")))
        assertNull(parseLoginTicket(userA, jwt("not-a-uuid", loginA)))
        assertNull(parseLoginTicket(userA, jwt(userA, "not-a-uuid")))
        assertNull(parseLoginTicket("  $userA", jwt(userA, loginA)))
        assertNull(parseLoginTicket(userA, jwt("$userA ", loginA)))
        assertNull(parseLoginTicket("00000000-0000-0000-0000-000000000000", jwt("00000000-0000-0000-0000-000000000000", loginA)))
        assertNull(parseLoginTicket(userA, jwt(userA, "00000000-0000-0000-0000-000000000000")))
    }

    @Test fun `UUID case does not create a different login identity`() {
        assertEquals(
            LoginTicketSnapshot(userA, loginA),
            parseLoginTicket(userA.uppercase(), jwt(userA, loginA.uppercase())),
        )
    }

    @Test fun `missing and non-string claims fail closed`() {
        assertNull(parseLoginTicket(userA, jwtPayload("""{"sub":"$userA"}""")))
        assertNull(parseLoginTicket(userA, jwtPayload("""{"session_id":"$loginA"}""")))
        assertNull(parseLoginTicket(userA, jwtPayload("""{"sub":42,"session_id":"$loginA"}""")))
        assertNull(parseLoginTicket(userA, jwtPayload("""{"sub":"$userA","session_id":42}""")))
        assertNull(parseLoginTicket(userA, jwtPayload("""[]""")))
    }

    @Test fun `malformed or unsigned JWT fails closed`() {
        assertNull(parseLoginTicket(userA, null))
        assertNull(parseLoginTicket(userA, ""))
        assertNull(parseLoginTicket(userA, "not.a.jwt.extra"))
        assertNull(parseLoginTicket(userA, "e30.@@@.signature"))
        assertNull(parseLoginTicket(userA, "e30.bm90LWpzb24.signature"))
        assertNull(parseLoginTicket(userA, jwt(userA, loginA).substringBeforeLast('.') + "."))
    }

    @Test fun `invalid JWT header and signature fail closed`() {
        val valid = jwt(userA, loginA)
        val parts = valid.split('.')
        assertNull(parseLoginTicket(userA, "@@@.${parts[1]}.${parts[2]}"))
        assertNull(parseLoginTicket(userA, "${parts[0]}.${parts[1]}.@@@"))
        val unsignedHeader = Base64.getUrlEncoder().withoutPadding()
            .encodeToString("""{"alg":"none"}""".toByteArray(Charsets.UTF_8))
        assertNull(parseLoginTicket(userA, "$unsignedHeader.${parts[1]}.${parts[2]}"))
    }

    private fun session(userId: String?, accessToken: String): UserSession {
        val userInfo = userId?.let { id ->
            mockk<UserInfo>().also { every { it.id } returns id }
        }
        return mockk<UserSession>().also {
            every { it.user } returns userInfo
            every { it.accessToken } returns accessToken
        }
    }

    private fun jwt(subject: String, sessionId: String, nonce: String = "one"): String =
        jwtPayload("""{"sub":"$subject","session_id":"$sessionId","nonce":"$nonce"}""")

    private fun jwtPayload(payload: String): String {
        fun encode(value: String): String = Base64.getUrlEncoder().withoutPadding()
            .encodeToString(value.toByteArray(Charsets.UTF_8))
        return "${encode("""{"alg":"HS256","typ":"JWT"}""")}.${encode(payload)}.${encode("signature")}"
    }
}
