package com.equipseva.app.core.data.account

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class SupabaseAccountDeletionRepository @Inject constructor(
    private val client: SupabaseClient,
) : AccountDeletionRepository {

    override suspend fun deleteMyAccount(reason: String?): Result<Unit> = runCatching {
        val trimmed = reason?.trim()?.takeIf { it.isNotEmpty() }
        client.postgrest.rpc(
            function = "delete_my_account",
            parameters = buildJsonObject {
                put("p_reason", if (trimmed != null) JsonPrimitive(trimmed) else JsonNull)
            },
        )
        Unit
    }
}
