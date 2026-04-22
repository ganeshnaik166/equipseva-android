package com.equipseva.app.core.security

import android.os.Build
import android.os.Debug
import android.util.Log
import com.equipseva.app.BuildConfig
import java.io.File
import java.net.InetSocketAddress
import java.net.Socket

/**
 * Runs cheap local probes for signals that the device is rooted, an emulator,
 * under a debugger, or has Frida attached. The intent is to *report*, not to
 * block — a determined attacker always wins on-device. The real backstop is
 * server-side: forward [Verdict] alongside a Play Integrity token to the
 * server, and let the server refuse sensitive ops (order create, KYC submit,
 * payout release) when the verdict is dirty.
 *
 * Keep the probes conservative: false positives on legitimate
 * developer / rooted enthusiast devices are bad UX.
 */
object DeviceIntegrityCheck {

    data class Verdict(
        val debuggerAttached: Boolean,
        val rooted: Boolean,
        val emulator: Boolean,
        val fridaDetected: Boolean,
    ) {
        val clean: Boolean
            get() = !debuggerAttached && !rooted && !emulator && !fridaDetected

        fun toTag(): String = buildString {
            append("debugger=").append(debuggerAttached)
            append(" rooted=").append(rooted)
            append(" emulator=").append(emulator)
            append(" frida=").append(fridaDetected)
        }
    }

    fun run(): Verdict {
        val debugger = !BuildConfig.DEBUG && (Debug.isDebuggerConnected() || Debug.waitingForDebugger())
        val verdict = Verdict(
            debuggerAttached = debugger,
            rooted = looksRooted(),
            emulator = looksLikeEmulator(),
            fridaDetected = looksLikeFrida(),
        )
        if (!verdict.clean) {
            Log.w(TAG, "Device integrity: ${verdict.toTag()}")
        }
        return verdict
    }

    private fun looksRooted(): Boolean {
        val suspects = listOf(
            "/system/app/Superuser.apk",
            "/system/xbin/su",
            "/sbin/su",
            "/system/bin/su",
            "/system/xbin/busybox",
            "/data/local/su",
            "/data/local/bin/su",
            "/data/local/xbin/su",
            "/data/adb/magisk",
            "/sbin/.magisk",
        )
        if (suspects.any { File(it).exists() }) return true
        if (Build.TAGS?.contains("test-keys") == true) return true
        // Writable /system is a rooted-ROM tell.
        return File("/system").canWrite()
    }

    private fun looksLikeEmulator(): Boolean {
        val fp = Build.FINGERPRINT.orEmpty()
        val model = Build.MODEL.orEmpty()
        val manufacturer = Build.MANUFACTURER.orEmpty()
        val product = Build.PRODUCT.orEmpty()
        val hardware = Build.HARDWARE.orEmpty()
        return fp.startsWith("generic") ||
            fp.startsWith("unknown") ||
            fp.contains("vbox") ||
            model.contains("google_sdk") ||
            model.contains("Emulator", ignoreCase = true) ||
            model.contains("Android SDK built for") ||
            manufacturer.contains("Genymotion", ignoreCase = true) ||
            product.contains("sdk") ||
            hardware.contains("goldfish") ||
            hardware.contains("ranchu")
    }

    private fun looksLikeFrida(): Boolean {
        // Frida-server default TCP port on the device's loopback. Very cheap
        // probe; misses gadget-based Frida but catches the common case.
        val port = 27042
        return runCatching {
            Socket().use { s ->
                s.connect(InetSocketAddress("127.0.0.1", port), 50)
                true
            }
        }.getOrDefault(false)
    }

    private const val TAG = "DeviceIntegrityCheck"
}
