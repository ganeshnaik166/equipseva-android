package com.equipseva.app.core.data.orgroles

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.query.Columns
import kotlinx.serialization.Serializable
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class SupabaseOrgRoleRepository @Inject constructor(
    private val client: SupabaseClient,
) : OrgRoleRepository {

    @Serializable
    private data class IdRow(val id: String)

    @Serializable
    private data class ManufacturerCategoriesRow(
        val id: String,
        @kotlinx.serialization.SerialName("equipment_categories")
        val equipmentCategories: List<String>? = null,
    )

    override suspend fun manufacturerIdForOrg(organizationId: String): Result<String?> = runCatching {
        client.from("manufacturers").select(columns = Columns.raw("id")) {
            filter { eq("organization_id", organizationId) }
            limit(count = 1)
        }.decodeList<IdRow>().firstOrNull()?.id
    }

    override suspend fun manufacturerCategoriesForOrg(organizationId: String): Result<List<String>> = runCatching {
        val row = client.from("manufacturers").select(columns = Columns.raw("id, equipment_categories")) {
            filter { eq("organization_id", organizationId) }
            limit(count = 1)
        }.decodeList<ManufacturerCategoriesRow>().firstOrNull()
        row?.equipmentCategories.orEmpty()
    }

    override suspend fun logisticsPartnerIdForUser(userId: String): Result<String?> = runCatching {
        client.from("logistics_partners").select(columns = Columns.raw("id")) {
            filter { eq("user_id", userId) }
            limit(count = 1)
        }.decodeList<IdRow>().firstOrNull()?.id
    }
}
