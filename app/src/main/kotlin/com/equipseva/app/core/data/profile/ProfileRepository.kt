package com.equipseva.app.core.data.profile

import com.equipseva.app.features.auth.UserRole

interface ProfileRepository {
    /** Read the signed-in user's profile (with org name embedded). */
    suspend fun fetchById(userId: String): Result<Profile?>

    /**
     * Persist the role choice and mark `role_confirmed = true`.
     * RLS allows the user to update only their own row.
     */
    suspend fun updateRole(userId: String, role: UserRole): Result<Unit>
}
