package com.equipseva.app.core.auth

import kotlinx.coroutines.flow.Flow

/**
 * Phone-OTP-only auth contract. Email + password + Google sign-in were
 * stripped — Supabase phone (Twilio/MSG91) is the single sign-in path.
 *
 * `sendEmailOtp` + `verifyEmailOtp` survive **only** for the engineer's
 * email-verify sheet inside KYC Step 1. They are not used for sign-in.
 */
interface AuthRepository {
    val sessionState: Flow<AuthSession>

    /**
     * Send a 6-digit OTP to the given phone number (E.164 format, e.g. +919999999999).
     * Requires the Supabase project to have a Phone provider (Twilio/MSG91) wired.
     */
    suspend fun sendPhoneOtp(phone: String): Result<Unit>
    suspend fun verifyPhoneOtp(phone: String, token: String): Result<Unit>

    /**
     * Attach (or change) a phone number on the *currently signed-in* user.
     * Used by [verifyPhoneAdd] to confirm the Supabase-fired SMS to the new
     * number. Does NOT replace the user's session.
     */
    suspend fun requestPhoneAdd(phone: String): Result<Unit>
    suspend fun verifyPhoneAdd(phone: String, token: String): Result<Unit>

    /**
     * Email OTP — KEPT for KYC Step 1's "verify your email" sheet only.
     * Not a sign-in path. Engineers + hospitals authenticate via phone.
     */
    suspend fun sendEmailOtp(email: String): Result<Unit>
    suspend fun verifyEmailOtp(email: String, token: String): Result<Unit>

    /**
     * Stamp a new email onto the *currently signed-in* user. Supabase fires
     * a confirmation message to the new address. Used by KYC Step 1's
     * email-change row before the inline OTP sheet runs.
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
