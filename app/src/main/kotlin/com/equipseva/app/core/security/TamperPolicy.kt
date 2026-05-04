package com.equipseva.app.core.security

import com.equipseva.app.BuildConfig
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Single decision point for "is this device + APK trustworthy enough to perform
 * a sensitive action right now?". Combines two signals:
 *
 *  1. [SignatureVerifier.Verdict] from boot — the APK signing certificate must
 *     match `EXPECTED_CERT_SHA256`. A `Tampered` verdict means the APK was
 *     resigned (jadx + apktool, malicious repackaging) and we refuse the action
 *     unconditionally — even in debug, since debug builds always pass `Unknown`.
 *
 *  2. [IntegrityVerifier] (Play Integrity, server-verified) — fresh per call so
 *     a snapshot stolen from another device cannot replay forever. The verifier
 *     applies a debug fail-open / release fail-closed split, so callers don't
 *     have to special-case build types.
 *
 * `EXPECTED_CERT_SHA256` is allowed blank during pre-Play-upload builds — when
 * blank, the signature signal is treated as `Unknown` and not used to deny
 * (otherwise local debug builds couldn't sign in). Once the upload key + Play
 * App Signing fingerprints are wired (PENDING.md item 14), the signature signal
 * gates the session for real.
 *
 * Usage:
 *
 *   tamperPolicy.enforce("auth_change").onFailure { return Result.failure(it) }
 *   // proceed with the sensitive Supabase call
 */
@Singleton
class TamperPolicy @Inject constructor(
    private val integrityVerifier: IntegrityVerifier,
) {
    @Volatile private var sigVerdict: SignatureVerifier.Verdict = SignatureVerifier.Verdict.Unknown

    fun setSignatureVerdict(verdict: SignatureVerifier.Verdict) {
        sigVerdict = verdict
    }

    /**
     * Returns `Result.success(Unit)` when the action may proceed.
     * Returns `Result.failure(...)` when the device or APK is untrusted.
     *
     * @param action stable string label (`auth_change`, `delete_account`, `kyc_submit`, ...)
     *   echoed into the Play Integrity attestation request so the server can audit
     *   per-action verdict patterns.
     */
    suspend fun enforce(action: String): Result<Unit> {
        if (BuildConfig.EXPECTED_CERT_SHA256.isNotBlank() &&
            sigVerdict == SignatureVerifier.Verdict.Tampered
        ) {
            return Result.failure(TamperedSignatureException(action))
        }
        return integrityVerifier.requestVerification(action)
            .fold(
                onSuccess = { pass ->
                    if (pass) Result.success(Unit)
                    else Result.failure(IntegrityFailedException(action))
                },
                onFailure = { Result.failure(it) },
            )
    }

    class TamperedSignatureException(action: String) :
        RuntimeException("APK signature mismatch — refusing $action")

    class IntegrityFailedException(action: String) :
        RuntimeException("Play Integrity verdict failed for $action")
}
