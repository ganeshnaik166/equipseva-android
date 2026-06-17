package com.equipseva.app.core.security

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log

/**
 * Checks where the APK was installed from. An attacker re-signs and sideloads
 * a tampered APK; legitimate users install from Play Store. This verifier
 * does NOT alone gate the app — pair with [SignatureVerifier] (the cert hash
 * is the real protection). Install source is the second-cheapest signal to
 * cross-check: if the cert SHA matches BUT the installer is unknown, that's
 * a strong signal the genuine APK was extracted-and-resigned with a stolen
 * upload key, OR was sideloaded by a curious power user.
 *
 * Allowlist (default = Google Play family):
 *   - com.android.vending           Play Store install / update
 *   - com.google.android.feedback   Play Store self-update channel
 *   - com.android.shell             ADB sideload (debug/CI only — block in release)
 *   - null                          Pre-Lollipop or stripped ROM (Unknown)
 *
 * Returns [Verdict.Sideloaded] for anything outside the allowlist. The caller
 * decides whether to log-only or hard-block via [BuildConfig.TAMPER_ENFORCE].
 */
object InstallSourceVerifier {

    enum class Verdict { PlayStore, AdbSideload, Sideloaded, Unknown }

    private val PLAY_FAMILY = setOf(
        "com.android.vending",
        "com.google.android.feedback",
    )

    private const val ADB_INSTALLER = "com.android.shell"

    fun verify(context: Context): Verdict {
        val installer = installerPackage(context)
        Log.i(TAG, "installer=$installer")
        return when {
            installer == null -> Verdict.Unknown
            installer in PLAY_FAMILY -> Verdict.PlayStore
            installer == ADB_INSTALLER -> Verdict.AdbSideload
            else -> Verdict.Sideloaded
        }
    }

    private fun installerPackage(context: Context): String? = runCatching {
        val pm = context.packageManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            pm.getInstallSourceInfo(context.packageName).installingPackageName
        } else {
            @Suppress("DEPRECATION")
            pm.getInstallerPackageName(context.packageName)
        }
    }.onFailure { Log.w(TAG, "installer lookup threw: ${it::class.simpleName} ${it.message}") }
        .getOrNull()

    private const val TAG = "InstallSourceVerifier"
}
