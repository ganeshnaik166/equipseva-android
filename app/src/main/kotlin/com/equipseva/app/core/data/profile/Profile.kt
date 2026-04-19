package com.equipseva.app.core.data.profile

import com.equipseva.app.features.auth.UserRole

data class Profile(
    val id: String,
    val email: String?,
    val phone: String?,
    val fullName: String?,
    val avatarUrl: String?,
    val role: UserRole?,
    val rawRoleKey: String?,
    val roleConfirmed: Boolean,
    val onboardingCompleted: Boolean,
    val isActive: Boolean,
    val organizationId: String?,
    val organizationName: String?,
    val organizationCity: String?,
    val organizationState: String?,
) {
    val displayName: String
        get() = fullName?.takeIf { it.isNotBlank() }
            ?: email?.substringBefore('@')
            ?: "User"

    val locationLine: String?
        get() = listOfNotNull(organizationCity, organizationState)
            .filter { it.isNotBlank() }
            .joinToString(", ")
            .ifBlank { null }
}

internal fun ProfileDto.toDomain(): Profile = Profile(
    id = id,
    email = email,
    phone = phone,
    fullName = fullName,
    avatarUrl = avatarUrl,
    role = role?.let { key -> UserRole.entries.firstOrNull { it.storageKey == key } },
    rawRoleKey = role,
    roleConfirmed = roleConfirmed,
    onboardingCompleted = onboardingCompleted,
    isActive = isActive,
    organizationId = organizationId,
    organizationName = organizations?.name,
    organizationCity = organizations?.city,
    organizationState = organizations?.state,
)
