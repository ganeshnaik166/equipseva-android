package com.equipseva.app.core.security

import android.content.Context
import android.content.pm.PackageManager
import android.util.Log

/**
 * Scans installed packages for known reverse-engineering / hooking tools.
 * Report-only by default: if any of these are present, the device is
 * actively being used to inspect or modify apps. Combine with
 * [DeviceIntegrityCheck] and [SignatureVerifier]; on its own this just
 * raises a yellow flag.
 *
 * Package-visibility filtering (targetSdk 30+) applies even to a lookup of
 * one specific id: `getPackageInfo` throws NameNotFoundException for any
 * package the manifest does not declare under <queries>, installed or not.
 * Every id below therefore needs a matching `<package>` entry in
 * AndroidManifest.xml, and that correspondence is pinned by
 * ReverseEngineeringQueriesManifestTest — without it the scan reports a
 * clean device no matter what is installed.
 */
object ReverseEngineeringDetector {

    /**
     * Curated list of well-known package ids used to instrument, hook, or
     * tamper with other apps. Avoid blanket emulator/root packages — those
     * are already covered by [DeviceIntegrityCheck]. Keep this list short
     * to minimise false positives.
     *
     * Adding an id here without the manifest `<queries>` entry makes it
     * undetectable; the manifest test fails in that case.
     */
    internal val SUSPICIOUS_PACKAGES = listOf(
        // Xposed / LSPosed framework family
        "de.robv.android.xposed.installer",
        "org.meowcat.edxposed.manager",
        "org.lsposed.manager",
        "io.github.lsposed.manager",
        // LSPatch (re-signs APKs with hooks baked in)
        "org.lsposed.lspatch",
        // Magisk hide / root managers (DeviceIntegrityCheck already
        // checks for magisk binaries; the manager package id is a
        // second signal).
        "com.topjohnwu.magisk",
        "com.kingoapp.apk",
        "com.kingroot.kinguser",
        // Frida-server controller / clients
        "re.frida.server",
        // Substrate (cydia-style hooking on Android)
        "com.saurik.substrate",
        // Apktool / apk-modder GUI front-ends
        "brut.apktool",
        "com.dryrum.apktoolm",
        "com.guoshi.httpcanary",
        "app.greyshirts.sslcapture",
        "com.guoshi.httpcanary.premium",
        "jp.co.taosoftware.android.packetcapture",
        // Lucky Patcher / Game Guardian — generic patcher tools
        "com.chelpus.lackypatch",
        "com.dimonvideo.luckypatcher",
        "com.forpda.lp",
        "com.android.vendin", // Lucky Patcher fake-store overlay
        "com.cih.gamecih",
        "com.cih.gamecih2",
        "com.cih.game_cih",
        "cn.maocai.gamekiller",
        "cn.maocai.gamemaster",
        "com.android.kelizi.lcsdk", // memory editors
    )

    data class Verdict(
        val foundPackages: List<String>,
    ) {
        val clean: Boolean
            get() = foundPackages.isEmpty()
    }

    fun scan(context: Context): Verdict {
        val pm = context.packageManager
        val hits = SUSPICIOUS_PACKAGES.filter { pkg ->
            runCatching {
                @Suppress("DEPRECATION")
                pm.getPackageInfo(pkg, 0)
                true
            }.recover { ex ->
                if (ex is PackageManager.NameNotFoundException) false
                else {
                    // Other failures (security, RemoteException) — treat as
                    // not-present so a flaky PM doesn't trip a false-positive.
                    Log.w(TAG, "scan threw on $pkg: ${ex::class.simpleName} ${ex.message}")
                    false
                }
            }.getOrDefault(false)
        }
        if (hits.isNotEmpty()) {
            Log.w(TAG, "suspicious packages installed: ${hits.joinToString(",")}")
        }
        return Verdict(foundPackages = hits)
    }

    private const val TAG = "ReverseEngineeringDetector"
}
