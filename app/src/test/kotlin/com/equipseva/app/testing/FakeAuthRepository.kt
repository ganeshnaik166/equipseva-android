package com.equipseva.app.testing

import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.auth.InvalidCurrentPasswordException
import com.equipseva.app.core.auth.SignUpOutcome
import com.equipseva.app.features.auth.UserRole
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.io.IOException

/**
 * Hand-rolled fake for [AuthRepository] used by JVM ViewModel tests.
 * Defaults to success on every suspend call so a happy-path test can
 * construct the fake with no arguments. Each call is recorded so the
 * test can assert what was actually invoked.
 *
 * Why a hand-rolled fake instead of MockK on the interface?
 *   * The interface is small (~12 methods) so the boilerplate is
 *     bounded.
 *   * A real class with mutable defaults is easier to mutate
 *     mid-test (e.g. switch sessionState from SignedOut → SignedIn
 *     between assertions).
 *   * The recorded-calls shape lets tests assert "exactly one call
 *     with these args" without `verify { ... wasNotCalled }`
 *     ceremony.
 *
 * Bind via:
 *
 *   @HiltAndroidTest
 *   @UninstallModules(AuthModule::class)
 *   class FooViewModelTest {
 *       @BindValue @JvmField val authRepository: AuthRepository = FakeAuthRepository()
 *       ...
 *   }
 */
class FakeAuthRepository(
    initialSession: AuthSession = AuthSession.SignedOut,
) : AuthRepository {

    private val _sessionState = MutableStateFlow<AuthSession>(initialSession)
    override val sessionState: Flow<AuthSession> = _sessionState.asStateFlow()

    /** Mutate from inside a test to drive flow re-emission. */
    fun setSession(next: AuthSession) {
        _sessionState.value = next
    }

    // --- recorded calls -------------------------------------------------

    data class SignInCall(val email: String, val password: String)
    data class SignUpCall(
        val email: String,
        val password: String,
        val fullName: String,
        val role: UserRole,
    )
    data class GoogleSignInCall(val idToken: String, val nonce: String?)
    data class UpdatePasswordCall(val current: String, val newPwd: String)
    data class UpdateEmailCall(val current: String, val newEmail: String)
    data class PhoneAddCall(val phone: String)
    data class VerifyPhoneCall(val phone: String, val token: String)
    data class VerifyEmailOtpCall(val email: String, val token: String)

    val signInCalls = mutableListOf<SignInCall>()
    val signUpCalls = mutableListOf<SignUpCall>()
    val googleCalls = mutableListOf<GoogleSignInCall>()
    val resetEmails = mutableListOf<String>()
    val updatePasswordCalls = mutableListOf<UpdatePasswordCall>()
    val verifyCurrentPasswordCalls = mutableListOf<String>()
    val updateEmailCalls = mutableListOf<UpdateEmailCall>()
    val updateEmailDuringKycCalls = mutableListOf<String>()
    val emailOtpCalls = mutableListOf<String>()
    val verifyEmailOtpCalls = mutableListOf<VerifyEmailOtpCall>()
    val phoneAddCalls = mutableListOf<PhoneAddCall>()
    val verifyPhoneAddCalls = mutableListOf<VerifyPhoneCall>()
    var signOutCount = 0
        private set
    var refreshSessionCount = 0
        private set

    // --- knob-style result overrides ------------------------------------

    /** When non-null, every `sendPasswordResetEmail` returns this. */
    var resetEmailResult: Result<Unit>? = null
    var signInResult: Result<Unit>? = null
    var signUpResult: Result<SignUpOutcome>? = null
    var googleResult: Result<Unit>? = null
    var updatePasswordResult: Result<Unit>? = null
    var verifyCurrentPasswordResult: Result<Unit>? = null
    var updateEmailResult: Result<Unit>? = null
    var emailOtpResult: Result<Unit>? = null

    // --- AuthRepository impl -------------------------------------------

    override suspend fun signInWithEmailPassword(email: String, password: String): Result<Unit> {
        signInCalls += SignInCall(email, password)
        return signInResult ?: Result.success(Unit)
    }

    override suspend fun signUpWithEmailPassword(
        email: String,
        password: String,
        fullName: String,
        role: UserRole,
    ): Result<SignUpOutcome> {
        signUpCalls += SignUpCall(email, password, fullName, role)
        return signUpResult ?: Result.success(SignUpOutcome.AutoSignedIn)
    }

    override suspend fun signInWithGoogleIdToken(idToken: String, nonce: String?): Result<Unit> {
        googleCalls += GoogleSignInCall(idToken, nonce)
        return googleResult ?: Result.success(Unit)
    }

    override suspend fun sendPasswordResetEmail(email: String): Result<Unit> {
        resetEmails += email
        return resetEmailResult ?: Result.success(Unit)
    }

    override suspend fun updatePassword(currentPassword: String, newPassword: String): Result<Unit> {
        updatePasswordCalls += UpdatePasswordCall(currentPassword, newPassword)
        return updatePasswordResult ?: Result.success(Unit)
    }

    override suspend fun verifyCurrentPassword(password: String): Result<Unit> {
        verifyCurrentPasswordCalls += password
        return verifyCurrentPasswordResult ?: Result.success(Unit)
    }

    override suspend fun sendEmailOtp(email: String): Result<Unit> {
        emailOtpCalls += email
        return emailOtpResult ?: Result.success(Unit)
    }

    override suspend fun verifyEmailOtp(email: String, token: String): Result<Unit> {
        verifyEmailOtpCalls += VerifyEmailOtpCall(email, token)
        return Result.success(Unit)
    }

    override suspend fun requestPhoneAdd(phone: String): Result<Unit> {
        phoneAddCalls += PhoneAddCall(phone)
        return Result.success(Unit)
    }

    override suspend fun verifyPhoneAdd(phone: String, token: String): Result<Unit> {
        verifyPhoneAddCalls += VerifyPhoneCall(phone, token)
        return Result.success(Unit)
    }

    override suspend fun updateEmail(currentPassword: String, newEmail: String): Result<Unit> {
        updateEmailCalls += UpdateEmailCall(currentPassword, newEmail)
        return updateEmailResult ?: Result.success(Unit)
    }

    override suspend fun updateEmailDuringKyc(newEmail: String): Result<Unit> {
        updateEmailDuringKycCalls += newEmail
        return Result.success(Unit)
    }

    override suspend fun signOut(): Result<Unit> {
        signOutCount++
        return Result.success(Unit)
    }

    override suspend fun refreshSession(): Result<Unit> {
        refreshSessionCount++
        return Result.success(Unit)
    }

    companion object {
        /** Convenience for tests that want a typed "wrong password" failure. */
        fun invalidPassword(): Result<Unit> =
            Result.failure(InvalidCurrentPasswordException())

        /** Convenience for tests that want a typed network failure. */
        fun networkFailure(): Result<Unit> =
            Result.failure(IOException("offline (fake)"))
    }
}
