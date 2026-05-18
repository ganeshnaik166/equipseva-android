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

// Round 330 — revive against the current JobStatusOutboxHandler shape.
// Six outcome branches:
//   1. malformed payload          -> GiveUp("Malformed payload: ...")
//   2. unknown status string      -> GiveUp("Unknown status: ...")
//   3. no auth session            -> Retry
//   4. legacy payload (null uid)  -> GiveUp (round 236+ refusal)
//   5. actor mismatch             -> GiveUp("Actor mismatch: ...")
//   6. happy path                 -> Success
class JobStatusOutboxHandlerTest {

    private lateinit var jobRepository: RepairJobRepository
    private lateinit var client: SupabaseClient
    private lateinit var auth: Auth
    private lateinit var handler: JobStatusOutboxHandler

    @Before fun setUp() {
        jobRepository = mockk(relaxed = true)
        client = mockk()
        auth = mockk()
        mockkStatic("io.github.jan.supabase.auth.AuthKt")
        every { client.auth } returns auth
        handler = JobStatusOutboxHandler(jobRepository, client, Json)
    }

    @After fun tearDown() {
        unmockkStatic("io.github.jan.supabase.auth.AuthKt")
    }

    private fun entry(payload: String) = OutboxEntryEntity(
        kind = "job_status",
        payload = payload,
        createdAt = 1_700_000_000_000L,
    )

    @Test fun `malformed payload returns GiveUp`() = runTest {
        every { auth.currentUserOrNull() } returns null
        val outcome = handler.handle(entry("not json"))
        assertTrue(outcome is OutboxKindHandler.Outcome.GiveUp)
        assertTrue((outcome as OutboxKindHandler.Outcome.GiveUp).reason.startsWith("Malformed payload"))
    }

    @Test fun `unknown status string returns GiveUp`() = runTest {
        every { auth.currentUserOrNull() } returns userInfo("eng-1")
        val payload = """{"jobId":"job-1","newStatus":"FroBnIcAtEd","actorUserId":"eng-1"}"""
        val outcome = handler.handle(entry(payload))
        assertTrue(outcome is OutboxKindHandler.Outcome.GiveUp)
        assertTrue((outcome as OutboxKindHandler.Outcome.GiveUp).reason.startsWith("Unknown status"))
    }

    @Test fun `no auth session returns Retry`() = runTest {
        every { auth.currentUserOrNull() } returns null
        val payload = """{"jobId":"job-1","newStatus":"Completed","actorUserId":"eng-1"}"""
        val outcome = handler.handle(entry(payload))
        assertTrue(outcome is OutboxKindHandler.Outcome.Retry)
    }

    @Test fun `legacy payload with null actorUserId is refused`() = runTest {
        // Round 236 tightened this — null actor must be GiveUp'd rather
        // than drained under whichever user is currently signed in.
        every { auth.currentUserOrNull() } returns userInfo("eng-1")
        val payload = """{"jobId":"job-1","newStatus":"Completed"}"""
        val outcome = handler.handle(entry(payload))
        assertTrue(outcome is OutboxKindHandler.Outcome.GiveUp)
        assertTrue(
            (outcome as OutboxKindHandler.Outcome.GiveUp).reason
                .startsWith("Missing actorUserId on legacy payload"),
        )
    }

    @Test fun `actor mismatch returns GiveUp`() = runTest {
        every { auth.currentUserOrNull() } returns userInfo("eng-DIFFERENT")
        val payload = """{"jobId":"job-1","newStatus":"Completed","actorUserId":"eng-1"}"""
        val outcome = handler.handle(entry(payload))
        assertTrue(outcome is OutboxKindHandler.Outcome.GiveUp)
        assertTrue((outcome as OutboxKindHandler.Outcome.GiveUp).reason.startsWith("Actor mismatch"))
    }

    @Test fun `happy path returns Success`() = runTest {
        every { auth.currentUserOrNull() } returns userInfo("eng-1")
        val anyJob = mockk<RepairJob>(relaxed = true)
        coEvery {
            jobRepository.updateStatus(
                jobId = "job-1",
                newStatus = RepairJobStatus.InProgress,
                startedAt = any(),
                completedAt = any(),
                cancellationReason = any(),
            )
        } returns Result.success(anyJob)

        val payload = """{
            "jobId":"job-1",
            "newStatus":"InProgress",
            "startedAtEpochMs":1700000000000,
            "actorUserId":"eng-1"
        }""".trimIndent()
        val outcome = handler.handle(entry(payload))
        assertEquals(OutboxKindHandler.Outcome.Success, outcome)
    }

    private fun userInfo(id: String): UserInfo {
        val u = mockk<UserInfo>()
        every { u.id } returns id
        return u
    }
}
