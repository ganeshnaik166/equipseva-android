package com.equipseva.app.core.security

import android.content.Context
import android.util.Log
import com.equipseva.app.BuildConfig
import com.google.android.play.core.integrity.IntegrityManagerFactory
import com.google.android.play.core.integrity.IntegrityTokenRequest
import dagger.hilt.android.qualifiers.ApplicationContext
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.functions.functions
import io.ktor.client.statement.bodyAsText
import io.ktor.http.isSuccess
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import javax.inject.Inject
import javax.inject.Singleton
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/**
 * Client wiring for the verify-play-integrity Edge Function (PR #186).
 *
 * Flow:
 *   1. Ask Google Play Integrity for an attestation token (signed JWE).
 *   2. POST { token, action } to the Edge Function. The function exchanges
 *      the token with Google's decodeIntegrityToken endpoint server-side and
 *      returns { pass, verdicts }.
 *   3. Caller gates a sensitive action (checkout, KYC submit, payout) on the
 *      pass flag.
 *
 * Why server-verify: a rooted device can stub this client and lie about the
 * verdict. Only the server -> Google decode is honest. We never trust the
 * raw token contents on-device.
 *
 * Failure policy:
 *   - DEBUG builds: fail-open. Devs without Play setup must still be able
 *     to test checkout / KYC locally, and the SDK throws on emulators that
 *     don't have Play Services.
 *   - RELEASE builds: fail-closed. A real failure (network, Google quota,
 *     mismatched package, missing Play install) blocks the sensitive action.
 *
 * Timeout: 10 s round-trip cap. If we don't have an answer in that window,
 * apply the same fail-open / fail-closed split as above.
 *
 * NOT a permission: the Play Integrity SDK uses Google Play Services and
 * does not require any extra Android manifest permission.
 */
/**
 * Tiny interface KycViewModel + the rest of the app pin to so unit tests can
 * provide a trivial fake without instantiating the real Play Integrity stack
 * (which needs a Context + SupabaseClient + the SDK on the device).
 */
interface IntegrityVerifier {
    suspend fun requestVerification(action: String): Result<Boolean>
}

@Singleton
open class PlayIntegrityClient @Inject constructor(
    @ApplicationContext private val context: Context,
    private val supabase: SupabaseClient,
) : IntegrityVerifier {
    private val json = Json { ignoreUnknownKeys = true }

    /**
     * Asks Play Integrity for a token and posts to the verify-play-integrity
     * Edge Function. Returns Result.success(true) on a clean pass, success(false)
     * on a clean fail. On exceptions (timeout / SDK error / network) returns
     * success(true) in DEBUG and failure(...) in RELEASE.
     *
     * Always called from viewModelScope on Dispatchers.IO via [withContext].
     */
    override suspend fun requestVerification(action: String): Result<Boolean> = withContext(Dispatchers.IO) {
        val outcome = withTimeoutOrNull(VERIFICATION_TIMEOUT_MS) {
            runCatching { runVerification(action) }
        }

        when {
            outcome == null -> {
                // Timeout. Mirror the debug/release split — devs on slow
                // simulators shouldn't be locked out of checkout.
                Log.w(TAG, "Play Integrity timeout after ${VERIFICATION_TIMEOUT_MS}ms (action=$action)")
                if (BuildConfig.DEBUG) Result.success(true)
                else Result.failure(IntegrityTimeoutException(action))
            }
            outcome.isSuccess -> outcome.getOrThrow().let { Result.success(it) }
            else -> {
                val ex = outcome.exceptionOrNull()
                    ?: IllegalStateException("unknown integrity failure")
                Log.w(TAG, "Play Integrity failed (action=$action): ${ex.message}")
                if (BuildConfig.DEBUG) Result.success(true) else Result.failure(ex)
            }
        }
    }

    private suspend fun runVerification(action: String): Boolean {
        val token = requestToken()
        val res = supabase.functions.invoke(
            function = "verify-play-integrity",
            body = buildJsonObject {
                put("token", JsonPrimitive(token))
                put("action", JsonPrimitive(action))
            },
        )
        val text = res.bodyAsText()
        if (!res.status.isSuccess()) {
            // Edge function 4xx/5xx — surface to the caller. The debug/release
            // split is applied one level up, in [requestVerification].
            throw IntegrityServerException(res.status.value, text)
        }
        val parsed = json.decodeFromString(VerifyResponse.serializer(), text)
        return parsed.ok && parsed.pass
    }

    /**
     * Bridges [IntegrityManager.requestIntegrityToken] (which exposes a Play
     * Tasks API) into a suspend function. Cancellation propagates: if the
     * caller is cancelled (e.g. checkout screen leaves), the Task is left
     * to complete on its own — there's no public cancel API for it.
     */
    private suspend fun requestToken(): String = suspendCancellableCoroutine { cont ->
        val manager = IntegrityManagerFactory.create(context.applicationContext)
        // Nonce binds the token to *this* request. We use a per-call random
        // nonce to make replay across calls harder. The server doesn't pin
        // the nonce today — when it starts, switch this to an opaque value
        // returned from the backend.
        val nonce = generateNonce()
        val request = IntegrityTokenRequest.builder()
            .setNonce(nonce)
            .build()
        manager.requestIntegrityToken(request)
            .addOnSuccessListener { response ->
                if (cont.isActive) cont.resume(response.token())
            }
            .addOnFailureListener { error ->
                if (cont.isActive) cont.resumeWithException(error)
            }
    }

    private fun generateNonce(): String {
        val bytes = ByteArray(16)
        java.security.SecureRandom().nextBytes(bytes)
        return android.util.Base64.encodeToString(
            bytes,
            android.util.Base64.URL_SAFE or android.util.Base64.NO_WRAP or android.util.Base64.NO_PADDING,
        )
    }

    @Serializable
    private data class VerifyResponse(
        val ok: Boolean = false,
        val pass: Boolean = false,
        val verdicts: Verdicts? = null,
    )

    @Serializable
    private data class Verdicts(
        val device: String? = null,
        val app: String? = null,
        @SerialName("licensing") val licensing: String? = null,
    )

    class IntegrityServerException(
        val httpStatus: Int,
        val responseBody: String,
    ) : RuntimeException("verify-play-integrity returned $httpStatus: $responseBody")

    class IntegrityTimeoutException(action: String) :
        RuntimeException("verify-play-integrity timed out for action=$action")

    companion object {
        private const val TAG = "PlayIntegrityClient"
        private const val VERIFICATION_TIMEOUT_MS: Long = 10_000

        /** User-facing message for a hard fail in release. */
        const val FAILURE_MESSAGE: String =
            "Couldn't verify your device. Please reinstall from Google Play."
    }
}
