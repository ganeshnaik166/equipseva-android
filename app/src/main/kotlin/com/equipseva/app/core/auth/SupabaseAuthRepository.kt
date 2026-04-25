package com.equipseva.app.core.auth

import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.providers.Google
import io.github.jan.supabase.auth.providers.builtin.Email
import io.github.jan.supabase.auth.providers.builtin.IDToken
import io.github.jan.supabase.auth.providers.builtin.OTP
import io.github.jan.supabase.auth.status.SessionStatus
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class SupabaseAuthRepository @Inject constructor(
    private val client: SupabaseClient,
) : AuthRepository {

    override val sessionState: Flow<AuthSession> =
        client.auth.sessionStatus.map { status ->
            when (status) {
                is SessionStatus.Authenticated -> {
                    val user = status.session.user
                    AuthSession.SignedIn(
                        userId = user?.id ?: "",
                        email = user?.email,
                    )
                }
                is SessionStatus.NotAuthenticated -> AuthSession.SignedOut
                is SessionStatus.Initializing -> AuthSession.Unknown
                is SessionStatus.RefreshFailure -> AuthSession.SignedOut
            }
        }

    override suspend fun signInWithEmailPassword(email: String, password: String): Result<Unit> = runCatching {
        client.auth.signInWith(Email) {
            this.email = email
            this.password = password
        }
    }

    override suspend fun sendEmailOtp(email: String): Result<Unit> = runCatching {
        client.auth.signInWith(OTP) {
            this.email = email
        }
    }

    override suspend fun verifyEmailOtp(email: String, token: String): Result<Unit> = runCatching {
        client.auth.verifyEmailOtp(
            type = io.github.jan.supabase.auth.OtpType.Email.EMAIL,
            email = email,
            token = token,
        )
    }

    override suspend fun signInWithGoogleIdToken(idToken: String, nonce: String?): Result<Unit> = runCatching {
        client.auth.signInWith(IDToken) {
            this.idToken = idToken
            this.provider = Google
            this.nonce = nonce
        }
    }

    override suspend fun sendPhoneOtp(phone: String): Result<Unit> = runCatching {
        client.auth.signInWith(OTP) {
            this.phone = phone
        }
    }

    override suspend fun verifyPhoneOtp(phone: String, token: String): Result<Unit> = runCatching {
        client.auth.verifyPhoneOtp(
            type = io.github.jan.supabase.auth.OtpType.Phone.SMS,
            phone = phone,
            token = token,
        )
    }

    override suspend fun sendPasswordResetEmail(email: String): Result<Unit> = runCatching {
        client.auth.resetPasswordForEmail(email)
    }

    override suspend fun updatePassword(newPassword: String): Result<Unit> = runCatching {
        client.auth.updateUser {
            password = newPassword
        }
        Unit
    }

    override suspend fun updateEmail(newEmail: String): Result<Unit> = runCatching {
        client.auth.updateUser {
            email = newEmail
        }
        Unit
    }

    override suspend fun signOut(): Result<Unit> = runCatching {
        client.auth.signOut()
    }
}
