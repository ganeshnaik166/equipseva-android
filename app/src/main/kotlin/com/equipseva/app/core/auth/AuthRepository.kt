package com.equipseva.app.core.auth

import kotlinx.coroutines.flow.Flow

interface AuthRepository {
    val sessionState: Flow<AuthSession>

    suspend fun signInWithEmailPassword(email: String, password: String): Result<Unit>
    suspend fun sendEmailOtp(email: String): Result<Unit>
    suspend fun verifyEmailOtp(email: String, token: String): Result<Unit>
    suspend fun signInWithGoogleIdToken(idToken: String, nonce: String?): Result<Unit>
    suspend fun signOut(): Result<Unit>
}

sealed interface AuthSession {
    data object Unknown : AuthSession
    data object SignedOut : AuthSession
    data class SignedIn(val userId: String, val email: String?) : AuthSession
}
