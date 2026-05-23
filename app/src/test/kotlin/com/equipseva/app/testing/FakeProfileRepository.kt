package com.equipseva.app.testing

import com.equipseva.app.core.data.profile.Profile
import com.equipseva.app.core.data.profile.ProfileRepository
import com.equipseva.app.features.auth.UserRole

/**
 * Hand-rolled fake for [ProfileRepository] used by JVM ViewModel tests.
 *
 * Same shape as [FakeAuthRepository]:
 *   * every suspend method defaults to a sensible success;
 *   * each call is recorded into a per-method `mutableListOf` for
 *     assertion;
 *   * per-method `xxxResult` knobs let a test flip a single path to
 *     failure.
 *
 * Use via `@UninstallModules(ProfileModule::class) + @BindValue` for
 * Hilt-aware tests, or just construct directly for VM tests that
 * instantiate the VM with a plain Kotlin constructor (the more common
 * pattern — see TESTING.md).
 */
class FakeProfileRepository : ProfileRepository {

    // --- recorded calls -------------------------------------------------

    data class UpdateRoleCall(val userId: String, val role: UserRole)
    data class UpdateBasicInfoCall(
        val userId: String,
        val fullName: String?,
        val phone: String?,
        val email: String?,
        val avatarUrl: String?,
    )

    val fetchByIdCalls = mutableListOf<String>()
    val updateRoleCalls = mutableListOf<UpdateRoleCall>()
    val updateBasicInfoCalls = mutableListOf<UpdateBasicInfoCall>()
    val fetchDisplayNamesCalls = mutableListOf<List<String>>()
    val addRoleCalls = mutableListOf<String>()
    val setActiveRoleCalls = mutableListOf<String>()

    // --- knob-style result overrides ------------------------------------

    /** When non-null, every `fetchById` returns this. */
    var fetchByIdResult: Result<Profile?>? = null
    var updateRoleResult: Result<Unit>? = null
    var updateBasicInfoResult: Result<Unit>? = null
    var fetchDisplayNamesResult: Result<Map<String, String>>? = null
    var addRoleResult: Result<Unit>? = null
    var setActiveRoleResult: Result<Unit>? = null

    // --- ProfileRepository impl -----------------------------------------

    override suspend fun fetchById(userId: String): Result<Profile?> {
        fetchByIdCalls += userId
        return fetchByIdResult ?: Result.success(null)
    }

    override suspend fun updateRole(userId: String, role: UserRole): Result<Unit> {
        updateRoleCalls += UpdateRoleCall(userId, role)
        return updateRoleResult ?: Result.success(Unit)
    }

    override suspend fun updateBasicInfo(
        userId: String,
        fullName: String?,
        phone: String?,
        email: String?,
        avatarUrl: String?,
    ): Result<Unit> {
        updateBasicInfoCalls += UpdateBasicInfoCall(userId, fullName, phone, email, avatarUrl)
        return updateBasicInfoResult ?: Result.success(Unit)
    }

    override suspend fun fetchDisplayNames(userIds: List<String>): Result<Map<String, String>> {
        fetchDisplayNamesCalls += userIds.toList()
        return fetchDisplayNamesResult ?: Result.success(emptyMap())
    }

    override suspend fun addRole(roleKey: String): Result<Unit> {
        addRoleCalls += roleKey
        return addRoleResult ?: Result.success(Unit)
    }

    override suspend fun setActiveRole(roleKey: String): Result<Unit> {
        setActiveRoleCalls += roleKey
        return setActiveRoleResult ?: Result.success(Unit)
    }
}
