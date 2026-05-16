package com.equipseva.app.core.data.profile

import com.equipseva.app.features.auth.UserRole
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.query.Columns
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class SupabaseProfileRepository @Inject constructor(
    private val client: SupabaseClient,
) : ProfileRepository {

    override suspend fun fetchById(userId: String): Result<Profile?> = runCatching {
        // First try the full SELECT *with* the embedded organization summary.
        // Works only when userId == auth.uid() since profiles RLS is now
        // self-only. The org embed depends on column-level grants on the
        // organizations table; if those fail we fall back to a base SELECT
        // so the user's own profile still loads (org name is decorative).
        val full = runCatching {
            client.from(TABLE).select(
                columns = Columns.raw("$BASE_COLUMNS, organizations(name, city, state)"),
            ) {
                filter { eq("id", userId) }
                limit(count = 1)
            }.decodeList<ProfileDto>().firstOrNull()?.toDomain()
        }.getOrNull() ?: runCatching {
            client.from(TABLE).select(columns = Columns.raw(BASE_COLUMNS)) {
                filter { eq("id", userId) }
                limit(count = 1)
            }.decodeList<ProfileDto>().firstOrNull()?.toDomain()
        }.getOrNull()

        if (full != null) return@runCatching full

        // Fallback: cross-user lookup (chat counterpart, conversation peers)
        // hits the SECURITY DEFINER RPC that returns ONLY id+full_name+
        // avatar_url. We synthesise a Profile from those three fields; PII
        // (email, phone, organization) stays hidden.
        val minimal = fetchMinimal(listOf(userId))[userId]
        minimal?.let {
            Profile(
                id = it.id,
                email = null,
                phone = null,
                fullName = it.fullName,
                avatarUrl = it.avatarUrl,
                role = null,
                rawRoleKey = null,
                roleConfirmed = false,
                onboardingCompleted = false,
                isActive = true,
                organizationId = null,
                organizationName = null,
                organizationCity = null,
                organizationState = null,
            )
        }
    }

    /**
     * SECURITY DEFINER RPC that returns only the safe public fields for the
     * given user ids. Returns an empty map when no callers match. Used by
     * [fetchById] (cross-user fallback) and [fetchDisplayNames].
     */
    private suspend fun fetchMinimal(userIds: List<String>): Map<String, MinimalProfileDto> {
        if (userIds.isEmpty()) return emptyMap()
        return client.postgrest.rpc(
            function = "public_profiles_minimal",
            parameters = buildJsonObject {
                put("p_user_ids", JsonArray(userIds.map { JsonPrimitive(it) }))
            },
        ).decodeList<MinimalProfileDto>().associateBy { it.id }
    }

    @Serializable
    private data class MinimalProfileDto(
        val id: String,
        @SerialName("full_name") val fullName: String? = null,
        @SerialName("avatar_url") val avatarUrl: String? = null,
    )

    override suspend fun updateRole(userId: String, role: UserRole): Result<Unit> = runCatching {
        // Mirror updateBasicInfo: reject a caller that hands in someone
        // else's user id. RLS catches the row-write server-side; the
        // local guard means a logic bug (stale uid past a token rotation,
        // mis-routed caller) surfaces as an exception instead of a
        // silent no-op against an empty filtered set.
        val authUid = client.auth.currentUserOrNull()?.id
        require(authUid != null && authUid == userId) {
            "updateRole refused: signed-in user does not match target id"
        }
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

    override suspend fun updateBasicInfo(
        userId: String,
        fullName: String?,
        phone: String?,
        email: String?,
        avatarUrl: String?,
    ): Result<Unit> = runCatching {
        // Defense-in-depth: reject calls that try to mutate someone else's
        // profile before the network round-trip. RLS would also block the
        // row update server-side, but a fail-fast here means callers can't
        // accidentally race a stale userId past a token refresh, and a
        // logic bug that mis-routes a user-id stays local + visible
        // instead of silently no-op'ing against Postgres.
        val authUid = client.auth.currentUserOrNull()?.id
        require(authUid != null && authUid == userId) {
            "updateBasicInfo refused: signed-in user does not match target id"
        }
        // Omit null fields entirely so Postgrest leaves the column unchanged.
        // Setting a key to JsonNull writes NULL to the row, which violates
        // profiles.full_name NOT NULL when callers update only one field
        // (e.g. AddPhoneScreen). Letting null sail through historically
        // wiped full_name on every phone save.
        //
        // Round 289 — repo-boundary `.take(N)` to match the server CHECK
        // added in 20260704700000 (full_name <= 200, phone <= 20). The
        // UI already validates phone shape and clamps full_name on edit
        // screens, but a stale ViewModel state or a future bulk path
        // would otherwise hit the server CHECK with a confusing 23514.
        client.from(TABLE).update(
            buildJsonObject {
                if (fullName != null) put("full_name", JsonPrimitive(fullName.take(200)))
                if (phone != null) put("phone", JsonPrimitive(phone.take(20)))
                if (email != null) put("email", JsonPrimitive(email))
                if (avatarUrl != null) put("avatar_url", JsonPrimitive(avatarUrl))
            },
        ) {
            filter { eq("id", userId) }
        }
        Unit
    }

    override suspend fun fetchDisplayNames(
        userIds: List<String>,
    ): Result<Map<String, String>> = runCatching {
        val distinct = userIds.filter { it.isNotBlank() }.distinct()
        if (distinct.isEmpty()) return@runCatching emptyMap()
        // RPC returns only id + full_name + avatar_url. Falls back to
        // "User" if the row's full_name is blank (we don't expose email
        // anymore so the previous `email.substringBefore('@')` fallback is
        // gone — slightly less personalised but no PII leak).
        fetchMinimal(distinct).mapValues { (_, dto) ->
            dto.fullName?.takeIf { it.isNotBlank() } ?: "User"
        }
    }

    override suspend fun addRole(roleKey: String): Result<Unit> = runCatching {
        client.postgrest.rpc(
            function = "add_role",
            parameters = buildJsonObject {
                put("p_role", JsonPrimitive(roleKey))
            },
        )
        Unit
    }

    override suspend fun setActiveRole(roleKey: String): Result<Unit> = runCatching {
        client.postgrest.rpc(
            function = "set_active_role",
            parameters = buildJsonObject {
                put("p_role", JsonPrimitive(roleKey))
            },
        )
        Unit
    }

    private companion object {
        const val TABLE = "profiles"
        const val BASE_COLUMNS =
            "id,email,phone,full_name,avatar_url,role,roles,active_role,organization_id," +
                "is_active,onboarding_completed,role_confirmed,buyer_kyc_status," +
                "email_verified,phone_verified"
    }
}
