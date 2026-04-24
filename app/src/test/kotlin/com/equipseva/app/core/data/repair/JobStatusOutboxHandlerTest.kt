package com.equipseva.app.core.data.repair

import com.equipseva.app.core.data.entities.OutboxEntryEntity
import com.equipseva.app.core.sync.OutboxKindHandler
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.IOException
import java.time.Instant

class JobStatusOutboxHandlerTest {

    private val json = Json { ignoreUnknownKeys = true }

    @Test fun `unknown status string gives up`() = runTest {
        val handler = JobStatusOutboxHandler(FakeJobRepository(), json)
        val entry = entry("""{"jobId":"j-1","newStatus":"not_a_real_status"}""")

        val outcome = handler.handle(entry)

        assertTrue(outcome is OutboxKindHandler.Outcome.GiveUp)
    }

    @Test fun `valid payload forwards timestamps as instants`() = runTest {
        val fake = FakeJobRepository()
        val handler = JobStatusOutboxHandler(fake, json)
        val entry = entry(
            """{"jobId":"j-2","newStatus":"InProgress","startedAtEpochMs":1700000000000}"""
        )

        val outcome = handler.handle(entry)

        assertTrue(outcome is OutboxKindHandler.Outcome.Success)
        val call = fake.updateStatusCalls.single()
        assertEquals("j-2", call.jobId)
        assertEquals(RepairJobStatus.InProgress, call.status)
        assertEquals(Instant.ofEpochMilli(1700000000000L), call.startedAt)
    }

    @Test fun `retry when repo returns failure`() = runTest {
        val fake = FakeJobRepository(nextResult = Result.failure(IOException("offline")))
        val handler = JobStatusOutboxHandler(fake, json)
        val entry = entry("""{"jobId":"j-3","newStatus":"Completed"}""")

        val outcome = handler.handle(entry)

        assertTrue(outcome is OutboxKindHandler.Outcome.Retry)
    }

    private fun entry(payload: String) = OutboxEntryEntity(
        id = 1L,
        kind = "job_status",
        payload = payload,
        createdAt = 0L,
    )

    private class FakeJobRepository(
        private val nextResult: Result<RepairJob>? = null,
    ) : RepairJobRepository {
        data class UpdateStatusCall(
            val jobId: String,
            val status: RepairJobStatus,
            val startedAt: Instant?,
            val completedAt: Instant?,
        )
        val updateStatusCalls = mutableListOf<UpdateStatusCall>()

        override suspend fun fetchOpenJobs(page: Int, pageSize: Int, query: String?): Result<List<RepairJob>> =
            Result.success(emptyList())

        override suspend fun fetchById(jobId: String): Result<RepairJob?> = Result.success(null)
        override suspend fun fetchAssignedToMe(): Result<List<RepairJob>> = Result.success(emptyList())
        override suspend fun fetchByIds(jobIds: Collection<String>): Result<List<RepairJob>> =
            Result.success(emptyList())

        override suspend fun fetchByHospitalUser(hospitalUserId: String): Result<List<RepairJob>> =
            Result.success(emptyList())

        override suspend fun create(draft: RepairJobDraft): Result<RepairJob> =
            Result.failure(UnsupportedOperationException())

        override suspend fun updateStatus(
            jobId: String,
            newStatus: RepairJobStatus,
            startedAt: Instant?,
            completedAt: Instant?,
        ): Result<RepairJob> {
            updateStatusCalls += UpdateStatusCall(jobId, newStatus, startedAt, completedAt)
            return nextResult ?: Result.success(stubJob(jobId, newStatus))
        }

        override suspend fun submitRating(
            jobId: String,
            role: RatingRole,
            stars: Int,
            review: String?,
        ): Result<RepairJob> = Result.failure(UnsupportedOperationException())

        private fun stubJob(jobId: String, status: RepairJobStatus) = RepairJob(
            id = jobId,
            jobNumber = null,
            title = "",
            issueDescription = "",
            equipmentCategory = RepairEquipmentCategory.Other,
            equipmentBrand = null,
            equipmentModel = null,
            status = status,
            urgency = RepairJobUrgency.Unknown,
            estimatedCostRupees = null,
            scheduledDate = null,
            scheduledTimeSlot = null,
            isAssignedToEngineer = false,
            engineerId = null,
            hospitalUserId = null,
            startedAtInstant = null,
            completedAtInstant = null,
            hospitalRating = null,
            hospitalReview = null,
            engineerRating = null,
            engineerReview = null,
            createdAtInstant = null,
            updatedAtInstant = null,
        )
    }
}
