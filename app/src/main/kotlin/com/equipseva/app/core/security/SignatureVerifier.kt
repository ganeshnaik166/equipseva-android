package com.equipseva.app.core.security

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.util.Base64
import android.util.Log
import com.equipseva.app.BuildConfig
import java.security.MessageDigest

/**
 * Checks that the APK the user is running was signed with one of the expected
 * certs. A jadx-modified, apktool-rebuilt, or otherwise resigned build fails
 * because the signing cert's SubjectPublicKeyInfo hash changes.
 *
 * The expected SHA-256 list comes from [BuildConfig.EXPECTED_CERT_SHA256]
 * (plumbed from `EXPECTED_CERT_SHA256` in local.properties / CI secret).
 * Comma-separated so a single config holds BOTH:
 *   - the upload-key fingerprint (locally-built AABs / sideloaded test APKs), AND
 *   - the Play App Signing key fingerprint (Play-distributed installs, where
 *     Google re-signs after upload).
 * Whitespace around each entry is trimmed; empties skipped.
 *
 * While the release keystore isn't provisioned yet (Play Console access
 * pending) the constant is blank and we skip the check — logging only so we
 * know it ran. When the keystore lands: fill in `EXPECTED_CERT_SHA256`, flip
 * [TamperPolicy.enforce] to `true`, and this check starts gating the app.
 */
object SignatureVerifier {

    enum class Verdict { Ok, Unknown, Tampered }

    fun verify(context: Context): Verdict {
        val expected = parseExpectedFingerprints(BuildConfig.EXPECTED_CERT_SHA256)
        if (expected.isEmpty()) {
            Log.w(TAG, "EXPECTED_CERT_SHA256 is blank; skipping signature check.")
            return Verdict.Unknown
        }

        val actual = runCatching { currentCertSha256(context) }
            .onFailure { Log.w(TAG, "currentCertSha256 threw: ${it::class.simpleName} ${it.message}") }
            .getOrNull()
        if (actual == null) {
            Log.w(TAG, "Could not read signing certificate; treating as unknown.")
            return Verdict.Unknown
        }

        return if (expected.any { it.equals(actual, ignoreCase = true) }) {
            Verdict.Ok
        } else {
            Log.e(TAG, "Signature mismatch. expected=${expected.joinToString(",")} actual=$actual")
            Verdict.Tampered
        }
    }

    private fun parseExpectedFingerprints(raw: String): List<String> =
        raw.split(',').map { it.trim() }.filter { it.isNotEmpty() }

    private fun currentCertSha256(context: Context): String {
        val pm = context.packageManager
        val certBytes: ByteArray = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            @Suppress("DEPRECATION")
            val info = pm.getPackageInfo(
                context.packageName,
                PackageManager.GET_SIGNING_CERTIFICATES,
            )
            val signingInfo = info.signingInfo
                ?: error("signingInfo is null")
            val signers = if (signingInfo.hasMultipleSigners()) {
                signingInfo.apkContentsSigners
            } else {
                signingInfo.signingCertificateHistory
            }
            signers.first().toByteArray()
        } else {
            @Suppress("DEPRECATION")
            val info = pm.getPackageInfo(
                context.packageName,
                PackageManager.GET_SIGNATURES,
            )
            @Suppress("DEPRECATION")
            info.signatures!!.first().toByteArray()
        }
        val sha = MessageDigest.getInstance("SHA-256").digest(certBytes)
        return Base64.encodeToString(sha, Base64.NO_WRAP)
    }

    private const val TAG = "SignatureVerifier"
}
