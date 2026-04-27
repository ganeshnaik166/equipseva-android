package com.equipseva.app.features.auth.google

import android.content.Context
import androidx.credentials.CredentialManager
import androidx.credentials.GetCredentialRequest
import androidx.credentials.exceptions.GetCredentialCancellationException
import androidx.credentials.exceptions.GetCredentialException
import com.equipseva.app.core.util.BuildConfigValues
import com.google.android.libraries.identity.googleid.GetSignInWithGoogleOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import com.google.android.libraries.identity.googleid.GoogleIdTokenParsingException
import dagger.hilt.android.qualifiers.ApplicationContext
import java.security.MessageDigest
import java.security.SecureRandom
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Wraps Credential Manager's GoogleId flow. We try the silent "sign-in only" path first
 * (returns existing accounts) and fall back to the explicit "Sign in with Google" picker.
 *
 * Returns a `GoogleSignInResult` with the ID token + nonce so the AuthRepository can hand
 * it to Supabase's verify-id-token endpoint.
 */
@Singleton
class GoogleSignInClient @Inject constructor(
    @ApplicationContext private val context: Context,
) {
    private val credentialManager: CredentialManager = CredentialManager.create(context)

    suspend fun signIn(activityContext: Context): GoogleSignInResult {
        val webClientId = BuildConfigValues.googleWebClientId
        if (webClientId.isBlank()) return GoogleSignInResult.NotConfigured

        val rawNonce = generateNonce()
        val hashedNonce = sha256(rawNonce)

        // Always show the explicit "Sign in with Google" picker. The previous
        // silent + auto-select path re-picked the last-used account on every
        // sign-in, which made it impossible to switch accounts after a sign-out.
        return requestExplicitPicker(activityContext, webClientId, rawNonce, hashedNonce)
    }

    private suspend fun requestExplicitPicker(
        activityContext: Context,
        webClientId: String,
        rawNonce: String,
        hashedNonce: String,
    ): GoogleSignInResult {
        val explicitRequest = GetCredentialRequest.Builder()
            .addCredentialOption(
                GetSignInWithGoogleOption.Builder(webClientId)
                    .setNonce(hashedNonce)
                    .build(),
            )
            .build()
        return try {
            val credential = credentialManager.getCredential(activityContext, explicitRequest).credential
            extractIdToken(credential, rawNonce)
        } catch (cancelled: GetCredentialCancellationException) {
            GoogleSignInResult.Cancelled
        } catch (e: GetCredentialException) {
            GoogleSignInResult.Error(e.message ?: "Google sign-in failed.", e)
        }
    }

    private fun extractIdToken(credential: androidx.credentials.Credential, rawNonce: String): GoogleSignInResult {
        if (credential !is androidx.credentials.CustomCredential ||
            credential.type != GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL
        ) {
            return GoogleSignInResult.Error("Unexpected credential type: ${credential.type}", null)
        }
        return try {
            val parsed = GoogleIdTokenCredential.createFrom(credential.data)
            // Supabase expects the *raw* nonce in verify; the request carried the SHA-256 hash.
            GoogleSignInResult.Token(idToken = parsed.idToken, rawNonce = rawNonce)
        } catch (e: GoogleIdTokenParsingException) {
            GoogleSignInResult.Error("Invalid Google ID token.", e)
        }
    }

    private fun generateNonce(bytes: Int = 32): String {
        val buf = ByteArray(bytes)
        SecureRandom().nextBytes(buf)
        return buf.joinToString("") { "%02x".format(it) }
    }

    private fun sha256(input: String): String {
        val digest = MessageDigest.getInstance("SHA-256").digest(input.toByteArray(Charsets.UTF_8))
        return digest.joinToString("") { "%02x".format(it) }
    }
}

sealed interface GoogleSignInResult {
    data class Token(val idToken: String, val rawNonce: String) : GoogleSignInResult
    data object Cancelled : GoogleSignInResult
    data object NotConfigured : GoogleSignInResult
    data class Error(val message: String, val cause: Throwable?) : GoogleSignInResult
}
