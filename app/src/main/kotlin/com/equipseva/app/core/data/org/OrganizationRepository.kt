package com.equipseva.app.core.data.org

import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.profile.ProfileRepository
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.coroutines.flow.first
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject

/**
 * The caller's own organization's full record (round 428): organization_full
 * returns the PII/compliance columns (GSTIN, PAN, GST/trade-licence URLs) that
 * the column-level SELECT grants withhold from a plain read. SECURITY DEFINER,
 * authenticated-granted, gated to active members of the org (or founder). The
 * org id is resolved from the caller's profile.
 */
@Singleton
class OrganizationRepository @Inject constructor(
    private val client: SupabaseClient,
    private val authRepository: AuthRepository,
    private val profileRepository: ProfileRepository,
) {
    @Serializable
    data class OrgDetail(
        @SerialName("name") val name: String = "",
        @SerialName("type") val type: String? = null,
        @SerialName("city") val city: String? = null,
        @SerialName("state") val state: String? = null,
        @SerialName("verification_status") val verificationStatus: String? = null,
        @SerialName("accreditation") val accreditation: String? = null,
        @SerialName("beds_count") val bedsCount: Int? = null,
        @SerialName("gstin") val gstin: String? = null,
        @SerialName("pan") val pan: String? = null,
        @SerialName("gst_certificate_url") val gstCertificateUrl: String? = null,
        @SerialName("trade_licence_url") val tradeLicenceUrl: String? = null,
    )

    /** The signed-in user's organization, or null when they have no org. */
    suspend fun myOrganization(): Result<OrgDetail?> = runCatching {
        val session = authRepository.sessionState.first { it !is AuthSession.Unknown }
        val uid = (session as? AuthSession.SignedIn)?.userId ?: return@runCatching null
        val orgId = profileRepository.fetchById(uid).getOrNull()?.organizationId ?: return@runCatching null
        client.postgrest.rpc(
            function = "organization_full",
            parameters = buildJsonObject { put("p_org_id", JsonPrimitive(orgId)) },
        ).decodeList<OrgDetail>().firstOrNull()
    }
}
