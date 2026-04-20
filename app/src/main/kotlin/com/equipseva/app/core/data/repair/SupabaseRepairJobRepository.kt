package com.equipseva.app.core.data.repair

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.query.Order
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class SupabaseRepairJobRepository @Inject constructor(
    private val client: SupabaseClient,
) : RepairJobRepository {

    override suspend fun fetchOpenJobs(
        page: Int,
        pageSize: Int,
        query: String?,
    ): Result<List<RepairJob>> = runCatching {
        val from = (page.coerceAtLeast(0)).toLong() * pageSize
        val to = from + pageSize - 1

        client.from(TABLE).select {
            filter {
                // Engineer feed shows jobs that are still actionable from the outside
                // — i.e. not yet wrapped up or killed. RLS decides which of these
                // rows this engineer is actually allowed to see.
                isIn("status", RepairJobStatus.OpenForEngineers.map { it.storageKey })
                if (!query.isNullOrBlank()) {
                    val needle = query.trim().sanitizeForIlike()
                    or {
                        ilike("issue_description", "%$needle%")
                        ilike("equipment_brand", "%$needle%")
                        ilike("equipment_model", "%$needle%")
                    }
                }
            }
            // Most recent first — the feed is a worklist, not an archive.
            order("created_at", order = Order.DESCENDING)
            range(from, to)
        }.decodeList<RepairJobDto>().map(RepairJobDto::toDomain)
    }

    override suspend fun fetchById(jobId: String): Result<RepairJob?> = runCatching {
        client.from(TABLE).select {
            filter {
                eq("id", jobId)
            }
            limit(count = 1)
        }.decodeList<RepairJobDto>().firstOrNull()?.toDomain()
    }

    override suspend fun fetchAssignedToMe(): Result<List<RepairJob>> = runCatching {
        val userId = requireNotNull(client.auth.currentUserOrNull()?.id) {
            "No authenticated user"
        }
        client.from(TABLE).select {
            filter { eq("engineer_id", userId) }
            order("updated_at", order = Order.DESCENDING)
        }.decodeList<RepairJobDto>().map(RepairJobDto::toDomain)
    }

    override suspend fun fetchByIds(jobIds: Collection<String>): Result<List<RepairJob>> = runCatching {
        if (jobIds.isEmpty()) return@runCatching emptyList<RepairJob>()
        client.from(TABLE).select {
            filter { isIn("id", jobIds.toList()) }
        }.decodeList<RepairJobDto>().map(RepairJobDto::toDomain)
    }

    override suspend fun fetchByHospitalUser(hospitalUserId: String): Result<List<RepairJob>> = runCatching {
        client.from(TABLE).select {
            filter { eq("hospital_user_id", hospitalUserId) }
            order("created_at", order = Order.DESCENDING)
        }.decodeList<RepairJobDto>().map(RepairJobDto::toDomain)
    }

    override suspend fun create(draft: RepairJobDraft): Result<RepairJob> = runCatching {
        val payload = RepairJobInsertDto(
            hospitalUserId = draft.hospitalUserId,
            hospitalOrgId = draft.hospitalOrgId?.takeIf { it.isNotBlank() },
            equipmentType = draft.equipmentCategory.storageKey,
            equipmentBrand = draft.equipmentBrand?.takeIf { it.isNotBlank() },
            equipmentModel = draft.equipmentModel?.takeIf { it.isNotBlank() },
            urgency = draft.urgency.storageKey.takeIf { it.isNotBlank() },
            issueDescription = draft.issueDescription,
        )
        client.from(TABLE).insert(payload) {
            select()
        }.decodeSingle<RepairJobDto>().toDomain()
    }

    private fun String.sanitizeForIlike(): String =
        replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")

    private companion object {
        const val TABLE = "repair_jobs"
    }
}
