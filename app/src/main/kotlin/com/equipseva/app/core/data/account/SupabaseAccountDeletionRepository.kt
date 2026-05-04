package com.equipseva.app.core.data.account

import com.equipseva.app.core.security.TamperPolicy
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
    private val tamperPolicy: TamperPolicy,
) : AccountDeletionRepository {

    override suspend fun deleteMyAccount(reason: String?): Result<Unit> = runCatching {
        // Anti-tamper gate: account deletion is the most destructive irreversible
        // action a user can trigger. A Frida-hooked or repackaged APK that bypasses
        // the in-app confirmation sheet should still be blocked server-side via
        // Play Integrity attestation before delete_my_account fires.
        tamperPolicy.enforce(action = "delete_account").getOrThrow()

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
