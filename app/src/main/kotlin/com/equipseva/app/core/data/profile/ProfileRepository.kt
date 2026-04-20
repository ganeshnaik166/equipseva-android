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

    /** Update the signed-in user's display name + phone. Either can be null to clear. */
    suspend fun updateBasicInfo(userId: String, fullName: String?, phone: String?): Result<Unit>

    /**
     * Bulk-resolve display names for a set of user ids. Missing ids are simply
     * absent from the returned map. Used by hospital-side bid lists to label
     * each bid with the engineer's name.
     */
    suspend fun fetchDisplayNames(userIds: List<String>): Result<Map<String, String>>
}
