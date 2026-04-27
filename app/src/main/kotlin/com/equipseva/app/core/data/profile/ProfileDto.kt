package com.equipseva.app.core.data.profile

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** Wire shape for `public.profiles`, with embedded `organizations(name, city, state)`. */
@Serializable
data class ProfileDto(
    val id: String,
    val email: String? = null,
    val phone: String? = null,
    @SerialName("full_name") val fullName: String? = null,
    @SerialName("avatar_url") val avatarUrl: String? = null,
    val role: String? = null,
    @SerialName("roles") val roles: List<String>? = null,
    @SerialName("active_role") val activeRoleKey: String? = null,
    @SerialName("organization_id") val organizationId: String? = null,
    @SerialName("is_active") val isActive: Boolean = true,
    @SerialName("onboarding_completed") val onboardingCompleted: Boolean = false,
    @SerialName("role_confirmed") val roleConfirmed: Boolean = false,
    @SerialName("buyer_kyc_status") val buyerKycStatus: String? = null,
    // Mirrored from auth.users.{email,phone}_confirmed_at via DB trigger
    // (migration 20260428060000). Lets KYC Step 1 surface a "Verify" CTA
    // without round-tripping the auth schema on every load.
    @SerialName("email_verified") val emailVerified: Boolean = false,
    @SerialName("phone_verified") val phoneVerified: Boolean = false,
    val organizations: OrganizationSummaryDto? = null,
)

@Serializable
data class OrganizationSummaryDto(
    val name: String? = null,
    val city: String? = null,
    val state: String? = null,
)
