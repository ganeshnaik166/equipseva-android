package com.equipseva.app.core.data.profile

import com.equipseva.app.features.auth.UserRole
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.query.Columns
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class SupabaseProfileRepository @Inject constructor(
    private val client: SupabaseClient,
) : ProfileRepository {

    override suspend fun fetchById(userId: String): Result<Profile?> = runCatching {
        client.from(TABLE).select(
            // Embed the FK'd organization summary in a single round-trip.
            columns = Columns.raw("$BASE_COLUMNS, organizations(name, city, state)"),
        ) {
            filter { eq("id", userId) }
            limit(count = 1)
        }.decodeList<ProfileDto>().firstOrNull()?.toDomain()
    }

    override suspend fun updateRole(userId: String, role: UserRole): Result<Unit> = runCatching {
        client.from(TABLE).update(
            buildJsonObject {
                put("role", JsonPrimitive(role.storageKey))
                put("role_confirmed", JsonPrimitive(true))
            },
        ) {
            filter { eq("id", userId) }
        }
        Unit
    }

    private companion object {
        const val TABLE = "profiles"
        const val BASE_COLUMNS =
            "id,email,phone,full_name,avatar_url,role,organization_id," +
                "is_active,onboarding_completed,role_confirmed"
    }
}
