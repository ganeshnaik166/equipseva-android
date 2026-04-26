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
    val organizations: OrganizationSummaryDto? = null,
)

@Serializable
data class OrganizationSummaryDto(
    val name: String? = null,
    val city: String? = null,
    val state: String? = null,
)
