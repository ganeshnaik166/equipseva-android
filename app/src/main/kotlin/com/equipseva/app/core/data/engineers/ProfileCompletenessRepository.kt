package com.equipseva.app.core.data.engineers

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Engineer profile-completeness meter (r504): a 0–100 score, the explicit
 * list of missing items, and a band. Called with no arg → the RPC defaults
 * to the caller's own profile (auth.uid()). Read-only; drives the
 * "Profile strength" nudge.
 */
@Singleton
class ProfileCompletenessRepository @Inject constructor(
    private val client: SupabaseClient,
) {
    @Serializable
    data class ProfileCompleteness(
        @SerialName("score") val score: Int = 0,
        @SerialName("missing_items") val missingItems: List<String> = emptyList(),
        @SerialName("band") val band: String = "incomplete", // incomplete | partial | complete
    )

    suspend fun fetch(): Result<ProfileCompleteness?> = runCatching {
        client.postgrest
            .rpc(function = "engineer_profile_completeness")
            .decodeList<ProfileCompleteness>()
            .firstOrNull()
    }
}
