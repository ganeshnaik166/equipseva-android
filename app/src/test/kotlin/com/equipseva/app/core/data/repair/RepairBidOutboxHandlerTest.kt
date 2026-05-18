package com.equipseva.app.core.data.repair

import com.equipseva.app.core.data.entities.OutboxEntryEntity
import com.equipseva.app.core.sync.OutboxKindHandler
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.Auth
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.user.UserInfo
import io.mockk.coEvery
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkStatic
import io.mockk.unmockkStatic
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.Json
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

// Round 329 — revive the suite using the mockk dep landed in round 328.
// Covers the four outcome branches of RepairBidOutboxHandler.handle:
//   1. malformed payload  -> GiveUp
//   2. no auth session    -> Retry
//   3. owner mismatch     -> GiveUp
//   4. happy path         -> Success
class RepairBidOutboxHandlerTest {

    private lateinit var bidRepository: RepairBidRepository
    private lateinit var client: SupabaseClient
    private lateinit var auth: Auth
    private lateinit var handler: RepairBidOutboxHandler

    @Before fun setUp() {
        bidRepository = mockk(relaxed = true)
        client = mockk()
        auth = mockk()
        // SupabaseClient.auth is a top-level extension property in
        // io.github.jan.supabase.auth.AuthKt — mockkStatic on the
        // generated class file lets us stub `client.auth` directly
        // without diving into the underlying pluginManager generics.
        mockkStatic("io.github.jan.supabase.auth.AuthKt")
        every { client.auth } returns auth
        handler = RepairBidOutboxHandler(bidRepository, client, Json)
    }

    @After fun tearDown() {
        unmockkStatic("io.github.jan.supabase.auth.AuthKt")
    }

    private fun entry(payload: String, kind: String = "repair_bid"): OutboxEntryEntity =
        OutboxEntryEntity(
            kind = kind,
            payload = payload,
            createdAt = 1_700_000_000_000L,
        )

    @Test fun `malformed payload returns GiveUp`() = runTest {
        every { auth.currentUserOrNull() } returns null
        val outcome = handler.handle(entry("this is not json"))
        assertTrue(outcome is OutboxKindHandler.Outcome.GiveUp)
        assertTrue((outcome as OutboxKindHandler.Outcome.GiveUp).reason.startsWith("Malformed payload"))
    }

    @Test fun `no auth session returns Retry`() = runTest {
        every { auth.currentUserOrNull() } returns null
        val payload = """{"jobId":"job-1","amountRupees":2500.0,"engineerUserId":"eng-1"}"""
        val outcome = handler.handle(entry(payload))
        assertTrue(outcome is OutboxKindHandler.Outcome.Retry)
    }

    @Test fun `owner mismatch returns GiveUp`() = runTest {
        every { auth.currentUserOrNull() } returns userInfo("eng-DIFFERENT")
        val payload = """{"jobId":"job-1","amountRupees":2500.0,"engineerUserId":"eng-1"}"""
        val outcome = handler.handle(entry(payload))
        assertTrue(outcome is OutboxKindHandler.Outcome.GiveUp)
        assertTrue((outcome as OutboxKindHandler.Outcome.GiveUp).reason.startsWith("Engineer mismatch"))
    }

    @Test fun `happy path delegates to placeBid and returns Success`() = runTest {
        every { auth.currentUserOrNull() } returns userInfo("eng-1")
        // Bid model is internal-detailed; we don't inspect the returned
        // RepairBid here, just the outer Result.success wrapper.
        val anyBid = mockk<RepairBid>(relaxed = true)
        coEvery {
            bidRepository.placeBid(
                jobId = "job-1",
                amountRupees = 2500.0,
                etaHours = 4,
                note = "any",
            )
        } returns Result.success(anyBid)

        val payload = """{
            "jobId":"job-1",
            "amountRupees":2500.0,
            "etaHours":4,
            "note":"any",
            "engineerUserId":"eng-1"
        }""".trimIndent()
        val outcome = handler.handle(entry(payload))
        assertEquals(OutboxKindHandler.Outcome.Success, outcome)
    }

    @Test fun `backward compat null engineerUserId still proceeds`() = runTest {
        // Rows queued before the owner-gate field landed have null
        // engineerUserId; handler must NOT short-circuit on the owner
        // gate (server-side RLS still keeps the bid scoped to the caller).
        every { auth.currentUserOrNull() } returns userInfo("eng-anyone")
        val anyBid = mockk<RepairBid>(relaxed = true)
        coEvery {
            bidRepository.placeBid(
                jobId = "job-legacy",
                amountRupees = 1000.0,
                etaHours = null,
                note = null,
            )
        } returns Result.success(anyBid)
        val payload = """{"jobId":"job-legacy","amountRupees":1000.0}"""
        val outcome = handler.handle(entry(payload))
        assertEquals(OutboxKindHandler.Outcome.Success, outcome)
    }

    private fun userInfo(id: String): UserInfo {
        val u = mockk<UserInfo>()
        every { u.id } returns id
        return u
    }
}
