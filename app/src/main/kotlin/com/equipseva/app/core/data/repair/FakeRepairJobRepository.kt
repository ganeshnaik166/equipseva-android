package com.equipseva.app.core.data.repair

import com.equipseva.app.core.data.demo.DemoSeed
import java.time.Instant
import javax.inject.Inject
import javax.inject.Singleton

/**
 * In-memory implementation backed by [DemoSeed]. Wired in by [RepairModule] when
 * `BuildConfig.DEMO_MODE` is true so the engineer feed / hospital active-jobs view
 * render rich sample data without hitting Supabase. Writes are no-ops and surface
 * an [UnsupportedOperationException] so screens don't appear to mutate state.
 */
@Singleton
class FakeRepairJobRepository @Inject constructor() : RepairJobRepository {

    private val seed: List<RepairJob> get() = DemoSeed.repairJobs

    override suspend fun fetchOpenJobs(
        page: Int,
        pageSize: Int,
        query: String?,
    ): Result<List<RepairJob>> {
        val q = query?.trim()?.lowercase().orEmpty()
        val open = seed
            .filter { it.status in RepairJobStatus.OpenForEngineers }
            .filter {
                q.isEmpty() ||
                    it.issueDescription.lowercase().contains(q) ||
                    (it.equipmentModel?.lowercase()?.contains(q) ?: false) ||
                    (it.equipmentBrand?.lowercase()?.contains(q) ?: false)
            }
            .sortedByDescending { it.createdAtInstant ?: Instant.EPOCH }
        val from = (page * pageSize).coerceAtMost(open.size)
        val to = (from + pageSize).coerceAtMost(open.size)
        return Result.success(open.subList(from, to))
    }

    override suspend fun fetchById(jobId: String): Result<RepairJob?> =
        Result.success(seed.firstOrNull { it.id == jobId })

    override suspend fun fetchAssignedToMe(): Result<List<RepairJob>> =
        Result.success(
            seed
                .filter { it.engineerId == DemoSeed.DEMO_ENGINEER_USER }
                .sortedByDescending { it.createdAtInstant ?: Instant.EPOCH },
        )

    override suspend fun fetchByIds(jobIds: Collection<String>): Result<List<RepairJob>> {
        val wanted = jobIds.toSet()
        return Result.success(seed.filter { it.id in wanted })
    }

    override suspend fun fetchByHospitalUser(hospitalUserId: String): Result<List<RepairJob>> =
        Result.success(
            seed
                .filter { it.hospitalUserId == hospitalUserId }
                .sortedByDescending { it.createdAtInstant ?: Instant.EPOCH },
        )

    override suspend fun create(draft: RepairJobDraft): Result<RepairJob> =
        Result.failure(UnsupportedOperationException("Demo mode: repair job create is disabled"))

    override suspend fun updateStatus(
        jobId: String,
        newStatus: RepairJobStatus,
        startedAt: Instant?,
        completedAt: Instant?,
    ): Result<RepairJob> =
        Result.failure(UnsupportedOperationException("Demo mode: repair job status updates are disabled"))

    override suspend fun submitRating(
        jobId: String,
        role: RatingRole,
        stars: Int,
        review: String?,
    ): Result<RepairJob> =
        Result.failure(UnsupportedOperationException("Demo mode: ratings are disabled"))
}
