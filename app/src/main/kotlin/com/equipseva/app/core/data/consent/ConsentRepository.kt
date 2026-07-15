package com.equipseva.app.core.data.consent

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Read-only DPDP consent state for the current user via current_consents()
 * (round 485) — auth.uid()-scoped. Returns the LATEST log entry per consent
 * type (granted or revoked) plus the exact policy version and timestamp, which
 * DPDP requires us to be able to show the user. Concrete @Singleton with
 * constructor injection; no @Binds module needed.
 */
@Singleton
class ConsentRepository @Inject constructor(
    private val client: SupabaseClient,
) {
    @Serializable
    data class ConsentRow(
        @SerialName("consent_type") val consentType: String,
        @SerialName("document_version") val documentVersion: String = "",
        // granted | revoked
        @SerialName("action") val action: String = "granted",
        @SerialName("granted_at") val grantedAt: String? = null,
    )

    suspend fun fetch(): Result<List<ConsentRow>> = runCatching {
        client.postgrest
            .rpc(function = "current_consents")
            .decodeList<ConsentRow>()
    }
}
