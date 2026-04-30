package com.equipseva.app.core.auth

import kotlinx.coroutines.flow.Flow

/**
 * Email + password is the primary sign-in path. Google sign-in (via Credential
 * Manager + Supabase OIDC) is the alternative. Forgot-password fires a Supabase
 * reset email; the post-login change-password + change-email flows mirror it.
 *
 * Phone-OTP sign-in was dropped. Phone is still collected as a contact
 * attribute for engineers (verified via `requestPhoneAdd` / `verifyPhoneAdd`),
 * but you can't authenticate with a phone number anymore.
 *
 * Email OTP (`sendEmailOtp` / `verifyEmailOtp`) survives **only** for the
 * engineer's email-verify sheet inside KYC Step 1.
 */
interface AuthRepository {
    val sessionState: Flow<AuthSession>

    suspend fun signInWithEmailPassword(email: String, password: String): Result<Unit>
    suspend fun signUpWithEmailPassword(email: String, password: String, fullName: String): Result<Unit>
    suspend fun signInWithGoogleIdToken(idToken: String, nonce: String?): Result<Unit>

    suspend fun sendPasswordResetEmail(email: String): Result<Unit>

    /**
     * Updates the password after re-authenticating the current session by
     * verifying [currentPassword]. Surfaces [InvalidCurrentPasswordException]
     * inside Result.failure when the current password is wrong so the UI can
     * attribute the error to the right input. Without the re-auth check an
     * unlocked-device attacker could lock the legitimate owner out.
     */
    suspend fun updatePassword(currentPassword: String, newPassword: String): Result<Unit>

    /**
     * Email OTP — KEPT for KYC Step 1's "verify your email" sheet only. Not a
     * sign-in path.
     */
    suspend fun sendEmailOtp(email: String): Result<Unit>
    suspend fun verifyEmailOtp(email: String, token: String): Result<Unit>

    /**
     * Attach (or change) a phone number on the *currently signed-in* user.
     * Used during KYC so engineers can be reached by hospitals. Pair with
     * [verifyPhoneAdd] to confirm the Supabase-fired SMS. Does NOT replace
     * the user's session.
     */
    suspend fun requestPhoneAdd(phone: String): Result<Unit>
    suspend fun verifyPhoneAdd(phone: String, token: String): Result<Unit>

    /**
     * Stamp a new email onto the *currently signed-in* user. Supabase fires
     * a confirmation message to the new address.
     */
    suspend fun updateEmail(newEmail: String): Result<Unit>

    suspend fun signOut(): Result<Unit>

    /**
     * Force-refresh the current JWT. Best-effort: returns failure if there's no
     * session or the refresh endpoint errors. Used before privileged RPCs.
     */
    suspend fun refreshSession(): Result<Unit>
}

sealed interface AuthSession {
    data object Unknown : AuthSession
    data object SignedOut : AuthSession
    data class SignedIn(val userId: String, val email: String?) : AuthSession
}

/** Thrown by [AuthRepository.updatePassword] when the supplied current
 *  password fails the re-auth check, so the screen can attribute the error
 *  to the current-password field instead of the new-password field. */
class InvalidCurrentPasswordException : RuntimeException("Current password is incorrect.")
