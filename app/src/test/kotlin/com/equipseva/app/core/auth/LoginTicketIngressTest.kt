package com.equipseva.app.core.auth

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.Auth
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.status.SessionStatus
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkStatic
import io.mockk.unmockkStatic
import io.mockk.verify
import kotlinx.coroutines.flow.MutableStateFlow
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test

class LoginTicketIngressTest {
    private val ticket = LoginTicketSnapshot(
        userId = "11111111-1111-4111-8111-111111111111",
        sessionId = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
    )

    private lateinit var client: SupabaseClient
    private lateinit var auth: Auth
    private lateinit var manager: EncryptedSessionManager
    private lateinit var status: MutableStateFlow<SessionStatus>

    @Before fun setUp() {
        client = mockk()
        auth = mockk()
        manager = mockk()
        status = MutableStateFlow(SessionStatus.Initializing)
        mockkStatic("io.github.jan.supabase.auth.AuthKt")
        every { client.auth } returns auth
        every { auth.sessionStatus } returns status
        every { manager.peekStoredLoginTicket() } returns ticket
    }

    @After fun tearDown() {
        unmockkStatic("io.github.jan.supabase.auth.AuthKt")
    }

    @Test fun `Initializing may read a stored witness while currentTicket stays SDK-only`() {
        every { auth.currentSessionOrNull() } returns null
        val source = LoginTicketSource(client, manager)

        assertNull(source.currentTicket())
        assertEquals(ticket, source.provisionalStoredTicketDuringInitializing())
        verify(exactly = 1) { manager.peekStoredLoginTicket() }
    }

    @Test fun `non-initializing SDK states never read stored identity`() {
        val source = LoginTicketSource(client, manager)
        val otherStatuses: List<SessionStatus> = listOf(
            SessionStatus.NotAuthenticated(),
            mockk<SessionStatus.RefreshFailure>(),
            mockk<SessionStatus.Authenticated>(),
        )

        otherStatuses.forEach { sdkStatus ->
            status.value = sdkStatus
            assertNull(source.provisionalStoredTicketDuringInitializing())
        }
        verify(exactly = 0) { manager.peekStoredLoginTicket() }
    }

    @Test fun `status change during storage read discards provisional witness`() {
        val source = LoginTicketSource(client, manager)
        every { manager.peekStoredLoginTicket() } answers {
            status.value = SessionStatus.NotAuthenticated()
            ticket
        }

        assertNull(source.provisionalStoredTicketDuringInitializing())
        verify(exactly = 1) { manager.peekStoredLoginTicket() }
    }
}
