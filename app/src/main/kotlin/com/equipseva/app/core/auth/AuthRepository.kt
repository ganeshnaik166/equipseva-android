package com.equipseva.app.core.auth

import kotlinx.coroutines.flow.Flow

interface AuthRepository {
    val sessionState: Flow<AuthSession>

    suspend fun signInWithEmailPassword(email: String, password: String): Result<Unit>
    suspend fun sendEmailOtp(email: String): Result<Unit>
    suspend fun verifyEmailOtp(email: String, token: String): Result<Unit>
    suspend fun signInWithGoogleIdToken(idToken: String, nonce: String?): Result<Unit>
    /**
     * Send a 6-digit OTP to the given phone number (E.164 format, e.g. +919999999999).
     * Requires the Supabase project to have a Phone provider (Twilio/MSG91) wired.
     */
    suspend fun sendPhoneOtp(phone: String): Result<Unit>
    suspend fun verifyPhoneOtp(phone: String, token: String): Result<Unit>
    suspend fun sendPasswordResetEmail(email: String): Result<Unit>
    suspend fun updatePassword(newPassword: String): Result<Unit>
    suspend fun updateEmail(newEmail: String): Result<Unit>
    suspend fun signOut(): Result<Unit>
    /**
     * Force-refresh the current JWT. Best-effort: returns failure if there's no
     * session or the refresh endpoint errors. Used before privileged RPCs (e.g.
     * create-razorpay-order) so the cached JWT doesn't go stale on long-idle apps.
     */
    suspend fun refreshSession(): Result<Unit>
}

sealed interface AuthSession {
    data object Unknown : AuthSession
    data object SignedOut : AuthSession
    data class SignedIn(val userId: String, val email: String?) : AuthSession
}
