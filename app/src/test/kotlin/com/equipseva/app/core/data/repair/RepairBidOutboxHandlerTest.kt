package com.equipseva.app.core.data.repair

import com.equipseva.app.core.data.entities.OutboxEntryEntity
import com.equipseva.app.core.sync.OutboxKindHandler
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.IOException

class RepairBidOutboxHandlerTest {

    private val json = Json { ignoreUnknownKeys = true }

    @Test fun `malformed payload gives up immediately`() = runTest {
        val handler = RepairBidOutboxHandler(FakeBidRepository(), json)
        val entry = entry("not-json")

        val outcome = handler.handle(entry)

        assertTrue(outcome is OutboxKindHandler.Outcome.GiveUp)
    }

    @Test fun `valid payload delegates to placeBid and succeeds on success`() = runTest {
        val fake = FakeBidRepository()
        val handler = RepairBidOutboxHandler(fake, json)
        val entry = entry(
            """{"jobId":"job-1","amountRupees":1500.0,"etaHours":24,"note":"next day"}"""
        )

        val outcome = handler.handle(entry)

        assertTrue(outcome is OutboxKindHandler.Outcome.Success)
        assertEquals(1, fake.placeBidCalls.size)
        val call = fake.placeBidCalls.single()
        assertEquals("job-1", call.jobId)
        assertEquals(1500.0, call.amountRupees, 0.0)
        assertEquals(24, call.etaHours)
        assertEquals("next day", call.note)
    }

    @Test fun `retry when placeBid throws a transient error`() = runTest {
        val fake = FakeBidRepository(nextResult = Result.failure(IOException("offline")))
        val handler = RepairBidOutboxHandler(fake, json)
        val entry = entry("""{"jobId":"job-2","amountRupees":500.0}""")

        val outcome = handler.handle(entry)

        assertTrue(outcome is OutboxKindHandler.Outcome.Retry)
    }

    private fun entry(payload: String) = OutboxEntryEntity(
        id = 1L,
        kind = "repair_bid",
        payload = payload,
        createdAt = 0L,
    )

    private class FakeBidRepository(
        private val nextResult: Result<RepairBid>? = null,
    ) : RepairBidRepository {
        data class PlaceBidCall(
            val jobId: String,
            val amountRupees: Double,
            val etaHours: Int?,
            val note: String?,
        )
        val placeBidCalls = mutableListOf<PlaceBidCall>()

        override suspend fun fetchOwnBidForJob(jobId: String): Result<RepairBid?> = Result.success(null)
        override suspend fun fetchBidsForJob(jobId: String): Result<List<RepairBid>> = Result.success(emptyList())
        override suspend fun placeBid(
            jobId: String,
            amountRupees: Double,
            etaHours: Int?,
            note: String?,
        ): Result<RepairBid> {
            placeBidCalls += PlaceBidCall(jobId, amountRupees, etaHours, note)
            return nextResult ?: Result.success(stubBid(jobId, amountRupees))
        }

        override suspend fun withdrawBid(bidId: String): Result<Unit> = Result.success(Unit)
        override suspend fun acceptBid(bidId: String): Result<Unit> = Result.success(Unit)
        override suspend fun fetchMyBids(): Result<List<RepairBid>> = Result.success(emptyList())

        private fun stubBid(jobId: String, amountRupees: Double) = RepairBid(
            id = "bid-1",
            repairJobId = jobId,
            engineerUserId = "engineer-1",
            amountRupees = amountRupees,
            etaHours = null,
            note = null,
            status = RepairBidStatus.Pending,
            createdAtInstant = null,
            updatedAtInstant = null,
        )
    }
}
