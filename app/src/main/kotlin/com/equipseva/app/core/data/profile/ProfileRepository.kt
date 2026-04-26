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

    /**
     * Append a role to the caller's `profiles.roles[]` and set it active. Calls
     * the `add_role(p_role)` RPC which is SECURITY DEFINER on the server and
     * validates the role key against the user_role enum.
     */
    suspend fun addRole(roleKey: String): Result<Unit>

    /**
     * Flip `profiles.active_role` to a role the caller already owns. Calls the
     * `set_active_role(p_role)` RPC; raises if the user doesn't have the role.
     */
    suspend fun setActiveRole(roleKey: String): Result<Unit>
}
