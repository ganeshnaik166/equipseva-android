package com.equipseva.app.features.auth.google

import android.content.Context
import androidx.credentials.CredentialManager
import androidx.credentials.GetCredentialRequest
import androidx.credentials.exceptions.GetCredentialCancellationException
import androidx.credentials.exceptions.GetCredentialException
import androidx.credentials.exceptions.NoCredentialException
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

    // CredentialManagerSignInWithGoogle is a false positive here:
    // lint flags `GetSignInWithGoogleOption` use because it can't see
    // the GoogleIdTokenCredential.TYPE_* references across function
    // boundaries (they live in [isAcceptedGoogleIdCredentialType]
    // below, which extractIdToken calls). Both legacy + SIWG token
    // types are handled — see IsAcceptedGoogleIdCredentialTypeTest.
    @Suppress("CredentialManagerSignInWithGoogle")
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
        } catch (noCredential: NoCredentialException) {
            // User has no Google account saved on the device, or hasn't
            // granted Credential Manager access to one. Generic
            // "sign-in failed" is misleading — the fix is on the user's
            // side (add a Google account). lint flags this branch
            // specifically (CredentialManagerMisuse) because the parent
            // GetCredentialException catch below would otherwise hide
            // it behind a generic error toast.
            GoogleSignInResult.Error(
                "No Google account on this device. Add one in Settings → Passwords & accounts, then try again.",
                noCredential,
            )
        } catch (e: GetCredentialException) {
            GoogleSignInResult.Error(e.message ?: "Google sign-in failed.", e)
        }
    }

    private fun extractIdToken(credential: androidx.credentials.Credential, rawNonce: String): GoogleSignInResult {
        // googleid 1.1+ ships TWO credential types depending on which
        // identity provider answered the GetSignInWithGoogleOption
        // request:
        //   * TYPE_GOOGLE_ID_TOKEN_CREDENTIAL — legacy Google
        //     identity (most common path today).
        //   * TYPE_GOOGLE_ID_TOKEN_SIWG_CREDENTIAL — newer SIWG flow
        //     issued by Credential Manager directly (rolling out
        //     gradually; passkey-paired Google accounts already hit
        //     this path on some devices).
        //
        // Accept either. The earlier version only checked the legacy
        // type, which meant any user the Credential Manager routed
        // through SIWG saw "Unexpected credential type" and couldn't
        // sign in. lint flagged the gap as CredentialManagerSignInWithGoogle.
        if (credential !is androidx.credentials.CustomCredential ||
            !isAcceptedGoogleIdCredentialType(credential.type)
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

/**
 * Whether [type] is a credential-type string this app accepts from a
 * Credential Manager `GetSignInWithGoogleOption` response. Lifted out
 * of [GoogleSignInClient.extractIdToken] so the legacy / SIWG pair
 * can be pinned by a unit test — googleid 1.1+ may issue either
 * `TYPE_GOOGLE_ID_TOKEN_CREDENTIAL` (legacy Google identity) or
 * `TYPE_GOOGLE_ID_TOKEN_SIWG_CREDENTIAL` (newer SIWG flow) depending
 * on how Credential Manager resolved the request.
 *
 * Pinned regression target: a previous version of the gate only
 * accepted the legacy type, which surfaced "Unexpected credential
 * type" for users routed through the SIWG path. A refactor that
 * narrows back to a single type would re-introduce that auth break.
 */
internal fun isAcceptedGoogleIdCredentialType(type: String): Boolean =
    type == GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL ||
        type == GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_SIWG_CREDENTIAL

sealed interface GoogleSignInResult {
    data class Token(val idToken: String, val rawNonce: String) : GoogleSignInResult
    data object Cancelled : GoogleSignInResult
    data object NotConfigured : GoogleSignInResult
    data class Error(val message: String, val cause: Throwable?) : GoogleSignInResult
}
